# Podclaws on Podman 

Podclaws is intended as a production ready environment that supports multiple
agentic framework implementations. e.g. goclaw, picoclaw, etc.

Rootless Podman, is the deployment runtime supported here, and it provides
single-node support for both podman-compose, and kubernetes configurations.

GoClaw uses `docker compose` out of the box. Podclaws uses `podman compose`, as an
evolutionary step towards using kubernetes for production deployments.

Local executable builds are explicitly decoupled from the deployment environment and
are published to `./RELEASES/<name>/<version>/<binary>` and mapped into containers
from there

## Podman vs Docker

| Aspect | Docker | Podman |
|--------|--------|--------|
| Daemon | Runs as root | Daemonless (rootless by default) |
| Socket | `/var/run/docker.sock` | `/run/user/$UID/podman/podman.sock` |
| Default network | `172.17.0.0/16` | `10.88.0.0/16` |
| Compose command | `docker compose` | `podman compose` |

### Setup

#### 1. Enable Rootless Podman Environment

```bash
# /code/podclaws/podman/setup-rootless.sh
mise run podman:setup
``````bash
# /code/podclaws/podman/setup-rootless.sh
mise run podman:setup
```

- Uses environment modifier `./mise/config.podman.toml` 
- Moves `miserc.toml` → `./.miserc.toml` (sets `MISE_ENV = "podman"`)
- Copied rootless podman config files to `~/.config/containers/` 

#### 2. Batteries Included Defaults (ZFS friendly)

Podman volume_path = `/srv` (why not?)

Assuming that a ZFS user will have separately mapped `/home/<user>`  directories into
a ZFS volume by default, placing our data volumes at `/srv/` simplifies the task
of mapping them individually to their own ZFS volumes. The goal being to map the
entireity of goclaw data into a single heirarchy of volumes, so that a backup 
volume snapshot becomes a single atomic operation.

In contrast placing podman storage at `/opt/storage` is intended to have the opposite
effect. Moving it out of `/home` simplifies choosing which filesystem options to use
underneath docker/podman's overlayfs filesystem. /opt is likly to be the same filesystem
as / (i.e. f2fs, ext4, or xfs)

```bash
# (may require tweaking)
/code/podclaws/zfs/setup.sh
```

#### Mise config

The mise config (`config.podman.toml`) sets up:
- `DOCKER_CMD=podman` - tasks use podman instead of docker
- `docker = "podman"` alias - shell compatibility so `docker` commands work
- `BUILDAH_FORMAT=docker` for healthcheck support

### UID/GUI Mapping

Where possible files should be accessible to users both in and
out of the container. To acheive this we run as the same user and group.

It also facilitates backup/snapshot and restore of volumes across different hosts.
Anticipating migration of test agents, via lift and shift of their data volumes
via zfs send.

An additional challenge is a preference to use umask 0002 for 
container processes, so that group membership IS significant for multiple
users with a coder/developer GID.

See what the situation is:
```bash
mise run podman:ids-map
```

This shows how your host UID maps inside containers:
```
UIDS: (Container)(host)   (range)
0         1000      1
```

If your UID isn't mapped, you' may get permission errors.

### 3. Select composition of services and overlays

`podman compose` expects `COMPOSE_FILE` to be set with a list of yaml fragments
that make up all of the services in the whole pod. This is maintained in `.env`
and the following utility script allows you to select which items to include.

```bash
#/code/podclaws/podman/compose-services-select.sh --generate
#/code/podclaws/podman/compose-services-select.sh --edit

mise run services:select
```

## Environment Variables

Set in `mise/podman-resources/mise.podman.toml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_CMD` | `docker` | CLI command (`podman` or `docker`) |
| `PODMAN_COMPOSE_WARNING_LOGS` | `false` | Suppress podman-compose warnings |

## Self-Improve

By default, Docker uses `pkg-helper` (a root socket daemon) and isolates Pip/
NPM installations into `/app/data/.runtime`. Since we use rootless Podman and commit our environments, this behavior is changed:

1. **System Packages (`apk`)**: The `pkg-helper` daemon is bypassed. Because of upstream PR (#1210), GoClaw runs `/bin/pkg-helper <pkg>` as a standard subprocess. This unprivileged binary detects it is not root and automatically prefixes its internal commands with `sudo -n apk`, leveraging the container's sudo capabilities directly.
2. **Pip/NPM & Runtimes (Managed via `mise`)**: We do not bake `python` or `node` into our minimal base images. Instead, we map a set of **lazy shims** into the container's `PATH` via `service.goclaw.yml`. 
   - When an agent calls a tool for the first time (e.g., `python` or `node`), our lazy shim intercepts it.
   - The shim bootstraps `mise` and installs the requested tool globally (`mise use -g python@latest`).
   - `mise` natively generates its own shims in `~/.local/share/mise/shims`.
   - Because `~/.local/share/mise/shims` is mapped to the *very front* of the container's `PATH`, all subsequent calls hit the native `mise` shim and bypass our lazy wrapper completely.
3. **Persistence**: Since packages and runtimes are installed directly into the container's filesystem by `mise`, they are persisted by committing the Podman container to an image, rather than relying on volume mounts.

## Tasks

Available mise tasks:
- `mise run podman-enable` - Enable podman environment
- `mise run services-list` - List compose services
- `mise run ids-map` - Check UID mapping
- `mise run build-sandbox` - Build sandbox image (when needed)

## Troubleshooting

### "user cannot be mapped"

Your UID is not in `/etc/subuid`. Fix:
```bash
sudo usermod -v $(id -u)-$(($(id -u)+10000)) $(whoami)
```

