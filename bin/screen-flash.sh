#!/usr/bin/env bash
# claude-pa screen flash — full-screen visual alert for dramatic effect.
#
# Fires in parallel with audio dispatches (alongside the signal bulb) so the
# user gets a hard-to-miss visual ping even on a silenced machine.
#
# Two modes, picked automatically based on what's installed:
#
#   1. fullscreen-overlay (preferred): a brief full-screen colored flash via
#      a tiny Python/tkinter window. Works on X11 and most Wayland compositors.
#      Falls back gracefully if tkinter or DISPLAY/WAYLAND_DISPLAY isn't
#      available.
#
#   2. notify-send (fallback): a desktop notification with urgency=critical.
#      Universal on Linux desktops with libnotify.
#
# Patterns map to colors:
#   thinking → blue
#   waiting  → amber
#   working  → cyan
#   done     → green
#   error    → red
#
# Refuses to fire unless config.screen_flash.enabled == true.
#
# Usage: screen-flash.sh <pattern> [--message TEXT] [--duration-ms N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"
claude_pa_require_config || exit 1

PATTERN="${1:?usage: screen-flash.sh <thinking|waiting|working|done|error|clear>}"
shift || true
MESSAGE=""
DURATION_MS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --message)     MESSAGE="$2"; shift 2 ;;
    --duration-ms) DURATION_MS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

CONFIG="$CLAUDE_PA_CONFIG_FILE"
ENABLED=$(jq -r '.screen_flash.enabled // false' "$CONFIG")
[[ "$ENABLED" == "true" ]] || exit 0  # silent no-op if disabled

MODE=$(jq -r '.screen_flash.mode // "auto"' "$CONFIG")
[[ -z "$DURATION_MS" ]] && DURATION_MS=$(jq -r '.screen_flash.duration_ms // 600' "$CONFIG")
FLASH_COUNT=$(jq -r '.screen_flash.flash_count // 3' "$CONFIG")

# Color per pattern (hex, no leading #)
case "$PATTERN" in
  thinking) COLOR="3a7afe"; LABEL="thinking" ;;
  waiting)  COLOR="ff9e2c"; LABEL="waiting on you" ;;
  working)  COLOR="2ec4f1"; LABEL="working" ;;
  done)     COLOR="2ecc71"; LABEL="done" ;;
  error)    COLOR="e74c3c"; LABEL="error" ;;
  clear)    exit 0 ;;
  *)        COLOR="ffffff"; LABEL="$PATTERN" ;;
esac
DISPLAY_MSG="${MESSAGE:-Claude-PA: $LABEL}"

# --- Mode resolution ----------------------------------------------------------
have_display() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}
have_overlay() {
  have_display && command -v python3 >/dev/null 2>&1 \
    && python3 -c 'import tkinter' >/dev/null 2>&1
}
have_notify() { command -v notify-send >/dev/null 2>&1; }

resolve_mode() {
  case "$MODE" in
    overlay) echo overlay ;;
    notify)  echo notify ;;
    auto)
      if have_overlay; then echo overlay
      elif have_notify; then echo notify
      else echo none
      fi
      ;;
    *) echo none ;;
  esac
}
RESOLVED=$(resolve_mode)

# --- Overlay (Python/tkinter) -------------------------------------------------
flash_overlay() {
  python3 - "$COLOR" "$DURATION_MS" "$FLASH_COUNT" "$DISPLAY_MSG" <<'PY' &
import sys, tkinter as tk
color, duration_ms, count, msg = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
root = tk.Tk()
root.attributes("-fullscreen", True)
try:
    root.attributes("-topmost", True)
    root.attributes("-alpha", 0.55)
except tk.TclError:
    pass
root.configure(bg=f"#{color}")
root.overrideredirect(True)
label = tk.Label(root, text=msg, bg=f"#{color}", fg="white",
                 font=("Helvetica", 64, "bold"))
label.pack(expand=True)
on = [True]
remaining = [count * 2]  # toggle on/off
def tick():
    if remaining[0] <= 0:
        root.destroy(); return
    if on[0]:
        root.deiconify()
    else:
        root.withdraw()
    on[0] = not on[0]
    remaining[0] -= 1
    root.after(duration_ms // 2, tick)
root.after(0, tick)
root.mainloop()
PY
  disown 2>/dev/null || true
}

# --- notify-send fallback -----------------------------------------------------
flash_notify() {
  notify-send --urgency=critical --expire-time="$DURATION_MS" \
    --icon=dialog-warning "Claude-PA" "$DISPLAY_MSG" || true
}

case "$RESOLVED" in
  overlay) flash_overlay ;;
  notify)  flash_notify ;;
  none)    exit 0 ;;
esac
