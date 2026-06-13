#!/bin/sh
# Setup host mise installation to use the shared ZFS cache volume
# This prevents the toolchain binaries from being backed up with the home directory.
set -e

MISE_DATA_DIR="${MISE_DATA_DIR:-/srv/mise/installs/glibc}"

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
    PROFILE_D_CONTENT="# mise: route data dir to the shared ZFS cache (not backed up)
# This is system-wide so all users transparently share the same toolchains.
#
# MISE_DATA_DIR: shared compiled toolchains (glibc binaries, downloaded tarballs).
#   System-wide so multiple users on this host share the same heavy data on ZFS.
export MISE_DATA_DIR=\"${MISE_DATA_DIR}\"

# MISE_SHIMS_DIR: tiny per-user shim executables that route to the shared binaries.
#   We MUST explicitly set this to the default per-user location. If unset, mise
#   would default to nesting it inside MISE_DATA_DIR (i.e. /srv/mise/installs/glibc/shims),
#   which would force all users to share the same shims (and thus the same tool versions).
#   By forcing it back to the per-user default, each user gets their own shims and
#   can independently select their tool versions.
export MISE_SHIMS_DIR=\"\${HOME}/.local/share/mise/shims\"
"
        echo "$PROFILE_D_CONTENT" | sudo tee "$PROFILE_D_FILE" >/dev/null
        sudo chmod 0644 "$PROFILE_D_FILE"
        echo "Added MISE_DATA_DIR and MISE_SHIMS_DIR to $PROFILE_D_FILE (system-wide login shells)"
    else
        echo "MISE_DATA_DIR already configured in $PROFILE_D_FILE"
    fi

# Also append to the user's personal .bashrc (and .zshrc if applicable).
# /etc/profile.d/ is ONLY sourced by login shells. To ensure the mise env vars
# are available in interactive non-login shells (like a fresh terminal tab),
# we must also append to the user's shell rc file.
SHELL_RC="${HOME}/.bashrc"
if [ -n "${ZSH_VERSION}" ]; then
    SHELL_RC="${ZDOTDIR:-${HOME}}/.zshrc"
fi

if [ -f "$SHELL_RC" ] && ! grep -q "MISE_DATA_DIR" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" <<EOF

# mise: route data dir to the shared ZFS cache (not backed up)
# (Mirrors /etc/profile.d/mise.sh for non-login interactive shells)
export MISE_DATA_DIR="${MISE_DATA_DIR}"
export MISE_SHIMS_DIR="\${HOME}/.local/share/mise/shims"
EOF
    echo "Added MISE_DATA_DIR and MISE_SHIMS_DIR to $SHELL_RC (interactive shells)"
elif [ ! -f "$SHELL_RC" ]; then
    echo "Note: $SHELL_RC does not exist. Skipping per-user shell rc."
fi
else
    echo "WARNING: Cannot write to $PROFILE_D_FILE. Run as root or install sudo."
    exit 1
fi
