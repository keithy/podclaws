# goclaw-debian — Debian bookworm-slim variant of the goclaw skeleton
#
> **STATUS: DEMO / UNTESTED.** This variant has not been built or run end-to-end. The Dockerfile, compose fragments, and Makefile are placeholders that mirror the Alpine variant. Build at your own risk.

The primary podclaws deployment uses the Alpine-based image in `../goclaw/` (slim, ~30 MB, fast cold start). This directory holds a Debian bookworm-slim variant for users who need a glibc base (e.g. some Python wheels, some node-gyp modules).

## Build

```bash
cd use_debian/goclaw
make image                # builds localhost/goclaw-debian:current
```

Or directly:

```bash
podman build -t localhost/goclaw-debian:current .
```

## Run

```bash
# Switch COMPOSE_FILE in .env to use this variant instead of the Alpine one
# (the service name is 'goclaw' in both, so only one is active at a time).
podman compose up -d
```

## Layout

```
use_debian/goclaw/
├── Dockerfile              (debian:bookworm-slim base, apt-install ca-certs + sudo + curl)
├── Makefile                (binary build + image build, mirrors ../goclaw/Makefile)
├── README.md               (this file)
├── ROOT/                   (copy of ../goclaw/ROOT — entrypoint, sudoers, etc.)
├── +self-improve.yml       (self-improve overlay, mounts use_debian/self-improve/)
└── service.goclaw.yml      (compose service def)
```

## Notes

- **Service name `goclaw` matches the Alpine variant.** Only one should be active at a time — swap via `services:select` in `.env`.
- **Same `RELEASES/goclaw/` path** — the goclaw binary is distro-agnostic, so both variants share the same built binary.
- **No bash, no git baked in** — opt in via the lazy shims (`add-bash`, `add-git`).
- **CA bundle bind-mount** — same as the Alpine variant: `PODCLAWS_CA_BUNDLE` defaults to `/etc/ssl/certs/ca-certificates.crt`.
- **Sandbox** (future work): `service.sandbox.yml` stub references `goclaw-sandbox:bookworm-slim` per the upstream convention.

## What hasn't been tested

- The Dockerfile has not been built. The `apt-get install` commands and `ROOT/` contents may need adjustments for Debian's package set, paths, and conventions.
- The compose fragments assume the same volume names, networks, and env vars as the Alpine variant — should work but unverified.
- The `+self-improve` overlay's `/usr/local/sbin` bind-mount assumes the lazy shims work in Debian's slightly different PATH layout — unverified.
- The `use_debian/self-improve/` overlay is currently a stub with no scripts; the Alpine overlay cannot be reused as-is.
