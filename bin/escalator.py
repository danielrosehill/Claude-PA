#!/usr/bin/env python3
"""claude-pa escalator daemon.

Watches $CLAUDE_PA_HOME/escalator/state.json. When Claude calls
/dispatch attention:*, dispatch.sh writes the marker. The daemon then walks
the manifest's tier ladder, firing `dispatch.sh <tag> --tier N` at each
delay_seconds threshold until the user responds (which deletes the marker
via the UserPromptSubmit hook → mark-active.sh).

Single source of truth for tier timing: sounds/manifest.json delay_seconds.
Cap: config.escalation.max_tier (or env CLAUDE_PA_MAX_TIER).
"""

from __future__ import annotations

import fcntl
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

POLL_INTERVAL = 2.0  # seconds — granularity of escalation firing
LOG_FLUSH_EVERY = 50


def home() -> Path:
    h = os.environ.get("CLAUDE_PA_HOME")
    if h:
        return Path(h)
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return Path(xdg) / "claude-pa"
    return Path.home() / ".local/share/claude-pa"


def plugin_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_json(path: Path) -> dict:
    with path.open() as f:
        return json.load(f)


def read_state(state_path: Path) -> dict | None:
    if not state_path.exists():
        return None
    try:
        with state_path.open("r") as f:
            fcntl.flock(f, fcntl.LOCK_SH)
            try:
                return json.load(f)
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)
    except (json.JSONDecodeError, OSError):
        return None


def write_state(state_path: Path, state: dict) -> None:
    tmp = state_path.with_suffix(".tmp")
    with tmp.open("w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            json.dump(state, f)
            f.flush()
            os.fsync(f.fileno())
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)
    tmp.replace(state_path)


def tier_ladder(manifest: dict) -> list[tuple[int, float]]:
    """Return [(tier, delay_seconds), ...] sorted, excluding tier 0."""
    out = []
    for tier_str, defn in manifest.get("escalation_tiers", {}).items():
        try:
            tier = int(tier_str)
        except ValueError:
            continue
        if tier == 0:
            continue  # tier 0 fired immediately by Claude itself
        delay = float(defn.get("delay_seconds", 0))
        out.append((tier, delay))
    out.sort(key=lambda x: x[1])
    return out


def max_tier(config: dict) -> int:
    env_cap = os.environ.get("CLAUDE_PA_MAX_TIER")
    if env_cap is not None:
        try:
            return int(env_cap)
        except ValueError:
            pass
    return int(config.get("escalation", {}).get("max_tier", 6))


def fire(tag: str, tier: int, plugin_dir: Path, log: Path) -> None:
    cmd = [str(plugin_dir / "bin" / "dispatch.sh"), tag, "--tier", str(tier)]
    ts = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    with log.open("a") as f:
        f.write(f"{ts} fire tag={tag} tier={tier}\n")
    try:
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as e:
        with log.open("a") as f:
            f.write(f"{ts} fire-error tag={tag} tier={tier} err={e}\n")


def run() -> int:
    h = home()
    plugin_dir = plugin_root()
    esc_dir = h / "escalator"
    esc_dir.mkdir(parents=True, exist_ok=True)
    state_path = esc_dir / "state.json"
    log_path = h / "logs" / "escalator.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    manifest_path = plugin_dir / "sounds" / "manifest.json"
    config_path = h / "config.json"

    if not manifest_path.exists():
        print(f"escalator: missing manifest at {manifest_path}", file=sys.stderr)
        return 1

    manifest = load_json(manifest_path)
    ladder = tier_ladder(manifest)
    if not ladder:
        print("escalator: no tier ladder in manifest", file=sys.stderr)
        return 1

    running = {"v": True}

    def stop(signum, frame):
        running["v"] = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    with log_path.open("a") as f:
        f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} start pid={os.getpid()}\n")

    last_config_mtime = 0.0
    cap = 6

    while running["v"]:
        # Re-read config opportunistically (cheap; lets user change cap without restart)
        try:
            mtime = config_path.stat().st_mtime if config_path.exists() else 0.0
            if mtime != last_config_mtime:
                cfg = load_json(config_path) if config_path.exists() else {}
                if not cfg.get("escalation", {}).get("enabled", True):
                    # disabled — sleep longer, skip work
                    time.sleep(POLL_INTERVAL * 5)
                    last_config_mtime = mtime
                    continue
                cap = max_tier(cfg)
                last_config_mtime = mtime
        except OSError:
            pass

        state = read_state(state_path)
        if state and "idle_since" in state and "tag" in state:
            elapsed = time.time() - float(state["idle_since"])
            fired = set(state.get("fired", []))
            for tier, delay in ladder:
                if tier > cap:
                    break
                if tier in fired:
                    continue
                if elapsed >= delay:
                    fire(state["tag"], tier, plugin_dir, log_path)
                    fired.add(tier)
                    state["fired"] = sorted(fired)
                    try:
                        write_state(state_path, state)
                    except OSError:
                        pass
                else:
                    break  # ladder is sorted — no later tier ready either

        time.sleep(POLL_INTERVAL)

    with log_path.open("a") as f:
        f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} stop pid={os.getpid()}\n")
    return 0


if __name__ == "__main__":
    sys.exit(run())
