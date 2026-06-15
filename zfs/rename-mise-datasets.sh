#!/bin/sh
# Rename ZFS datasets to flatten the mise volume layout.
#
# Current:
#   rock-pool/mise/installs/glibc   -> /srv/auto_mise-glibc/_data
#   rock-pool/mise/installs/musl    -> /srv/auto_mise-musl/_data
#   rock-pool/mise/installs         (parent, empty after rename)
#   rock-pool/mise                  (parent, default mount at /rock-pool/mise)
#
# Target:
#   rock-pool/mise/data-glibc       -> /srv/auto_mise-glibc/_data
#   rock-pool/mise/data-musl        -> /srv/auto_mise-musl/_data
#   rock-pool/mise                  (parent, mountpoint=none)
#
# Mountpoints are preserved on the renamed datasets, so no other paths change.
# After this script, run /code/podclaws/zfs/setup.sh to verify the new layout.
set -e

echo "=== Current ZFS layout (before) ==="
zfs list -r rock-pool/mise 2>/dev/null

echo ""
echo "=== Renaming children ==="
# Use -u to skip the unmount/remount step. The mountpoint path is preserved,
# so the existing mount continues to serve the dataset under its new name.
# This avoids the "pool or dataset is busy" error when files (e.g. the running
# Crush binary) are open on the dataset.
sudo zfs rename -u rock-pool/mise/installs/glibc rock-pool/mise/data-glibc
sudo zfs rename -u rock-pool/mise/installs/musl  rock-pool/mise/data-musl

echo ""
echo "=== Removing the now-empty installs/ parent ==="
sudo zfs destroy rock-pool/mise/installs

echo ""
echo "=== Unsetting the leftover /rock-pool/mise mountpoint ==="
sudo zfs set mountpoint=none rock-pool/mise

echo ""
echo "=== Result ==="
zfs list -r rock-pool/mise 2>/dev/null
zfs list -r rock-pool/cache/mise 2>/dev/null

echo ""
echo "=== Active mounts ==="
cat /proc/mounts | grep -E "auto_mise|rock-pool/mise" 2>/dev/null

echo ""
echo "=== Verify volume contents are intact ==="
echo "glibc toolchains: $(ls /srv/auto_mise-glibc/_data/installs/ 2>/dev/null | wc -l) entries"
echo "musl toolchains:  $(ls /srv/auto_mise-musl/_data/installs/ 2>/dev/null | wc -l) entries"
echo "cache contents:   $(ls /srv/auto_mise-cache/_data/ 2>/dev/null | wc -l) entries"

echo ""
echo "Done. Mountpoints unchanged; only ZFS dataset names moved."
