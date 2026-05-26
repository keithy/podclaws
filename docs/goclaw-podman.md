# Using Podman with GoClaw

GoClaw supports Docker Compose. Podclaws runs GoClaw under Rootless Podman.

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

### 1. Enable Podman Environment

```bash
mise run podman-enable
```

This:
- Moves `mise.podman.toml` → `./mise.podman.toml` (activates podman env)
- Moves `miserc.toml` → `./.miserc.toml` (sets `MISE_ENV = "podman"`)
- Creates symlinks in `~/.config/containers/` for podman config files (batteries included defaults)

#### Batteries Included Defaults (ZFS friendly)

Podman volume_path = `/srv` (why not?)

Assuming that a ZFS user will have separately mapped `/home/<user>`  directories into
a ZFS volume by default, placing our data volumes at `/srv/` simplifies the task
of mapping them individually to their own ZFS volumes. The goal being to map the
entirity of goclaw data into a single heirarchy of volumes, so that a backup 
volume snapshot becomes a single atomic operation.

In contrast placing podman storage at `/opt/storage` is intended to have the opposite
effect. Moving it out of `/home` simplifies choosing which filesystem options to use
underneath docker/podman's overlayfs filesystem. /opt is likly to be the same filesystem
as / (i.e. f2fs, ext4, or xfs)

#### Mise config

The mise config (`mise.podman.toml`) sets up:
- `DOCKER_CMD=podman` - makes tasks use podman instead of docker
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
podman compose -f docker-compose.yml -f docker-compose.postgres.yml up
```

## Environment Variables

Set in `mise/podman-resources/mise.podman.toml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_CMD` | `docker` | CLI command (`podman` or `docker`) |
| `PODMAN_COMPOSE_WARNING_LOGS` | `false` | Suppress podman-compose warnings |

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

### Socket permission denied

Check socket exists and permissions:
```bash
ls -la /run/user/$UID/podman/podman.sock
```
