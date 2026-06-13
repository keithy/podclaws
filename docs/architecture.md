# Podclaws Architecture

This document provides a high-level overview of the Podclaws architecture, focusing on its hybrid environment management and secure host communication model.

## 1. Core Goals

- Manage the lifecycle of multiple AI agents (`goclaw`, `picoclaw`) running in **rootless Podman** containers.
- Allow agents to install their own tools and dependencies dynamically, without baking them into base images.
- Strictly isolate the host from the containers, and the container from the agent's environment.

## 2. The Hybrid Lazy Shim Architecture

A unified system for managing Python, Node, Deno, Go, and other runtimes inside the containers:

- **No Base Bloat**: Base images only contain the bare minimum (`ca-certificates`, `sudo`, `wget`).
- **Lazy Bootstrapping**: When an agent requests a tool (e.g., `python`), the OS `PATH` routes the call to a shim in `/usr/local/sbin/`.
- **On-Demand Installation**: The shim invokes `mise` to install the tool globally (`mise use -g python@latest`) using the persisted data directory.
- **Native Handover**: `mise` automatically generates its own shims in the ephemeral directory, which take priority on the `PATH` for all subsequent calls.

## 3. Hybrid Persistence

We split `mise`'s data into two distinct volumes on a shared ZFS filesystem:

- **Heavy Installs (Persisted, Shared via ZFS)**: Compiled toolchains are stored under `/srv/mise/installs/{glibc,musl}`. This volume is shared across all containers (and host users) with matching libc. Survives container restarts.
- **Downloaded Tarballs (Persisted, Architecture-Independent)**: Downloaded tarballs, wheels, and source files live in `/srv/mise/cache`. This volume is shareable across any container type (Alpine, Ubuntu, etc.) for maximum cache hits.
- **Shims (Ephemeral)**: The routing shims in `/app/.local/share/mise/shims` (containers) and `~/.local/share/mise/shims` (host) are local to each environment, ensuring fresh boots start with a clean, predictable `PATH`.

## 4. Host Setup (Multi-User Shared Cache)

On the host, the system-wide `/etc/profile.d/mise.sh` configures:
- `MISE_DATA_DIR=/srv/mise/installs/glibc` — shared toolchains
- `MISE_SHIMS_DIR=~/.local/share/mise/shims` — per-user shims (preserves version autonomy)

This lets multiple users on the host share the same heavy toolchains via ZFS while independently selecting their own tool versions.

## 5. Project-Level Configurations

- Agents (or users) define project-specific tool versions in `<project>/mise/config.toml`.
- Local configurations take priority over the global fallbacks.

## 6. Secure Host Communication (Sensible)

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