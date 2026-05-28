#!/bin/sh
# sensible_on_host_do.sh - queue scripts for host execution
# Client end of sensible protocol (ash/busybox compatible)

set -euo pipefail

usage() {
  echo "Usage: sensible_on_host_do.sh <script> [<script>...]" >&2
  echo "  Queue execline scripts for host execution." >&2
  exit 1
}

TASKS_DIR="${HOST_TASKS_DIR:-/app/data/.runtime/sensible/tasks}"

# Create pending directory
mkdir -p "$TASKS_DIR/pending" 2>/dev/null || mkdir -p "$TASKS_DIR" 2>/dev/null

# Get current timestamp as RFC3339
timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# Save task as JSON file
save_task() {
  local file_id="$1"
  local request="$2"
  local run_next="${3:-}"
  local task_file="$TASKS_DIR/pending/${file_id}.json"

  # Simple JSON (no quoting/escaping for now)
  if [ -n "$run_next" ]; then
    cat > "$task_file" << EOF
{
  "file_id": "$file_id",
  "id": "$(echo "$file_id" | cut -d'-' -f1)",
  "request": "$request",
  "status": "queued",
  "timestamp": "$(timestamp)",
  "run_next": "$run_next"
}
EOF
  else
    cat > "$task_file" << EOF
{
  "file_id": "$file_id",
  "id": "$(echo "$file_id" | cut -d'-' -f1)",
  "request": "$request",
  "status": "queued",
  "timestamp": "$(timestamp)"
}
EOF
  fi
}

[ $# -lt 1 ] && usage

prev_file_id=""
script_num=1

for script in "$@"; do
  [ -z "$script" ] && echo "Error: empty script" >&2 && exit 1

  file_id="$(timestamp)-script-${script_num}"

  # If there's a previous task, update its runNext to point to this task
  if [ -n "$prev_file_id" ]; then
    # Load previous task and add runNext to it
    prev_task_file="$TASKS_DIR/pending/${prev_file_id}.json"
    if [ -f "$prev_task_file" ]; then
      # Update the runNext field in previous task
      sed -i "s/\"status\": \"queued\"/\"status\": \"queued\",\n  \"run_next\": \"$file_id\"/" "$prev_task_file" 2>/dev/null || true
    fi
  fi

  # Save current task
  save_task "$file_id" "$script" ""
  echo "$file_id"

  prev_file_id="$file_id"
  script_num=$((script_num + 1))
done
