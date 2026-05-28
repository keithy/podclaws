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
    # Standalone commit - just save with tag, no current/previous dance
    CONTAINER="${1?Usage: podman_on_host.sh commit <container> [tag]}"
    TAG="${2:-next}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      "podman commit $CONTAINER localhost/goclaw:$TAG"
    ;;
  commit_and_switch)
    # Uses next/previous scheme, always becomes current
    CONTAINER="${1?Usage: podman_on_host.sh commit_and_switch <container> [tag]}"
    TAG="${2:-next}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      'if { podman rmi localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:current localhost/goclaw:previous } true' \
      "podman commit $CONTAINER localhost/goclaw:$TAG" \
      "if { podman tag localhost/goclaw:$TAG localhost/goclaw:current } true" \
      'podman restart $CONTAINER'
    ;;
  switch)
    # Copy standalone tag to current, then restart
    CONTAINER="${1?Usage: podman_on_host.sh switch <container> [tag]}"
    TAG="${2:-next}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      'if { podman rmi localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:current localhost/goclaw:previous } true' \
      "if { podman tag localhost/goclaw:$TAG localhost/goclaw:current } true" \
      'podman restart $CONTAINER'
    ;;
  restart)
    CONTAINER="${1?Usage: podman_on_host.sh restart <container>}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" 'podman restart $CONTAINER'
    ;;
  reset_and_switch)
    # Reset to base image and restart
    CONTAINER="${1?Usage: podman_on_host.sh reset_and_switch <container>}"
    "$SCRIPT_DIR/sensible_on_host_do.sh" \
      'if { podman rmi localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:current localhost/goclaw:previous } true' \
      'if { podman tag localhost/goclaw:base localhost/goclaw:current } true' \
      'podman restart $CONTAINER'
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    echo "Usage: podman_on_host.sh <commit|commit_and_switch|switch|restart|reset_and_switch>" >&2
    exit 1
    ;;
esac
