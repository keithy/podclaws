#!/bin/sh
# Setup host mise installation to use the shared ZFS cache volume
# This prevents the toolchain binaries from being backed up with the home directory.
set -e

# Don't inherit MISE_DATA_DIR or MISE_CACHE_DIR from the calling shell - the
# script's defaults are the source of truth and match the ZFS layout.
unset MISE_DATA_DIR
unset MISE_CACHE_DIR
MISE_DATA_DIR="${MISE_DATA_DIR:-/srv/auto_mise-glibc/_data}"
MISE_CACHE_DIR="${MISE_CACHE_DIR:-/srv/auto_mise-cache/_data}"

# Ensure mise is installed. We check for the system binary first (e.g. /usr/bin/mise
# from APT), and fall back to the local shim (e.g. ~/.local/bin/mise from the
# standalone curl installer). If neither exists, we install the standalone version.
MISE_BIN=""
if command -v mise >/dev/null 2>&1; then
    MISE_BIN="$(command -v mise)"
    echo "Found mise at $MISE_BIN (system PATH)"
elif [ -x "${HOME}/.local/bin/mise" ]; then
    MISE_BIN="${HOME}/.local/bin/mise"
    echo "Found mise at $MISE_BIN (local install)"
else
    echo "mise not found. Installing via standalone installer..."
    curl https://mise.run | sh
    MISE_BIN="${HOME}/.local/bin/mise"
fi
echo "Using mise: $MISE_BIN"

# Add MISE_DATA_DIR to /etc/profile.d so EVERY user on the host automatically
# gets the shared ZFS-backed mise cache, without needing to edit personal dotfiles.
# This is the standard FHS-compliant way to set system-wide environment variables.
# Note: We deliberately do NOT override MISE_SHIMS_DIR. The default per-user
# location (~/.local/share/mise/shims) is the correct, well-tested location,
# and it respects each user's ability to select their own tool versions.
PROFILE_D_FILE="/etc/profile.d/mise.sh"

if [ -w "$(dirname "$PROFILE_D_FILE")" ] || command -v sudo >/dev/null 2>&1; then
    if ! grep -q "MISE_DATA_DIR" "$PROFILE_D_FILE" 2>/dev/null; then
    PROFILE_D_CONTENT="# mise: route data and cache to dedicated ZFS volumes (not backed up)
# The data dir is shared across all consumers with the same libc+arch (host users
# and containers of that family), but NOT across different libcs or architectures
# (compiled toolchains are not portable).
# The cache is shared across everything (downloads, version metadata - safe).
#
# MISE_DATA_DIR: compiled toolchains (glibc binaries, downloaded tarballs).
#   Shared across the glibc family: host users + glibc-based containers.
#   Alpine (musl) containers must use a separate MISE_DATA_DIR (the 'mise-musl' volume).
#   Backed by ZFS dataset mounted at the podman volume path, so the same data is
#   shared with glibc-based containers (cluster-friendly: no bind mounts).
export MISE_DATA_DIR=\"${MISE_DATA_DIR}\"

# MISE_CACHE_DIR: shared downloads cache (tarballs, wheels, version metadata).
#   Safe to share across all architectures and libcs (per upstream mise docs).
#   Shared with containers via the podman volume 'mise-cache'.
export MISE_CACHE_DIR=\"${MISE_CACHE_DIR}\"

# MISE_SHIMS_DIR: tiny per-user shim executables that route to the shared binaries.
#   We MUST explicitly set this to the default per-user location. If unset, mise
#   would default to nesting it inside MISE_DATA_DIR, which would force all users
#   to share the same shims (and thus the same tool versions).
#   By forcing it back to the per-user default, each user gets their own shims and
#   can independently select their tool versions.
export MISE_SHIMS_DIR=\"\${HOME}/.local/share/mise/shims\"
"
        echo "$PROFILE_D_CONTENT" | sudo tee "$PROFILE_D_FILE" >/dev/null
        sudo chmod 0644 "$PROFILE_D_FILE"
        echo "Added MISE_DATA_DIR and MISE_SHIMS_DIR to $PROFILE_D_FILE (system-wide login shells)"
    else
        # File already exists; do NOT modify it. The user is responsible for
        # keeping MISE_DATA_DIR in sync with the ZFS layout.
        echo "$PROFILE_D_FILE already exists (not modifying)"
        if grep -q "^export MISE_DATA_DIR=" "$PROFILE_D_FILE" 2>/dev/null; then
            current=$(grep "^export MISE_DATA_DIR=" "$PROFILE_D_FILE" | head -1 | sed -E 's/^export MISE_DATA_DIR="?([^"]*)"?$/\1/')
            echo "  current MISE_DATA_DIR=$current"
            if [ "$current" != "${MISE_DATA_DIR}" ]; then
                echo "  expected MISE_DATA_DIR=${MISE_DATA_DIR} -- MISMATCH"
            fi
        fi
    fi

# /etc/profile.d/ is ONLY sourced by login shells. To ensure the mise env vars
# are available in interactive non-login shells, the user is responsible for
# adding the MISE_DATA_DIR export to their shell rc file (e.g. ~/.bashrc).
# We intentionally do NOT auto-modify shell rc files.
else
    echo "WARNING: Cannot write to $PROFILE_D_FILE. Run as root or install sudo."
    exit 1
fi
