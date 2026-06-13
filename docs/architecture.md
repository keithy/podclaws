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

- **Heavy Installs (Persisted)**: Actual tool binaries are stored in the container volume at `/app/data/.runtime/mise`. They survive container restarts.
- **Shims (Ephemeral)**: The routing shims in `/app/.local/share/mise/shims` are local to the container, ensuring fresh containers boot with a clean, predictable `PATH`.

## 4. Project-Level Configurations

- Agents (or users) define project-specific tool versions in `<project>/mise/config.toml`.
- Local configurations take priority over the global fallbacks.

## 5. Secure Host Communication (Sensible)

- AI agents inside the container use `sensible` to queue and execute validated `execlineb` scripts on the host, eliminating the need for direct shell or SSH access from the container to the host.
