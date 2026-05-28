#!/bin/sh
# podman_on_host.sh - queue host commands via sensible
# Usage: podman_on_host.sh <command> [args]
# Commands: commit, restart, switch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CMD="${1?Usage: podman_on_host.sh <command> [args]}"
shift || true

case "$CMD" in
  commit)
    CONTAINER="${1?Usage: podman_on_host.sh commit <container> [tag]}"
    TAG="${2:-next}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      'if { podman rmi localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:current localhost/goclaw:previous } true' \
      "podman commit $CONTAINER localhost/goclaw:$TAG"
    ;;
  commit_and_switch)
    CONTAINER="${1?Usage: podman_on_host.sh commit_and_switch <container> [tag]}"
    TAG="${2:-current}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      'if { podman rmi localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:current localhost/goclaw:previous } true' \
      "podman commit $CONTAINER localhost/goclaw:$TAG" \
      'podman restart $CONTAINER'
    ;;
  restart)
    CONTAINER="${1?Usage: podman_on_host.sh restart <container>}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" 'podman restart $CONTAINER'
    ;;
  switch)
    CONTAINER="${1?Usage: podman_on_host.sh switch <container> [tag]}"
    TAG="${2:-current}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" 'podman restart $CONTAINER'
    ;;
  rmi)
    IMAGE="${1?Usage: podman_on_host.sh rmi <image>}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" "podman rmi $IMAGE"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    echo "Usage: podman_on_host.sh <commit|commit_and_switch|restart|switch|rmi> [args]" >&2
    exit 1
    ;;
esac
