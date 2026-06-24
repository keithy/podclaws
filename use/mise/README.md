# use/mise — upstream mise binary staging

Fetches prebuilt mise binaries from `jdx/mise` GitHub releases and stages them
under the goclaw podman volumes so the `add-mise` shim inside the container
can copy them out to `/bin/mise`.

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
make -C use/mise latest      # update 'latest' symlinks
```

## Targets

- `fetch-musl` / `fetch-glibc` — download `mise-v<VERSION>-linux-arm64{,-musl}.tar.gz`
  from upstream, verify against `SHASUMS256.txt`, extract.
- `stage-musl` / `stage-glibc` — copy the extracted binary to
  `/srv/auto_mise-{musl,glibc}/_data/RELEASES/mise/<VERSION>/aarch64/mise`.
- `latest` — update `latest → <VERSION>` symlinks in both volumes.
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
the `add-mise` shim's hardcoded path.

## Statically linked — no lua lib

mise 2026.6.x is statically linked for both musl and glibc variants
(no shared `liblua.so.5` dependency). Older versions (< 2024) needed
a side-staged lua lib on Alpine; this is no longer required.

## Layout after `make all`

```
/srv/auto_mise-musl/_data/RELEASES/
├── mise/2026.6.13/aarch64/mise        # the musl binary
└── mise/latest → 2026.6.13

/srv/auto_mise-glibc/_data/RELEASES/
├── mise/2026.6.13/aarch64/mise        # the glibc binary
└── mise/latest → 2026.6.13
```

## See also

- `use/self-improve/alpine-installers/add-mise` — Alpine-side shim
- `use/debian/installers/add-mise` — Debian-side shim
- `use/self-improve/mise-installers/add-mise` — mise-overlay shim
- `zfs/+zfs.yml` — bind-mount that exposes `/srv/auto_mise-*` into the
  container at `/usr/share/mise`
