# Compose File Selection

`podman compose` (and `docker compose`) treats a stack as a single list of YAML fragments, joined via the `COMPOSE_FILE` env var (colon-separated). Podclaws ships its services and overlays as **separate fragments** so the same files can be recombined for different deployments. The selector script at `podman/compose-services-select.sh` manages that combination.

## Mechanism

1. **Filename categories** (decoded from the filename only — not the contents):

   | Pattern | Category | Meaning |
   |---------|----------|---------|
   | `foo.yml` | `service` | Defines services, networks, or volumes |
   | `+foo.yml` | `overlay` | Patches or extends an existing service |
   | `foo.bar.yml` | `root` | Top-level compose file (e.g. defines the network) |

   The first `.` in the filename determines whether it is a root file; the leading `+` marks an overlay.

2. **`.env-compose`** is the human-edited selection file. Lines starting with `#` are disabled; uncommented lines are enabled. Sections (`# === ROOT ===`, `# === SERVICE ===`, `# === OVERLAY ===`) are generated for readability.

3. **`.env`** holds the resulting `COMPOSE_FILE=...` value (colon-separated), consumed by `podman compose` via `set -a; source .env; set +a` or the `--env-file` flag.

## Script Actions

```bash
# Generate a fresh .env-compose from all fragments under the current dir
podman/compose-services-select.sh --generate
# (or: mise run services:select -- --generate)

# Open .env-compose in $EDITOR, then write the resulting COMPOSE_FILE to .env
podman/compose-services-select.sh --edit
# (or: mise run services:select)

# Re-apply the current .env-compose to .env without opening the editor
podman/compose-services-select.sh --update

# Validate the resolved compose config (uses $DOCKER_CMD, defaults to docker)
podman/compose-services-select.sh --check
```

The mise wrapper task is `services:select` (in `mise/tasks/services/select`).

## Typical Workflow

```bash
# 1. Discover what's available
./podman/compose-services-select.sh --generate

# 2. Pick fragments (comment/uncomment lines in your editor)
./podman/compose-services-select.sh --edit

# 3. Validate before bringing the stack up
./podman/compose-services-select.sh --check

# 4. Run
podman compose up -d
```

## Where Fragments Live

| Directory | Purpose |
|-----------|---------|
| `podman-compose.yml` | Root: defines `default` and `goclaw-net` networks, the `mise-*` volumes |
| `use/goclaw/` | `service.goclaw.yml` (main), `service.upgrade.yml` (one-shot migrations), `+code.yml`, `+self-improve.yml` |
| `use/original/` | `service.goclaw.yml` — legacy full-Dockerfile build variant |
| `use/picoclaw/` | PicoClaw service (planned) |
| `podman/` | `+network-fix.yml`, `+user-fix.yml` — rootless-specific patches |
| `postgres/` | `+low-cpu.yml` — postgres resource limit overlay |

## Disabling a Selection Without Deleting It

Comment the line in `.env-compose` (prefix with `# `). The fragment stays on disk and the generator can re-enable it later.
