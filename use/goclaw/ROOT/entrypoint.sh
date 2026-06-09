#!/bin/sh
# optional wrapper for normal command

# podman does attempt to set this based upon setting in containers.conf
# 1. Set the umask for the environment
umask 0002

# 2. 'exec' replaces this shell process with your Go binary.
# Go becomes PID 1 and inherits the umask.
exec "$@"