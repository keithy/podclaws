#!/bin/sh
# Setup ZFS volumes for goclaw
set -e

POOL="${ZFS_POOL:-rock-pool}"
DATASET="${POOL}/safe/goclaw"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

echo "Creating ZFS datasets for podclaws..."

# Create datasets with host paths matching container expectations
# Container expects: /app/data, /app/workspace, /app/skills
# Host mounts to: /srv/auto_goclaw-data, /srv/auto_goclaw-workspace, /srv/auto_goclaw-skills
zfs create -o mountpoint=/srv/auto_goclaw-data      "${DATASET}/data"      2>/dev/null || echo "data exists"
zfs create -o mountpoint=/srv/auto_goclaw-workspace "${DATASET}/work"      2>/dev/null || echo "work exists"
zfs create -o mountpoint=/srv/auto_goclaw-skills    "${DATASET}/skills"    2>/dev/null || echo "skills exists"
zfs create -o mountpoint=/srv/auto_postgres-data    "${DATASET}/postgres"  2>/dev/null || echo "postgres exists"

# Pre-create _data subdirs with correct ownership so podman doesn't create as root
mkdir -p /srv/auto_goclaw-data/_data
mkdir -p /srv/auto_goclaw-workspace/_data
mkdir -p /srv/auto_goclaw-skills/_data
mkdir -p /srv/auto_postgres-data/_data

chown -R "${HOST_UID}:${HOST_GID}" /srv/auto_goclaw-data /srv/auto_goclaw-workspace /srv/auto_goclaw-skills /srv/auto_postgres-data

echo "Done. Datasets:"
zfs list -r "${DATASET}" 2>/dev/null

echo ""
echo "Pre-created _data dirs with ownership ${HOST_UID}:${HOST_GID}"
echo "Podman will use existing dirs instead of creating as root"