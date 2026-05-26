#!/bin/sh
if [ "$(id -u)" = "0" ]; then
  exec su-exec goclaw /app/goclaw "$@"
fi
exec /app/goclaw "$@"
