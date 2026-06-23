# use_debian/self-improve/ — Debian-based self-improve overlay (stub)
#
> **STATUS: STUB.** This directory mirrors the structure of `../use/self-improve/` but no scripts are implemented yet. Debian variants of the add-* scripts and shims are future work.

The primary podclaws deployment mounts the Alpine-based self-improve overlay from `../use/self-improve/`. That overlay's scripts use `sudo apk add` and assume Alpine paths, busybox quirks, etc.

For the Debian variant (`../use_debian/goclaw/`), the shim layer needs different scripts that use `sudo apt-get install` and Debian conventions. This directory is the placeholder for that work.

## Planned structure (matches `../use/self-improve/`)

```
use_debian/self-improve/
├── README.md               (this file)
├── sbin/                   (lazy shims + add-* scripts, apt-based)
│   ├── python, python3, pip, pip3, pipx
│   ├── node, npm
│   ├── go, gh, pg_dump, mise
│   ├── add-python, add-node, add-go, add-gh, add-pg-dump, add-bash, add-git, add-mise, ...
│   └── lib/shim-common.sh
├── skills/self-improve/    (the self-improve skill bundle, Debian-flavored)
└── tests/                  (spec scripts for the whitelisted commands)
    └── lib/bash-spec.sh
```

## Key differences from the Alpine overlay

- `add-*` scripts use `sudo apt-get install -y <package>` instead of `sudo apk add --no-cache <package>`.
- `apk policy` for `--version` becomes `apt-cache policy` (different output format).
- `mktemp -d -t prefix.XXXXXX` (BusyBox) vs `mktemp -d` (GNU coreutils) — minor.
- Python version on Debian bookworm is older than Alpine's — may need backports or use mise.
- The `psql` sniffing in `add-pg-client` works on both.
- `add-oils` builds from source — same on both.
- `add-mise` curl workflow is the same.

## What to do next

When you're ready to flesh this out:
1. Copy `../use/self-improve/sbin/*` to `use_debian/self-improve/sbin/`.
2. For each `add-*`, replace the `apk add` line with `apt-get install -y`.
3. For the `--version` mode, replace `apk policy` with `apt-cache policy` and adjust the awk/sed parsing.
4. Test in the Debian bookworm-slim goclaw container.
