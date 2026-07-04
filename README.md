# Podclaws

Agent launcher for rootless Podman — runs **goclaw**, **picoclaw**, and other AI agents as rootless containers with **sensible** to-host communication.

## What It Does

Podclaws orchestrates multiple AI agents under rootless Podman. Each agent runs in a minimal Alpine container with its binary **volume-mounted from `RELEASES/`** (no rebuild needed to update). Containers may communicate with the host to run whitelisted tasks via **sensible** — a hardened exec tool that uses `execlineb` (not shell) to prevent command injection.

```
Container (alpine)              Host
───────────────                 ───
goclaw / picoclaw        →      sensible-server → execlineb scripts
(binary volume-mounted,         (whitelisted host tasks)
 misec.toml driven)
```

## Status

- **goclaw** — builds, runs in podman, host commit/restart
- **picoclaw** — builds

## Agents

| Agent | Description |
|-------|-------------|
| **goclaw** | Multi-tenant AI gateway — WebSocket RPC + HTTP API, 11+ LLM providers, 5 channels. Upstream: <https://github.com/nextlevelbuilder/goclaw> |
| **picoclaw** | Personal AI agent — lightweight, skill-based. Upstream: <https://github.com/sipeed/picoclaw> |

## Architecture (high level)

- **`use/goclaw/`** — builds versioned goclaw binaries to `RELEASES/goclaw/{amd64,arm64}/<version>/` and ships the skeleton `service.goclaw.yml` + `service.upgrade.yml` + overlay fragments (`+code.yml`, `+self-improve.yml`).
- **`use/picoclaw/`** — same pattern for picoclaw.
- **`goclaw/`, `picoclaw/`** — submodules of the upstream sources (synced via `use/*/Makefile` targets).
- **`sensible/`** — host execution bridge (Go + `execlineb`).
- **`podman/`** — rootless Podman configuration, compose-file selector, network/user overlays.
- **`compose.yml`** — root compose: declares the `default` bridge network and the `mise-musl`, `mise-glibc`, `mise-cache` volumes. This is a fragment (input), not the rendered output.
- **`RELEASES/`** — built binaries, gitignored, versioned by tag.

For a deeper architecture description (hybrid mise shims, ZFS-backed volumes, sensible whitelist) see [`docs/architecture.md`](docs/architecture.md). For Podman-specific setup see [`docs/podman.md`](docs/podman.md).

## Quick Start

```bash
# Build goclaw binary for current arch (uses GOCLAW_USE_BRANCH from mise/config.toml)
mise run goclaw:build

# Edit the list of compose fragments to combine
mise run services:select

# Bring the stack up (rootless podman)
podman compose up -d

# Dashboard: http://localhost:18790
```

## mise Tasks

| Task | Description |
|------|-------------|
| `goclaw:build` | Build goclaw binary using the Makefile in `use/goclaw` |
| `goclaw:sync` | Sync goclaw `main` and `dev` with upstream |
| `goclaw:image` | Build goclaw container image (`localhost/goclaw:current` / `:base`) |
| `services:select` | Pick which compose fragments to combine (writes `COMPOSE_FILE` to `.env`) |
| `podman:setup` | Enable rootless Podman environment |
| `podman:ids-map` | Show host↔container UID mapping |
| `podman:fix-permissions` | Repair volume permissions |
| `podman:logs-clear` | Clear podman journal logs |
| `zfs:setup` | Configure ZFS datasets for mise volumes (idempotent) |
| `zfs:status` | Show ZFS dataset status |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOCLAW_USE_BRANCH` | `main` | Branch to build / sync (set in `mise/config.toml`) |
| `GOCLAW_DEPLOY_VERSION` | `latest` | version to deploy |
| `GOCLAW_PORT` | `18790` | Web UI port |
| `DOCKER_CMD` | `docker` | CLI command (`podman` in `mise/config.podman.toml`) |
| `MISE_DATA_DIR` | `mise` | mise data dir (host-side) |
| `MISE_NOTES_DIR` | `mise/notes` | mise notes dir |

## Project Layout

```
podclaws/
├── use/
│   ├── goclaw/            # GoClaw binary builder + compose fragments
│   ├── picoclaw/          # PicoClaw binary builder
│   ├── self-improve/      # Self-improve skill + sbin
│   └── original/          # Legacy / reference compose fragments
├── goclaw/                # GoClaw upstream submodule
├── picoclaw/              # PicoClaw upstream submodule
├── sensible/              # Host exec bridge
├── podman/                # Rootless Podman config + compose selector
├── postgres/              # Postgres low-CPU overlay
├── mise/                  # mise task definitions
├── docs/                  # Architecture, podman, execline tutorial
├── config/                # nginx config (mounted into goclaw-ui overlay)
├── podman-compose.yml     # Root compose: networks + mise volumes
└── RELEASES/              # Built binaries (gitignored)
```

## See Also

- [docs/architecture.md](docs/architecture.md) — Hybrid shim model, ZFS-backed volumes, sensible whitelist
- [docs/podman.md](docs/podman.md) — Rootless Podman setup, UID mapping, services selector
- [docs/EXECLINE_TUTORIAL.md](docs/EXECLINE_TUTORIAL.md) — Writing execline scripts for sensible
- [docs/compose-selection.md](docs/compose-selection.md) — How `COMPOSE_FILE` is built from `+overlay` / `service` / root fragments
- [docs/goclaw-pid1-zombies.md](docs/goclaw-pid1-zombies.md) — goclaw-as-PID-1 zombie issue, local `init: true` workaround, upstream fix options
- [docs/lazy-shims.md](docs/lazy-shims.md) — how the `sbin/<tool>` shims proxy to `add-*` installers so goclaw's hardcoded install action works
- [goclaw README](goclaw/README.md) — GoClaw itself
- [picoclaw README](picoclaw/README.md) — PicoClaw itself
- [sensible README](sensible/README.md) — Host exec bridge
