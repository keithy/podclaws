# Using Podman with GoClaw

Podclaws is intended as a production ready environment that supports multiple agent implementations.
Rootless Podman, is the deployment runtime supported, but the architecture is flexible.

GoClaw supports Docker Compose out of the box, the 'Podclaws' project explicitly decouples `goclaw`
executable development from the deployment environment.

This is achieved via some environment variables and additional config files.
This guide covers Podman-specific setup.

## Podman vs Docker

| Aspect | Docker | Podman |
|--------|--------|--------|
| Daemon | Runs as root | Daemonless (rootless by default) |
| Socket | `/var/run/docker.sock` | `/run/user/$UID/podman/podman.sock` |
| Default network | `172.17.0.0/16` | `10.88.0.0/16` |
| Compose command | `docker compose` | `podman compose` |

## Setup

### 1. Enable Rootless Podman Environment

```bash
/code/podclaws/podman/setup-rootless.sh
```

- Uses environment modifier `./mise/config.podman.toml` 
- Moves `miserc.toml` → `./.miserc.toml` (sets `MISE_ENV = "podman"`)
- Copied rootless podman config files to `~/.config/containers/` 

#### Batteries Included Defaults (ZFS friendly)

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

#### Mise config

The mise config (`config.podman.toml`) sets up:
- `DOCKER_CMD=podman` - tasks use podman instead of docker
- `docker = "podman"` alias - shell compatibility so `docker` commands work
- `BUILDAH_FORMAT=docker` for healthcheck support

### UID/GUI Mapping

This only matters if you care about the following:

Getting this mapping correct allows files to be accessible to users both in and
out of the container.

It also facilitates backup/snapshot and restore of volumes across different hosts.
Anticipating migration of test agents, via lift and shift of their data volumes
via zfs send.

One additional challenge is a preference to use umask 0002 for 
container processes, so that group membership IS significant for multiple
users with a coder/developer GID.

See what the situation is:
```bash
mise run podman-ids-map
```

This shows how your host UID maps inside containers:
```
UIDS: (Container)(host)   (range)
0         1000      1
```
z
If your UID isn't mapped, you'll get permission errors.

### 3. Run with Podman Compose

```bash
/code/podclaws/prepare-compose.sh --generate
/code/podclaws/prepare-compose.sh --edit
```

## Environment Variables

Set in `mise/podman-resources/mise.podman.toml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_CMD` | `docker` | CLI command (`podman` or `docker`) |
| `PODMAN_COMPOSE_WARNING_LOGS` | `false` | Suppress podman-compose warnings |

## Native Package Installation (Podman specific)

By default, Docker uses `pkg-helper` (a root socket daemon) and isolates Pip/NPM installations into `/app/data/.runtime`. Since we use rootless Podman and commit our environments, this behavior is changed:

1. **System Packages (`apk`)**: The `pkg-helper` daemon is bypassed. When GoClaw needs to install an `apk` package, it utilizes our upstream PR (#1210) to execute `pkg-helper` as a subprocess. Our custom `add-*` scripts use `sudo apk`, natively leveraging the host-mapped user's sudo capabilities.
2. **Pip/NPM**: We do not override `PIP_TARGET` or `NPM_CONFIG_PREFIX`. Packages are installed globally into the container's native `/usr/lib/python...` and `/usr/local/lib/node_modules` instead of the `.runtime` shared volume.
3. **Persistence**: Since packages are installed directly into the container's filesystem, they are persisted by committing the Podman container to an image, rather than relying on volume mounts.

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

