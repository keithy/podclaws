#!/bin/sh
# self-commit.sh - persist the container's state by committing the image.
#
# Wraps podman_on_host.sh commit_and_switch. The agent calls this from
# inside the container; the actual podman commit runs on the host
# (via the sensible task queue), then the container restarts with
# the new image.
#
# Usage: self-commit.sh [tag]
#   tag: image tag to commit as (default: next)
#
# Workflow:
#   1. Agent makes changes in the container (apk add, pip install, etc.)
#   2. Agent runs `self-commit.sh`
#   3. The host's sensible process picks up the queued task, runs
#      `podman commit` to capture the container's read-write layer
#      into a new image, and restarts the container with that image.
#   4. The new image is now localhost/goclaw:<tag>; rebuild the
#      service image with `make -C use/goclaw image` to bake it in.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-next}"

# Delegate to the existing podman_on_host.sh commit_and_switch verb.
# That script queues a sensible task that the host runs; the task does
# the actual podman commit + rmi + tag + restart sequence.
exec "$SCRIPT_DIR/podman_on_host.sh" commit_and_switch "$TAG"
