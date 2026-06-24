# use/mise — upstream mise binary staging (host-side)

Pre-fetches the upstream mise prebuilt binaries and stages them to the
`/srv/auto_mise-{musl,glibc}/_data/RELEASES/mise/<v>/aarch64/mise` paths
on the host. The goclaw container's `add-mise` shim reads from those paths
via the `mise-musl` / `mise-glibc` named volumes bind-mounted at
`/usr/share/mise`.

**The shim is self-bootstrapping** — it can also fetch and install mise
itself on first use if the volume is empty. This Makefile is the
host-side shortcut: pre-stage once on the host, no per-container network.

## When to use

- **Production / multi-host**: run `make` on each host. One download,
  many containers, no network in containers.
- **Dev / single-host**: skip `make`. The shim will fetch on first
  use. Subsequent runs are fast (cached on the container's writable
  layer at `/usr/share/mise/bin/mise` or `/usr/local/bin/mise`).

## Quick start

```sh
# 1. Set the version in versions.env
$EDITOR versions.env     # e.g. MISE_VERSION=2026.6.13

# 2. Fetch + verify + stage + link everything
make -C use/mise all

# Or step by step:
make -C use/mise fetch-musl
make -C use/mise fetch-glibc
make -C use/mise stage-musl
make -C use/mise stage-glibc
make -C use/mise latest      # update 'latest' symlinks and bin/mise pointer
```

## Targets

- `fetch-musl` / `fetch-glibc` — download `mise-v<VERSION>-linux-arm64{,-musl}.tar.gz`
  from upstream, verify against `SHASUMS256.txt`, extract.
- `stage-musl` / `stage-glibc` — copy the extracted binary to
  `/srv/auto_mise-{musl,glibc}/_data/RELEASES/mise/<VERSION>/aarch64/mise`.
- `latest` — update two symlinks per volume:
  - `RELEASES/mise/latest → <VERSION>` (so anything that walks the
    versioned directory tree picks up the new version)
  - `bin/mise → ../RELEASES/mise/latest/aarch64/mise` (so
    `/usr/share/mise/bin/mise` is a real binary on PATH; the
    `add-mise` shim is a one-line `exec` passthrough)
- `all` — runs the four above.
- `clean` — remove `build/` artifacts.

## Why two builds (musl + glibc)?

The goclaw container's base image is either Alpine (musl) or Debian/RHEL
(glibc). mise is published as both; we use the matching one rather than
a cross-compile or static-binary workaround.

Both the musl and glibc tarballs come from the same upstream release,
just with different filenames:

| Variant | URL |
| ------- | --- |
| musl    | `https://github.com/jdx/mise/releases/download/v<VERSION>/mise-v<VERSION>-linux-arm64-musl.tar.gz` |
| glibc   | `https://github.com/jdx/mise/releases/download/v<VERSION>/mise-v<VERSION>-linux-arm64.tar.gz` |

The tarball extracts to `mise/bin/mise` in both cases. Upstream uses
`arm64` in the URL; we use `aarch64` in the staging path to match the
existing `/srv/auto_mise-*/_data/RELEASES/mise/.../aarch64/` layout and
the `add-mise` shim's path.

## Statically linked — no lua lib

mise 2026.6.x is statically linked for both musl and glibc variants
(no shared `liblua.so.5` dependency). Older versions (< 2024) needed
a side-staged lua lib on Alpine; this is no longer required.

## Layout after `make all`

```
/srv/auto_mise-musl/_data/
├── bin/mise → ../RELEASES/mise/latest/aarch64/mise    # the binary on PATH
└── RELEASES/
    └── mise/
        ├── 2026.6.13/aarch64/mise
        ├── 2025.8.20/aarch64/mise
        └── latest → 2026.6.13

/srv/auto_mise-glibc/_data/
├── bin/mise → ../RELEASES/mise/latest/aarch64/mise
└── RELEASES/
    └── mise/
        ├── 2026.6.13/aarch64/mise
        ├── 2025.8.20/aarch64/mise
        └── latest → 2026.6.13
```

Inside the goclaw container (with `+mise-improve.yml` mounted), these become
`/usr/share/mise/bin/mise` and `/usr/share/mise/RELEASES/mise/<VERSION>/aarch64/mise`.
The `add-mise` shim is a one-line `exec` of the former (or a bootstrap
that re-fetches if the bind-mount is empty).

## See also

- `use/self-improve/alpine-installers/add-mise` — Alpine-side shim
- `use/debian/installers/add-mise` — Debian-side shim
- `use/self-improve/mise-installers/add-mise` — mise-overlay shim
- `zfs/+zfs.yml` — bind-mount that exposes `/srv/auto_mise-*` into the
  container at `/usr/share/mise`

