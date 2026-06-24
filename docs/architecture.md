# Podclaws Architecture

This document provides a high-level overview of the Podclaws architecture, focusing on its hybrid environment management and secure host communication model.

## TL;DR

The **self-improve** feature lets agents start with a miminal image and
install their own tools and runtimes on demand. Two compose overlays
select the installation strategy — pick one, not both:

- **`+self-improve.yml`** — apk (Alpine) or apt (Debian) for everything
  Python, Node, Go, etc. come from the OS package manager. The base
  image is minimal; the agent gets the OS-shipped versions. **State
  is persisted by committing the image** (`podman commit <ctr>
  localhost/goclaw:current-improved`) — the apk/apt installs land in
  the container's read-write layer and survive across `podman compose
  down/up` if the image is committed.

- **`+mise-improve.yml`** — mise for language runtimes (python, node,
  go), with apk/apt as fallback for system tools (bash, git, etc.).
  **State has two halves**: language runtimes and downloads live in
  **the `mise-{musl,glibc}` shared volumes** (host-side, persistent
  across container recreates without committing); local config and
  mise-managed tools land in the container's writable layer and
  **need `podman commit` to persist**.

Both overlays mount the same shared shim layer at `/usr/local/sbin/`
(thin wrappers in `use/self-improve/shared-sbin/`) and an installer
dir at `/usr/local/bin/` (the `add-python`, `add-node`, etc. scripts).
When goclaw's hardcoded `exec.Command("python", ...)` runs, the shell
walks PATH, finds the shim, which then calls the installer to
bootstrap the real binary. The shim at pos 10 is the last-resort
fallback; real binaries at `/usr/bin` (apk/apt installs) or
`/usr/share/mise/bin` (host-staged mise) win earlier in PATH.

To persist the container's state across recreates, run
`self-commit.sh` from inside the container. That queues a host-side
`podman commit` via the sensible task queue, captures the read-write
layer as `localhost/goclaw:<tag>`, and restarts the container with
the new image. The `podman_on_host.sh` and `sensible_on_host_do.sh`
sidecar scripts are the underlying mechanism; `self-commit.sh` is the
one-stop entry point.

The **`add-mise` installer** in `use/self-improve/shared-sbin/add-mise`
is self-bootstrapping: it can fetch the upstream mise release and
install it itself if neither the host-staged volume nor a previous
install has mise available. Set `MISE_STAGE_DIR` in the compose
overlay to control where it installs (`/usr/bin` in native mode,
`/usr/share/mise/bin` in mise mode).

See `docs/lazy-shims.md` for the shim mechanics, `use/mise/` for
the host-side mise staging Makefile, and `docs/podman.md` for
volume and state details.

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