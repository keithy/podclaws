#!/usr/bin/env bash
# Setup podman rootless server config
# Copies pre-configured files to ~/.config/containers/

set -euo pipefail

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT}")" && pwd)"
GOCLAW_DIR="$(realpath $SCRIPT_DIR/../goclaw)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_help() {
  echo "Usage: $SCRIPT [--help|--test]"
  echo "  Sets up podman configuration for rootless server"
  echo ""
  echo "Environment variables:"
  echo "  USER_CONFIG_DIR  Override config directory (for testing)"
}

# Ask user yes/no
ask() {
  local prompt="$1"
  local default="${2:-}"
  local response

  if [[ "$interactive" != true ]]; then
    case "$default" in
      n|[nN][oO]) return 1 ;;
      *) return 0 ;;
    esac
  fi

  while true; do
    case "$default" in
      y) printf "${YELLOW}%s [Y/n]${NC}: " "$prompt" ;;
      n) printf "${YELLOW}%s [y/N]${NC}: " "$prompt" ;;
      *) printf "${YELLOW}%s [y/n]${NC}: " "$prompt" ;;
    esac
    if ! read -r response </dev/tty 2>/dev/null; then
      echo
      return 1
    fi

    case "${response:-$default}" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO]) return 1 ;;
    esac
    echo "Please answer y or n"
  done
}

# Self-test
self_test() {
  local failed=0
  local tmp_dir=$(mktemp -d)

  echo "Running self-tests..."

  # Test: help
  "$SCRIPT" --help > /dev/null 2>&1 || { echo "FAIL: help"; failed=1; }

  # Test: with fake config dir
  USER_CONFIG_DIR="$tmp_dir/.config/containers" "$SCRIPT" <<< $'n\nn\n' > /dev/null 2>&1 || { echo "FAIL: run with fake dir"; failed=1; }

  rm -rf "$tmp_dir"
  if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
  else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  fi
}

# Handle args
[[ "${1:-}" == "--test" ]] && { self_test; exit 0; }
[[ "${1:-}" == "--help" ]] && { print_help; exit 0; }

# Non-interactive fallback
interactive=true
if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
  interactive=false
fi

# Setup config directory
CONFIG_DIR="${USER_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/containers}"
mkdir -p "$CONFIG_DIR"

# ─── Header ───────────────────────────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Podman Rootless Server Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "This will create/edit the following files in:"
echo -e "  ${YELLOW}$CONFIG_DIR${NC}"
echo ""

# ─── Explain each file ────────────────────────────────────────────
echo -e "${BLUE}Files to be copied:${NC}"
echo ""
echo -e "config/containers/ → $CONFIG_DIR/"
echo -e "  • containers.conf, registries.conf, storage.conf"
echo ""

# ─── Existing files warning ───────────────────────────────────────
if [[ -d "$CONFIG_DIR" ]] && [[ -n "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
  echo -e "${YELLOW}⚠ Existing config files detected:${NC}"
  ls -la "$CONFIG_DIR"
  echo ""
fi

echo -e "${YELLOW}NOTE:${NC}"
echo "  • Existing files will NOT be overwritten"
echo ""

# ─── Confirm ──────────────────────────────────────────────────────
if ! ask "Proceed with setup?" y; then
  echo "Aborted."
  exit 0
fi

# ─── Copy files ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}─── Installing configs ────────────────────────────────────${NC}"

cp -r "$SCRIPT_DIR/config/containers/." "$CONFIG_DIR/"

# ─── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Setup Complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Config files in: ${YELLOW}$CONFIG_DIR${NC}"
ls -la "$CONFIG_DIR" 2>/dev/null || true
echo ""


# ─── Environment variables ───────────────────────────────────────
echo -e "${BLUE}─── Environment Variables ───────────────────────────────${NC}"
echo ""

if command -v mise &>/dev/null; then

  echo "Mise detected — ./mise/config.podman.toml is available for env config."

  if [[ ! -f "$SCRIPT_DIR/../.miserc.toml" ]]; then
    cp "$SCRIPT_DIR/config/miserc.toml" "$SCRIPT_DIR/../.miserc.toml"
    echo -e "  ${GREEN}✓ Copied: .miserc.toml${NC}"
  else
    echo -e "  ${YELLOW}— Skipped (exists): .miserc.toml${NC}"
  fi

  echo "config.podman.toml sets env_file = \".env\" to auto-load .env on cd."
  echo ""
  echo "Verify environment:"
  echo -e "  ${YELLOW}mise env${NC}"
  echo ""
else
  echo "Without mise, you must source .env manually (.bashrc?) before compose:"
  echo -e "  ${YELLOW}set -a && source .env && set +a && podman compose up -d${NC}"
fi

echo ""
echo -e "Run ${YELLOW}podman info${NC} to verify configuration."
echo ""


