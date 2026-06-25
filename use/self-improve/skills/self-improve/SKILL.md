---
name: self-improve
description: Tool for building and managing container images from inside the container. Provides scripts for committing container state, switching between versions, and installing packages.
metadata: {"goclaw":{"emoji":"🛠️","requires":{},"install":[]}}
---

# Self-Improve Skill

A skill for modifying and managing the running container's image from inside the container.

## Overview

When you run installers or make changes inside the container, you can use these tools to:
1. **Commit** the changes to a named image
2. **Switch** to a different version
3. **Install** additional packages

## Scripts

All commands queue a task for the host's `sensible-consume` to execute; they
return immediately. The container is **not restarted** by `commit` itself —
run `podman compose down && up` (or `on-host-podman restart`) afterwards to
launch the new `:current`.

### Committing Changes

```bash
# Atomic commit. Snapshots :current → :previous, then captures the
# container's read-write layer directly as the new :current image.
on-host-podman commit
```

Equivalent one-liner used by the agent:
```bash
on-host-commit   # just calls `on-host-podman commit`
```

### Switching to an Existing Tag

```bash
# Promote an existing tag (e.g. :previous, :base) to :current.
on-host-podman switch <tag>
```

Example:
```bash
on-host-podman switch previous
# Snapshots :current → :previous, then tags :previous → :current.
```

### Just Restart

```bash
# Restart container without changing image
on-host-podman restart
```

### Reset to Base

```bash
# Roll :current back to :base and restart
on-host-podman reset_and_switch
```

## Image Tags

| Tag | Purpose |
|-----|---------|
| `base` | Build-time anchor (set by `make image`; reset target) |
| `current` | The image launched by `podman compose up`; updated on every commit |
| `previous` | One-step rollback target (snapshot of `:current` at each commit) |

`commit` writes **directly** to `:current`. No intermediate `:next` tag — the
atomic dance (rmi `:previous`, tag `:current` → `:previous`, commit) keeps the
running image and the rollback anchor consistent.

## Workflow Examples

### Typical Development Cycle

```bash
# 1. Make changes inside container
apk add --no-cache newpackage

# 2. Test changes
# (run the relevant tests in tests/ — e.g. ./tests/on-host-sensible-do_spec.sh)

# 3. Commit atomically — :current now reflects the new state
on-host-podman commit

# 4. Restart to launch the new :current
podman compose -f <stack> down && podman compose -f <stack> up -d

# 5. If broken, roll back
on-host-podman switch previous
podman compose -f <stack> down && podman compose -f <stack> up -d
```

### Testing Before Switching

Use `switch` to promote an existing tag (e.g. one you built locally and
tagged as `:test-version`):

```bash
# Promote a tagged image to :current
on-host-podman switch test-version
podman compose -f <stack> down && podman compose -f <stack> up -d

# ... test the version ...

# Roll back
on-host-podman switch previous
podman compose -f <stack> down && podman compose -f <stack> up -d
```

### Testing Before Switching

Use `switch` to promote an existing tag (e.g. one you built locally and
tagged as `:test-version`):

```bash
# Promote a tagged image to :current
on-host-podman switch test-version
podman compose -f <stack> down && podman compose -f <stack> up -d

# ... test the version ...

# Roll back
on-host-podman switch previous
podman compose -f <stack> down && podman compose -f <stack> up -d
```

### Bulk Reset

```bash
# Roll back to the build-time :base image (e.g. from `make image`)
on-host-podman reset_and_switch
```

## How It Works

1. Scripts are queued via sensible (file-based task queue)
2. Host's sensible-consume processes the queue
3. Podman commands execute on host
4. Changes persist across container restarts

## Package Installation

Inside the container, you can run add-* scripts to install packages:

```bash
./alpine-native-installers/add-bash        # Install bash shell
./alpine-native-installers/add-node        # Install Node.js
./alpine-native-installers/add-python      # Install Python
./alpine-native-installers/add-execline    # Install execline shell
./alpine-native-installers/add-gh          # Install GitHub CLI
./alpine-native-installers/add-oils        # Install Oil shell
./alpine-native-installers/add-office      # Install office tools
```

After installing packages, commit the changes to persist them.
