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

## 3. Persistence: podman commit + named volumes

Two complementary mechanisms:

- **Image read-write layer (podman commit)** — `apk add` / `apt-get install`
  packages land in the image's read-write layer. To persist, commit the
  running container: `podman commit <ctr> localhost/goclaw:current-improved`,
  then update the service's `image:` line. Used by both
  `+self-improve.yml` (native, apk/apt) and `+mise-improve.yml` (mise falls
  back to apk/apt for system tools).

- **Named volumes (mise only)** — when the mise overlay is in play, two
  named podman volumes are declared:
  - `mise-musl` mounted at `/usr/share/mise` — holds the prebuilt mise
    binary, lua 5.1 library, and per-version language installs
    (`installs/python/3.12.13/...`, `installs/node/24.14.1/...`, etc.).
  - `mise-cache` mounted at `/app/.cache/mise` — holds downloaded tarballs,
    wheels, and source files for cache hits across versions and containers.

  These volumes survive `podman compose down` and `podman rm`. The next
  container that needs `python@3.12.13` finds it already extracted and
  skips the download/extract step. Named volumes are also
  architecture-/libc-specific: do not share a `mise-musl` volume between
  musl (Alpine) and glibc (Debian, RHEL) containers.

  The shim layer at `/usr/local/sbin/` is **ephemeral** — re-applied by
  the compose overlay on every container start. This is intentional: a
  clean shim layer ensures fresh boots start with a predictable `PATH`.

See [docs/lazy-shims.md](lazy-shims.md#state-saving-podman-interface-vs-on-disk-cache)
for the full state-saving model and decision guide for which overlay to
pick.

## 4. Host Setup (Multi-User Shared Cache) — future work

The original design placed `MISE_DATA_DIR=/srv/auto_mise-glibc/_data` on the
host so multiple host users could share heavy toolchains via ZFS, with
per-user shims under `~/.local/share/mise/shims`. The current podclaws
deployment does not use this layout — named volumes are per-host and
shared at the podman level, not at the user level. Multi-user host
sharing is documented here for reference but is not currently wired up;
the actual host configuration is whatever the developer chooses for
their local mise install.

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