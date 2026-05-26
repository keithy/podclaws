# Podclaws

Agent launcher for rootless Podman — runs GoClaw, PicoClaw, and other AI agents as rootless containers with sensible host communication.

## What It Does

Podclaws orchestrates multiple AI agents under rootless Podman. Each agent runs in an isolated Alpine container with a volume-mounted binary (no rebuild needed to update). The container communicates with the host via **sensible** — execlineb scripts that prevent shell injection and restrict AI actions to explicit allowlists.

```
Container (alpine)          Host
───────────────             ───
goclaw/picoclaw       →     sensible-server → execlineb scripts
(goclaw binary              (whitelisted host tasks)
 volume-mounted)
```

## Agents

| Agent | Description |
|-------|-------------|
| **GoClaw** | Multi-tenant AI gateway — WebSocket RPC + HTTP API, 11+ LLM providers, 5 channels |
| **PicoClaw** | Personal AI agent — lightweight, skill-based |

## Architecture

- **goclaw-build/** — builds versioned binaries to `RELEASES/goclaw/{amd64,arm64}/{version}/`
- **compose.yml** — skeleton Alpine container, binary mounted in
- **+binary.yml** — compose override for volume-mounting local binaries
- **+dockerfile.yml** — compose override for Dockerfile-based builds
- **sensible/** — host execution bridge (execlineb, not shell)
- **self-buildah-orig/** — reference: self-building container approach (container evolves itself)

## Quick Start

```bash
# Build binary for current arch
cd goclaw-build && make build

# Launch with volume-mounted binary
podman compose -f goclaw-build/compose.yml -f goclaw-build/+binary.yml up -d

# Or build from Dockerfile
podman compose -f goclaw-build/compose.yml -f goclaw-build/+dockerfile.yml up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOCLAW_DEPLOY_VERSION` | `arm64/latest` | Arch/version to deploy |
| `GOCLAW_RELEASES` | `../RELEASES/goclaw` | Path to releases dir |
| `GOCLAW_PORT` | `18790` | Web UI port |

## Projects

```
podclaws/
├── goclaw-build/        # Binary builder
├── goclaw/              # GoClaw submodule (nextlevelbuilder/goclaw)
├── sensible/            # Sensible host execution bridge
├── self-buildah-orig/   # Self-building container reference
├── podman/              # Rootless Podman configuration
└── RELEASES/            # Built binaries (gitignored)
```

## See Also

- [GoClaw](https://github.com/nextlevelbuilder/goclaw) — the AI gateway
- [PicoClaw](https://github.com/nextlevelbuilder/picoclaw) — personal AI agent
- [Self-Building Container](./SELF_BUILDING.md) — alternative approach: container that builds itself
- [Podman Setup](./docs/goclaw-podman.md) — Podman-specific configuration