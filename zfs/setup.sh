#!/bin/sh
# Setup ZFS volumes for goclaw
# Requires sudo for ZFS dataset creation (datasets are typically not delegated
# to unprivileged users). The script will prompt for sudo as needed.
set -e

project="$COMPOSE_PROJECT_NAME"
POOL="${ZFS_POOL:-rock-pool}"
# 'safe' = backed up, persisted agent state
# 'cache' = ephemeral/auto-generated, not backed up (shared toolchains live here)
DATASET="${POOL}/safe/goclaw"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Helper: create a ZFS dataset with sudo (suppresses noise on already-existing)
zfs_create() {
    sudo zfs create "$@" 2>/dev/null || true
}

# Helper: chown a ZFS dataset's mountpoint to the host user.
# Because 'sudo zfs create' creates datasets owned by root, we must explicitly
# chown the mountpoint back to the host user (e.g. auto:coder) so the
# host user can write into it without sudo.
chown_mountpoint() {
    local mountpoint="$1"
    if [ -d "$mountpoint" ]; then
        sudo chown "${HOST_UID}:${HOST_GID}" "$mountpoint"
    fi
}

echo "Creating ZFS datasets for podclaws..."

# Create datasets with host paths matching container expectations.
#
# CRITICAL: ALL ZFS mountpoints MUST be on the /_data subdir, NOT the parent.
# Podman stores internal volume metadata (e.g. opts.json) in the parent
# directory. If we mounted ZFS over the parent, the ZFS mount would MASK
# (hide) podman's metadata, causing storage corruption and failed deployments.
# The _data subdir is the safe mount target.
#
# Layout convention (used for ALL project volumes):
#   /srv/${project}_<name>/         (parent, plain dir, podman metadata)
#   /srv/${project}_<name>/_data/   (ZFS mountpoint, container data)
#
# Container paths: /app/data, /app/workspace, /app/skills, /var/lib/postgresql/data
# Host paths:       /srv/${project}_goclaw-data/_data, etc.
zfs_create -o mountpoint=/srv/${project}_goclaw-data/_data      "${DATASET}/data"
zfs_create -o mountpoint=/srv/${project}_goclaw-workspace/_data "${DATASET}/work"
zfs_create -o mountpoint=/srv/${project}_goclaw-skills/_data    "${DATASET}/skills"
zfs_create -o mountpoint=/srv/${project}_postgres-data/_data    "${DATASET}/postgres"

# Create the shared mise-cache volume outside the 'safe' boundary.
# It lives in 'cache' (ephemeral, not backed up).
# Same _data subdir convention as above.
zfs_create -p -o mountpoint=/srv/${project}_mise-cache/_data     "${POOL}/cache/mise/cache"
zfs_create -p -o mountpoint=/srv/${project}_mise-installs/_data "${POOL}/cache/mise/installs"

# Fix ownership of all newly created mountpoints (sudo zfs create makes them root-owned)
chown_mountpoint /srv/${project}_goclaw-data/_data
chown_mountpoint /srv/${project}_goclaw-workspace/_data
chown_mountpoint /srv/${project}_goclaw-skills/_data
chown_mountpoint /srv/${project}_postgres-data/_data
chown_mountpoint /srv/${project}_mise-cache/_data
chown_mountpoint /srv/${project}_mise-installs/_data

# Pre-create the parent _data subdirs (parent dirs already exist as regular dirs)
# so podman doesn't need to create them as root.
# The _data subdirs are the actual targets where container data lives.
mkdir -p /srv/${project}_goclaw-data
mkdir -p /srv/${project}_goclaw-workspace
mkdir -p /srv/${project}_goclaw-skills
mkdir -p /srv/${project}_postgres-data
mkdir -p /srv/${project}_mise-cache
mkdir -p /srv/${project}_mise-installs
# The ZFS mounts create _data subdirs automatically; just chown them.
# (zfs_create already mounted the datasets, so the _data dirs exist.)

chown -R "${HOST_UID}:${HOST_GID}" \
    /srv/${project}_goclaw-data \
    /srv/${project}_goclaw-workspace \
    /srv/${project}_goclaw-skills \
    /srv/${project}_postgres-data \
    /srv/${project}_mise-cache \
    /srv/${project}_mise-installs

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
ensure_setgid /srv/${project}_mise-cache
ensure_setgid /srv/${project}_mise-installs

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
