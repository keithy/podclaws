#!/bin/sh
# optional wrapper for normal command

# Runtime check: Ensure mise shims appear before our sbin overlay in PATH
# If PATH is incorrectly ordered, our lazy shims might infinitely loop or
# obscure the actual mise native shims.
case "$PATH" in
    */app/.local/share/mise/shims*:/usr/local/sbin*)
        # Correct order
        ;;
    *)
        echo "WARNING: PATH is incorrectly ordered or missing directories!" >&2
        echo "Expected /app/.local/share/mise/shims to appear before /usr/local/sbin" >&2
        echo "Current PATH: $PATH" >&2
        ;;
esac

# podman does attempt to set this based upon setting in containers.conf
# 1. Set the umask for the environment
umask 0002

sudo chown -R $(id -u):$(id -g) "$HOME"

# 2. 'exec' replaces this shell process with your Go binary.
# Go becomes PID 1 and inherits the umask.
exec "$@"