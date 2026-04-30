#!/usr/bin/env bash
# Control the claude-pa escalator daemon. Prefers a systemd --user service
# (claude-pa-escalator.service); falls back to a plain background process
# tracked via $CLAUDE_PA_HOME/escalator/escalator.pid.
#
# Usage:
#   escalator-ctl.sh start | stop | restart | status | install | uninstall | logs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "$SCRIPT_DIR/paths.sh"

UNIT="claude-pa-escalator.service"
UNIT_SRC="$PLUGIN_ROOT/templates/systemd/$UNIT"
UNIT_DST="$HOME/.config/systemd/user/$UNIT"
ESC_DIR="$CLAUDE_PA_HOME/escalator"
PIDFILE="$ESC_DIR/escalator.pid"
LOGFILE="$CLAUDE_PA_LOG_DIR/escalator.log"

mkdir -p "$ESC_DIR" "$CLAUDE_PA_LOG_DIR"

have_systemd() { command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; }

cmd_install() {
  if ! have_systemd; then
    echo "claude-pa: systemd --user not available; will run in fallback mode (no install needed)"
    return 0
  fi
  mkdir -p "$(dirname "$UNIT_DST")"
  # Render unit with absolute path baked in
  sed "s|@PLUGIN_ROOT@|$PLUGIN_ROOT|g; s|@CLAUDE_PA_HOME@|$CLAUDE_PA_HOME|g" \
    "$UNIT_SRC" > "$UNIT_DST"
  systemctl --user daemon-reload
  systemctl --user enable "$UNIT" >/dev/null
  echo "installed: $UNIT_DST"
}

cmd_uninstall() {
  if have_systemd && [[ -f "$UNIT_DST" ]]; then
    systemctl --user disable --now "$UNIT" 2>/dev/null || true
    rm -f "$UNIT_DST"
    systemctl --user daemon-reload
    echo "uninstalled: $UNIT_DST"
  fi
  cmd_stop_fallback || true
}

start_systemd() { systemctl --user start "$UNIT"; echo "started (systemd)"; }
stop_systemd()  { systemctl --user stop  "$UNIT"; echo "stopped (systemd)"; }

start_fallback() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "already running (pid $(cat "$PIDFILE"))"
    return 0
  fi
  nohup python3 "$SCRIPT_DIR/escalator.py" >> "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
  echo "started (fallback, pid $!)"
}

cmd_stop_fallback() {
  [[ -f "$PIDFILE" ]] || return 0
  local pid
  pid=$(cat "$PIDFILE")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
    sleep 0.2
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" || true
  fi
  rm -f "$PIDFILE"
  echo "stopped (fallback)"
}

cmd_start() {
  if have_systemd && [[ -f "$UNIT_DST" ]]; then start_systemd; else start_fallback; fi
}
cmd_stop() {
  if have_systemd && [[ -f "$UNIT_DST" ]]; then stop_systemd; else cmd_stop_fallback; fi
}
cmd_restart() { cmd_stop || true; cmd_start; }

cmd_status() {
  if have_systemd && [[ -f "$UNIT_DST" ]]; then
    systemctl --user --no-pager status "$UNIT" || true
  elif [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "running (fallback, pid $(cat "$PIDFILE"))"
  else
    echo "not running"
  fi
  if [[ -f "$ESC_DIR/state.json" ]]; then
    echo "--- active idle marker ---"
    cat "$ESC_DIR/state.json"
    echo
  else
    echo "no active idle marker"
  fi
}

cmd_logs() { tail -n 200 -f "$LOGFILE"; }

case "${1:-}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  restart)   cmd_restart ;;
  status)    cmd_status ;;
  logs)      cmd_logs ;;
  *) echo "usage: $0 {install|uninstall|start|stop|restart|status|logs}" >&2; exit 2 ;;
esac
