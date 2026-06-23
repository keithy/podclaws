#!/bin/sh
# optional wrapper for normal command

# Runtime check: PATH ordering invariants.
# 1. /app/.local/share/mise/shims must appear (when present) so that mise's
#    shims take precedence over our fallback sbin shims.
# 2. /usr/local/sbin MUST be the last directory in PATH. It holds the lazy
#    shim layer (python, pip, node, etc.) and exists only as a fallback —
#    real tools at /usr/bin should always win. Putting sbin last ensures
#    goclaw's exec.Command("pg_dump", ...) finds /usr/bin/pg_dump first
#    and the shim only fires when the real binary is missing.
last_dir() {
    echo "$PATH" | tr ':' '\n' | awk 'NF' | tail -1
}

if ! echo "$PATH" | tr ':' '\n' | grep -qx '/app/.local/share/mise/shims'; then
    if [ -d /app/.local/share/mise/shims ]; then
        echo "WARNING: /app/.local/share/mise/shims exists but is not in PATH" >&2
    fi
fi

if [ "$(last_dir)" != "/usr/local/sbin" ]; then
    echo "WARNING: /usr/local/sbin must be the last PATH entry (got: $(last_dir))" >&2
    echo "Current PATH: $PATH" >&2
fi

# podman does attempt to set this based upon setting in containers.conf
# 1. Set the umask for the environment
umask 0002

sudo chown -R $(id -u):$(id -g) "$HOME"

# 2. 'exec' replaces this shell process with your Go binary.
# Go becomes PID 1 and inherits the umask.
exec "$@"