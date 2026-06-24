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

### Committing Changes

```bash
# Commit current container state as a named image
# Tag defaults to "next"
on-host-podman commit <container> [tag]
```

Example:
```bash
on-host-podman commit mycontainer my-feature
# Creates: localhost/goclaw:my-feature
```

### Switch Versions

```bash
# Switch container to use a different image tag, then restart
# Tag defaults to "next"
on-host-podman switch <container> [tag]
```

Example:
```bash
on-host-podman switch mycontainer previous
# Tags :previous as :current and restarts
```

### Commit and Switch Atomically

```bash
# Commit and immediately switch in one atomic operation
# Tag defaults to "next"
on-host-podman commit_and_switch <container> [tag]
```

### Just Restart

```bash
# Restart container without changing image
on-host-podman restart <container>
```

### Reset to Base

```bash
# Reset container to base image and restart
on-host-podman reset_and_switch <container>
```

This saves current → previous, tags :base → :current, then restarts.

## Image Tags

| Tag | Purpose |
|-----|---------|
| `base` | Original alpine image (reset target) |
| `current` | The image currently running |
| `previous` | The image before last switch |
| `next` | Default tag for commits |
| custom | Any name you choose (e.g., `my-feature`) |

## Workflow Examples

### Typical Development Cycle

```bash
# 1. Make changes inside container
apk add --no-cache newpackage

# 2. Test changes
# (run the relevant tests in tests/ — e.g. ./tests/on-host-sensible-do_spec.sh)

# 3. If happy, commit
on-host-podman commit mycontainer feature-x

# 4. If it works, switch to it
on-host-podman switch mycontainer feature-x

# 5. If broken, roll back
on-host-podman switch mycontainer previous
```

### Testing Before Switching

```bash
# Commit but don't switch
on-host-podman commit mycontainer test-version

# ... test the version ...

# Only switch if tests pass
on-host-podman switch mycontainer test-version
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
