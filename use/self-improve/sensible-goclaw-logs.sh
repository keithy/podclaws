#!/bin/sh
# sensible-goclaw-logs.sh - tail sensible consumer logs for the goclaw stack
#
# Usage:
#   sensible-goclaw-logs.sh            # tail journal (path + service, follow mode)
#   sensible-goclaw-logs.sh --once     # dump recent entries, exit
#   sensible-goclaw-logs.sh --tasks    # show current pending/ and done/ dirs
#   sensible-goclaw-logs.sh --watch    # inotifywait on pending/ (no journal required)
#
# The systemd units are installed by sensible-goclaw-user-setup.sh and log
# to the user journal. If systemd isn't reachable (e.g. inside a container),
# --watch and --tasks still work because they read the filesystem directly.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_DIR="${SENSIBLE_TASKS_DIR:-/srv/auto_goclaw-data/_data/.runtime/sensible/tasks}"

show_tasks() {
    echo "=== pending/ ==="
    if [ -d "$TASKS_DIR/pending" ]; then
        ls -la "$TASKS_DIR/pending" || true
    else
        echo "(missing: $TASKS_DIR/pending)"
    fi
    echo ""
    echo "=== done/ (most recent 10) ==="
    if [ -d "$TASKS_DIR/done" ]; then
        ls -lt "$TASKS_DIR/done" 2>/dev/null | head -11 || true
    else
        echo "(missing: $TASKS_DIR/done)"
    fi
}

show_watch() {
    if ! command -v inotifywait >/dev/null 2>&1; then
        echo "inotifywait not found (install inotify-tools / inotify-tools)"
        exit 1
    fi
    echo "Watching $TASKS_DIR/pending (Ctrl-C to exit)..."
    inotifywait -m -e create -e moved_to "$TASKS_DIR/pending"
}

show_journal() {
    once=""
    if [ "${1:-}" = "--once" ]; then
        once="--no-pager -n 50"
    fi
    journalctl --user -u sensible-goclaw.path -u sensible-goclaw.service $once -f
}

case "${1:-}" in
    --once)
        show_journal --once
        ;;
    --tasks)
        show_tasks
        ;;
    --watch)
        show_watch
        ;;
    --help|-h)
        sed -n '2,16p' "$0"
        ;;
    "")
        show_journal
        ;;
    *)
        echo "Unknown option: $1 (try --help)"
        exit 1
        ;;
esac