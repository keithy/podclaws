# Podclaw Architecture

This document provides a high-level overview of the Podclaws architecture. 
The goal is to provide a basis for both experimentation and production deployment. 
The distinguishing podclaw features are orthogonal to and useful for many agentic
frameworks. 

## Overview

### Data-Context-Interaction - like - Architecture

*credit - Trygve Reenskaug*

**Data** is mapped into a container, selected by the agentic framework, per-tennant,
per-user, per-chat-topic etc. While OpenClaw like agentic frameworks are built by
and for one user podclaw supports multi-channel operation out of the box.

Each agent chooses an activity based upon the data and input from its personality,
knowledge, memory, or skills. A working directory will form the assembled 
**context** for this activity. Within this **Context** the agent will provide a
definition of what specific tools (and versions of tools) are needed for the task. 
A library of (lazily) pre-installed tools is available to the container.

Agents perform their roles scoped within the container which provides
the venue for **Interaction**.

### Multiple Agentic Frameworks

A secure containerised architecture that efficiently supports multiple agentic frameworks.
e.g. goclaw, picoclaw, Pi

Local agent executable builds are explicitly decoupled from the deployment environment and
are published to the host and mapped into containers from there.

A deployed system can live-track new-releases in `./RELEASES/<name>/latest/<binary>`

### Rootless Podman

Rootless Podman, is the deployment runtime supported here; it provides
single-node support for both podman-compose, and kubernetes configurations.

Podclaws uses `podman compose`, as an evolutionary step towards using kubernetes for
production deployments. (`podman` directly generates kubernetes manifests from podman compose)

### Composable Features

`podclaw` is explicitly designed to support composeable features. The deployment can select which 
features and services are required. For example, `service.redis.yml` is optional.

### Composable Feature - Self-Improving Minimal Containers

The **self-improve** composable-feature lets any agent start with any miminal image and
install their own tools on demand. There are two options, 1) tools in-container,
and 2) tools in a shared library

- **`+self-improve.yml`** — apk (Alpine) or apt (Debian) for everything
  Python, Node, Go, etc. using the OS package manager, or
  venv support using `mise-en-place`. The base
  image is minimal; the agent installs what it needs and 
  **State is persisted by committing the image** (the command: `on-host-commit`)
  — the apk/apt/mise installs land in the container's read-write layer and
  survive across `podman compose down/up` IFF the image is committed.

- **`+mise-improve.yml`** — mise for language runtimes (python, node,
  go), language runtimes and downloads live in
  **the `mise-{musl,glibc}` shared volumes** (host-side, mostly persistent
  across container recreates without committing)

### Tools Library

- Having one library of tools of various versions shared among containers,
  projects, dev-containers, developer-workspaces is made possible using
  a tool like `mise-en-place`. This strategy keeps the containers themselves
  minimal, encouraging the use of multiple sandboxes.

### Lazy-shims

"Fake it till you make it!" - We fool gateways that may expect a fully tool-loaded
context into working with minimal containers using a shim layer at `/usr/local/sbin/`. 
These thin wrappers call installers on-demand.

When goclaw's hardcoded `exec.Command("python", ...)` runs, the shell
walks PATH, finds the shim as a last-resort fallback, which then calls
an installer `add-python` to bootstrap the real binary which lands earlier
on the path, effectivly replacing the shim.

### add-mise

The **`/usr/local/sbin/add-mise` installer** is self-bootstrapping: it can
fetch the upstream mise release and install it itself if not already available. 

### Container to Host Actions

To persist the container's state across recreates, run `on-host-commit`
from inside the container. That queues a host-side `podman commit` via
the sensible task queue, captures the read-write layer as `localhost/goclaw:next`.

## Core Goals

- Manage the lifecycle of multiple AI agents (`goclaw`, `picoclaw`) running in **rootless Podman** containers.
- Allow agents to self-improve and install their own tools and dependencies dynamically, without baking them into base images.
- Containers, for work isolation and sandboxing.
- Minimal Dockerfiles policy (use buildah in preference)
- A unified system for managing tools (Python, Node, Deno, Go etc.), per project/task inside the containers.
- Universal support for virtual environments for all tooling (not just python venv).
- **No Base Bloat**: By default base images only contain the bare minimum (`ca-certificates`, `sudo`, `curl`).
- **Lazy Bootstrapping**: tool use can self-fulfil, via shims mechanism.
- Option of native or `mise` managed tools
- Agent and skills that understand this system to provide self-management.
- ZFS backend filesystem for data integrity to guard against 'AI mistakes' (low-level snapshot every 15 minutes)
- Postgres data store, as a core feature and resource.
- Shared library of installed tools in a cluster mountable volume. (for multiple uses, including developer workspaces)
- Project-Level tool configuration - agents or users define `<project>/mise/config.toml`.

### Secure Host Communication (Sensible)

- AI agents inside the container use `sensible` to queue and execute validated `execlineb` scripts on the host, eliminating the need for direct shell or SSH access from the container to the host. The host defines a very restricted whitelist of valid actions.

```

 "whitelist": [
    "^podman commit",
    "^podman rmi",
    "^podman tag",
    "^podman restart"
  ],
  "blacklist": ["^.*"]
  ```