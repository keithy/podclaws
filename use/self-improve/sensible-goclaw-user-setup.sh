#!/bin/sh
# sensible-goclaw-user-setup.sh - setup sensible systemd units for goclaw self-improve
# Run this on the host before starting the goclaw container
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sensible-goclaw.json"
SETUP_DIR="$(cd "$SCRIPT_DIR/../sensible/systemd-path-user" && pwd)"

echo "Setting up sensible for goclaw self-improve..."
echo ""

"$SETUP_DIR/setup.sh" "$CONFIG_FILE"
