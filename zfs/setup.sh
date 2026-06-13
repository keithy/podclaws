#!/bin/sh
# Setup ZFS volumes for goclaw
set -e

project="$COMPOSE_PROJECT_NAME"
POOL="${ZFS_POOL:-rock-pool}"
# 'safe' = backed up, persisted agent state
# 'cache' = ephemeral/auto-generated, not backed up (shared toolchains live here)
DATASET="${POOL}/safe/goclaw"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

echo "Creating ZFS datasets for podclaws..."

# Create datasets with host paths matching container expectations
# Container expects: /app/data, /app/workspace, /app/skills
# Host mounts to: /srv/${project}_goclaw-data, /srv/${project}_goclaw-workspace, /srv/${project}_goclaw-skills
zfs create -o mountpoint=/srv/${project}_goclaw-data      "${DATASET}/data"      2>/dev/null || echo "data exists"
zfs create -o mountpoint=/srv/${project}_goclaw-workspace "${DATASET}/work"      2>/dev/null || echo "work exists"
zfs create -o mountpoint=/srv/${project}_goclaw-skills    "${DATASET}/skills"    2>/dev/null || echo "skills exists"
zfs create -o mountpoint=/srv/${project}_postgres-data    "${DATASET}/postgres"  2>/dev/null || echo "postgres exists"

# Create the shared mise-cache volume outside the 'safe' boundary.
# It lives in 'cache' (ephemeral, not backed up) and intentionally uses a hardcoded
# path (not project-prefixed) so all containers/agents share the exact same toolchain
# cache (e.g. main goclaw container, sandboxes, etc).
#
# 'installs/musl' explicitly namespaces the architecture/libc-specific binaries
# (Alpine containers). In the future, an 'installs/glibc' could be added for
# Ubuntu-slim containers without naming conflicts.
# The 'cache' subdirectory is architecture-independent (tarballs/wheels), so it
# can be safely shared across all container types.
zfs create -o mountpoint=/srv/mise/installs/musl       "${POOL}/cache/mise/installs/musl"  2>/dev/null || echo "installs/musl exists"
zfs create -o mountpoint=/srv/mise/cache              "${POOL}/cache/mise/cache"         2>/dev/null || echo "mise cache exists"

# Pre-create _data subdirs with correct ownership so podman doesn't create as root
mkdir -p /srv/${project}_goclaw-data/_data
mkdir -p /srv/${project}_goclaw-workspace/_data
mkdir -p /srv/${project}_goclaw-skills/_data
mkdir -p /srv/${project}_postgres-data/_data
mkdir -p /srv/mise/installs/musl/_data
mkdir -p /srv/mise/cache/_data

chown -R "${HOST_UID}:${HOST_GID}" /srv/${project}_goclaw-data /srv/${project}_goclaw-workspace /srv/${project}_goclaw-skills /srv/${project}_postgres-data /srv/mise

# Surgical permission fix: enforce the setgid bit (g+s) on all directories
# to guarantee that newly created files inherit the 'coder' group.
# We deliberately target only directories (-type d) so we DO NOT clobber
# restrictive file modes (e.g. 0600 keys, 0700 dirs) that users may have set.
ensure_setgid() {
    target_dir="$1"
    if [ -d "$target_dir" ]; then
        find "$target_dir" -type d -exec chmod g+s {} +
    fi
}

# Apply setgid to the shared cache (group-writable)
ensure_setgid /srv/mise
ensure_setgid /srv/mise/installs
ensure_setgid /srv/mise/cache

# Apply setgid to the project data (group-readable, writable by owner)
ensure_setgid /srv/${project}_goclaw-data
ensure_setgid /srv/${project}_goclaw-workspace
ensure_setgid /srv/${project}_goclaw-skills
ensure_setgid /srv/${project}_postgres-data

echo "Done. Datasets:"
zfs list -r "${DATASET}" 2>/dev/null
zfs list -r "${POOL}/cache/mise" 2>/dev/null

echo ""
echo "Pre-created _data dirs with ownership ${HOST_UID}:${HOST_GID}"
echo "Podman will use existing dirs instead of creating as root"
