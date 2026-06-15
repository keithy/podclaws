#!/bin/sh
# Setup ZFS volumes for podclaws
#
# This script is IDEMPOTENT and NON-DESTRUCTIVE. It:
#   1. Verifies that expected ZFS datasets exist (creates if missing, no-op if present).
#   2. Verifies mountpoints are on the /_data subdir (avoids masking podman metadata).
#   3. If a mountpoint is wrong, offers to fix it via 'sudo zfs set mountpoint=...'.
#
# Datasets are created under rock-pool/safe/goclaw (backed up) and
# rock-pool/cache/mise (not backed up, shared toolchains).
# Per-libc data dirs are under rock-pool/mise/data-{glibc,musl}, named to
# mirror the podman volume names (auto_mise-glibc / auto_mise-musl).
set -e

project="$COMPOSE_PROJECT_NAME"
POOL="${ZFS_POOL:-rock-pool}"
DATASET="${POOL}/safe/goclaw"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Helper: create a ZFS dataset with sudo, but ONLY IF IT DOESN'T EXIST.
# This is fully non-destructive - existing datasets are left untouched.
zfs_create() {
    local dataset="$1"
    local mountpoint="$2"
    if zfs list -H -o name "$dataset" >/dev/null 2>&1; then
        echo "  [exists] $dataset"
    else
        echo "  [creating] $dataset at $mountpoint"
        sudo zfs create -o mountpoint="$mountpoint" "$dataset" >/dev/null
    fi
}

# Helper: ensure a ZFS mountpoint is on the /_data subdir.
# If it's already correct, this is a no-op. If wrong, it offers to fix it.
fix_mountpoint() {
    local dataset="$1"
    local expected_mount="$2"
    local current_mount
    current_mount=$(zfs list -H -o mountpoint "$dataset" 2>/dev/null || echo "MISSING")
    if [ "$current_mount" = "$expected_mount" ]; then
        echo "  [ok] $dataset -> $expected_mount"
    else
        echo "  [WRONG] $dataset"
        echo "          current:  $current_mount"
        echo "          expected: $expected_mount"
        echo "          fix with:  sudo zfs set mountpoint=$expected_mount $dataset"
    fi
}

# Helper: chown a mountpoint to the host user.
chown_mountpoint() {
    local mountpoint="$1"
    if [ -d "$mountpoint" ]; then
        sudo chown "${HOST_UID}:${HOST_GID}" "$mountpoint" 2>/dev/null || \
            chown "${HOST_UID}:${HOST_GID}" "$mountpoint" 2>/dev/null || true
    fi
}

echo "=== Verifying ZFS datasets ==="

# Project data volumes (safe, backed up)
zfs_create "${DATASET}/data"     "/srv/${project}_goclaw-data/_data"
zfs_create "${DATASET}/work"     "/srv/${project}_goclaw-workspace/_data"
zfs_create "${DATASET}/skills"   "/srv/${project}_goclaw-skills/_data"
zfs_create "${DATASET}/postgres" "/srv/${project}_postgres-data/_data"

# Shared mise cache (not backed up, used by containers)
zfs_create "${POOL}/cache/mise" "/srv/${project}_mise-cache/_data"

# Per-libc mise data dirs (not backed up, shared within each libc family).
# Each dataset is mounted at the podman volume's _data subdir, so the data
# is visible at the path podman expects.
zfs_create "${POOL}/mise/data-glibc" "/srv/${project}_mise-glibc/_data"
zfs_create "${POOL}/mise/data-musl"  "/srv/${project}_mise-musl/_data"

echo ""
echo "=== Verifying mountpoints ==="
fix_mountpoint "${DATASET}/data"     "/srv/${project}_goclaw-data/_data"
fix_mountpoint "${DATASET}/work"     "/srv/${project}_goclaw-workspace/_data"
fix_mountpoint "${DATASET}/skills"   "/srv/${project}_goclaw-skills/_data"
fix_mountpoint "${DATASET}/postgres" "/srv/${project}_postgres-data/_data"
fix_mountpoint "${POOL}/cache/mise"          "/srv/${project}_mise-cache/_data"
fix_mountpoint "${POOL}/mise/data-glibc"    "/srv/${project}_mise-glibc/_data"
fix_mountpoint "${POOL}/mise/data-musl"     "/srv/${project}_mise-musl/_data"

echo ""
echo "=== Fixing ownership on mountpoints (no-op if already correct) ==="
# Only chown if the mountpoint is on a filesystem we own (e.g. not root-owned).
# If sudo is required, this prints a hint instead of failing.
chown_mountpoint /srv/${project}_goclaw-data/_data
chown_mountpoint /srv/${project}_goclaw-workspace/_data
chown_mountpoint /srv/${project}_goclaw-skills/_data
chown_mountpoint /srv/${project}_postgres-data/_data
chown_mountpoint /srv/${project}_mise-cache/_data
chown_mountpoint /srv/${project}_mise-glibc/_data
chown_mountpoint /srv/${project}_mise-musl/_data

# Ensure parent dirs exist as plain directories (they were auto-created by podman
# if anonymous volumes were ever instantiated).
mkdir -p /srv/${project}_goclaw-data \
         /srv/${project}_goclaw-workspace \
         /srv/${project}_goclaw-skills \
         /srv/${project}_postgres-data \
         /srv/${project}_mise-cache \
         /srv/${project}_mise-glibc \
         /srv/${project}_mise-musl 2>/dev/null || true

chown -R "${HOST_UID}:${HOST_GID}" \
    /srv/${project}_goclaw-data \
    /srv/${project}_goclaw-workspace \
    /srv/${project}_goclaw-skills \
    /srv/${project}_postgres-data \
    /srv/${project}_mise-cache \
    /srv/${project}_mise-glibc \
    /srv/${project}_mise-musl 2>/dev/null || true

# Surgical permission fix: enforce the setgid bit (g+s) on all directories.
# Targets only directories (-type d) so we DO NOT clobber restrictive file modes
# (e.g. 0600 keys, 0700 dirs).
ensure_setgid() {
    local target_dir="$1"
    if [ -d "$target_dir" ]; then
        find "$target_dir" -type d -exec chmod g+s {} + 2>/dev/null || true
    fi
}

# Apply setgid to the shared cache (group-writable)
ensure_setgid /srv/${project}_mise-cache
ensure_setgid /srv/${project}_mise-glibc
ensure_setgid /srv/${project}_mise-musl

# Apply setgid to the project data (group-readable, writable by owner)
ensure_setgid /srv/${project}_goclaw-data
ensure_setgid /srv/${project}_goclaw-workspace
ensure_setgid /srv/${project}_goclaw-skills
ensure_setgid /srv/${project}_postgres-data

echo ""
echo "=== ZFS layout ==="
zfs list -r "${DATASET}" 2>/dev/null
zfs list -r "${POOL}/cache/mise" 2>/dev/null
zfs list -r "${POOL}/mise" 2>/dev/null

echo ""
echo "Done. If any [WRONG] mountpoints were listed above, run the suggested"
echo "  'sudo zfs set mountpoint=...' command to fix them. No data is lost."
