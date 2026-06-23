#!/usr/bin/env bash
# Generates COMPOSE_FILE from .env-compose selection, writes to .env
set -euo pipefail

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT}")" && pwd)"
# Project root is the parent of podman/. The script lives at
# <root>/podman/compose-services-select.sh and scans the project root
# for compose fragments.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_COMPOSE="$PROJECT_ROOT/.env-compose"
EDITOR="${EDITOR:-${VISUAL:-nano}}"

# Detect a "no editor" sentinel (e.g. EDITOR=false in non-interactive shells).
# In that case --edit should just print the current selection instead of opening
# an editor that doesn't exist.
if [[ "$EDITOR" == "false" || "$EDITOR" == ":" || "$EDITOR" == "" ]]; then
    EDITOR_AVAILABLE=false
else
    EDITOR_AVAILABLE=true
fi

loud() {
  [[ "${QUIET:-false}" != true ]] && echo "$@"
  true
}

# Find all compose yml files under the project root. The deepest legitimate
# path is <root>/use/<distro>/goclaw/<file>.yml (depth 4). Exclude the goclaw
# submodule (./goclaw/) and noise dirs (.git/, .github/).
find_compose_files() {
  local dir="$1"
  find "$dir" -maxdepth 4 \( -path "$dir/goclaw" -o -path "$dir/goclaw/*" -o -path "$dir/.git" -o -path "$dir/.git/*" -o -path "*/.github/*" \) -prune -o -name "*.yml" -print 2>/dev/null | sort
}

# Check if a file is a compose file by content
is_compose_file() {
  [[ "$1" == *.yml ]] || return 1
  grep -q "^services:\|^networks:\|^volumes:" "$1" 2>/dev/null
}

# Categorize a compose file by filename only
# . = service, + = overlay, otherwise = root
categorize_compose() {
  local name="${1%.yml}"
  [[ "$name" == *+* ]] && echo "overlay" && return
  [[ "$name" == *.* ]] && echo "service" && return
  echo "root"
}

# Read current COMPOSE_FILE from .env, return colon-separated list
read_compose_file() {
  if [[ -f "$ENV_FILE" ]]; then
    grep "^COMPOSE_FILE=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/^COMPOSE_FILE=//' | tr -d "'"
  fi
}

# Update a key=value line in .env safely
update_env() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed "s|^${key}=.*|${key}='${value}'|" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  else
    echo "${key}='${value}'" >> "$ENV_FILE"
  fi
}

# Write COMPOSE_FILE to .env
write_compose_file() {
  local new_value="$1"
  local old_value=$(grep "^COMPOSE_FILE=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/^COMPOSE_FILE=//' | tr -d "'")
  update_env "COMPOSE_FILE" "$new_value"
  if [[ "$old_value" != "$new_value" ]]; then
    echo "COMPOSE_FILE='$new_value'"
  fi
}

# Generate .env-compose from available files and current selection
do_generate() {
  local current_compose="${1:-}"
  local line

  echo "# Docker Compose file picker"
  echo "# Lines starting with # are disabled"
  echo "# Remove # to enable a file"
  echo ""

  local roots="" services="" overlays=""

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if is_compose_file "$line"; then
      local cat=$(categorize_compose "$line")
      local rel="${line#$PROJECT_ROOT/}"
      local enabled="# "
      if [[ -n "$current_compose" && "$current_compose" == *"$rel"* ]]; then
        enabled=""
      fi
      case "$cat" in
        root) roots="${roots}${roots:+$'\n'}${enabled}${rel}" ;;
        service) services="${services}${services:+$'\n'}${enabled}${rel}" ;;
        overlay) overlays="${overlays}${overlays:+$'\n'}${enabled}${rel}" ;;
      esac
    fi
  done < <(find_compose_files "$PROJECT_ROOT")

  if [[ -n "$roots" ]]; then
    echo "# === ROOT (required) ==="
    echo "$roots"
    echo ""
  fi
  if [[ -n "$services" ]]; then
    echo "# === SERVICE (optional) ==="
    echo "$services"
    echo ""
  fi
  if [[ -n "$overlays" ]]; then
    echo "# === OVERLAY (optional) ==="
    echo "$overlays"
  fi
}

# Parse enabled files from .env-compose (uncommented, non-empty lines)
do_parse() {
  local result=""
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#\# }"  # remove "# " prefix
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ -n "$result" ]] && result="${result}:"
    result="${result}${line}"
  done < "$ENV_COMPOSE"

  echo "$result"
}

# Apply selection from .env-compose to .env
do_update() {
  if [[ ! -f "$ENV_COMPOSE" ]]; then
    loud "No .env-compose found. Run '$SCRIPT --generate' first."
    exit 1
  fi

  local selection
  selection=$(do_parse)

  if [[ -z "$selection" ]]; then
    loud "No compose files selected in .env-compose"
  fi

  write_compose_file "$selection"
  loud "Done. COMPOSE_FILE=$selection"
}

# Validate compose files with docker/podman compose config
do_check() {
  if [[ ! -f "$ENV_COMPOSE" ]]; then
    loud "No .env-compose found"
    exit 1
  fi

  # Source .env to get COMPOSE_FILE
  set -a
  source "$ENV_FILE" 2>/dev/null || true
  set +a

  local engine="${DOCKER_CMD:-docker}"
  if ! command -v "$engine" &>/dev/null; then
    loud "$engine not found"
    exit 1
  fi

  "$engine" compose config >/dev/null 2>&1 && loud "✓ Compose config valid" || loud "✗ Compose config invalid"
}

# Open editor, then apply
do_edit() {
  if [[ ! -f "$ENV_COMPOSE" ]]; then
    loud "Regenerating $ENV_COMPOSE..."
    local current
    current=$(read_compose_file)
    do_generate "$current" > "$ENV_COMPOSE"
  fi

  # If EDITOR is set to a no-op sentinel (e.g. "false" in non-interactive
  # shells, or empty), skip the editor and just apply the current selection.
  if [[ "$EDITOR_AVAILABLE" == false ]]; then
    loud "No editor available (EDITOR='$EDITOR'). Using current selection."
    do_update
    do_check
    return
  fi

  if ! "$EDITOR" "$ENV_COMPOSE"; then
    loud "Editor failed (EDITOR=$EDITOR)"
    exit 1
  fi

  do_update
  do_check
}

# Show help
show_help() {
  cat << EOF
Usage: $SCRIPT [--quiet] [--generate] [--update] [--edit] [--check] [--file <file>]

  --generate   Create/replace .env-compose from available compose files
  --edit        Open .env-compose in \$EDITOR, then apply to .env
  --update      Apply current .env-compose to .env
  --check       Validate compose config using \$DOCKER_CMD (default: docker)
  --file <f>    Copy <f> to .env-compose (-f also works)
  --quiet       Suppress normal output

  Finds all compose *.yml files under this directory.
  Reads .env-compose for file selection (uncommented lines = enabled).
  Writes resulting COMPOSE_FILE to .env

  .env-compose format:
    docker-compose.yml   # enabled
    # docker-compose.postgres.yml  # disabled (commented)
EOF
  exit 0
}

# Main
QUIET="${QUIET:-false}"
GENERATE=false
UPDATE=false
EDIT=false
CHECK=false
NEXT_FILE=""

for arg in "$@"; do
  if [[ "$NEXT_FILE" ]]; then
    cp "$arg" "$ENV_COMPOSE"
    loud "Copied $arg to $ENV_COMPOSE"
    NEXT_FILE=""
    UPDATE=true
    CHECK=true
    [[ "$QUIET" != true ]] && do_update && do_check || true
  else
    case "$arg" in
      --quiet) QUIET=true ;;
      --generate) GENERATE=true ;;
      --update) UPDATE=true ;;
      --edit) EDIT=true ;;
      --check) CHECK=true ;;
      --help|-h) show_help ;;
      --file|-f) NEXT_FILE="yes" ;;
      --file=*|-f=*)
        src="${arg#--file=}"
        src="${src#-f=}"
        cp "$src" "$ENV_COMPOSE"
        loud "Copied $src to $ENV_COMPOSE"
        UPDATE=true
        CHECK=true
        ;;
      *) loud "Unknown: $arg" ;;
    esac
  fi
done

cd "$PROJECT_ROOT" >/dev/null 2>&1

# No args = help (unless FILE was set, which auto-sets UPDATE/CHECK)
if [[ "$GENERATE" == false && "$UPDATE" == false && "$EDIT" == false && "$CHECK" == false ]]; then
  show_help
fi

if [[ "$GENERATE" == true ]]; then
  loud "Generating $ENV_COMPOSE..."
  current=$(read_compose_file)
  do_generate "$current" > "$ENV_COMPOSE"
  loud "Generated $ENV_COMPOSE"
fi

if [[ "$EDIT" == true ]]; then
  do_edit
fi

if [[ "$UPDATE" == true && "$QUIET" != true ]]; then
  do_update
fi

if [[ "$CHECK" == true && "$QUIET" != true ]]; then
  do_check
fi
