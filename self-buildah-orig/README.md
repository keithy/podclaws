# Self-Building Container (Buildah)

A container that builds its own layers. No CI/CD pipeline needed for adding modules.

See [SELF_BUILDING.md](./SELF_BUILDING.md) for full documentation.

## Quick Start

```bash
cd options/buildah
make build-binary/ctr       # build goclaw binary in alpine container
make build                 # build runtime image
podman run --rm ghcr.io/nextlevelbuilder/goclaw:latest version
```

## Workflow

Binary build in alpine (cross-compile):
```
make build-binary/ctr      # build binary in alpine container
make ctr-binary ctr-commit  # push binary to runtime image
```

Binary build on local host:
```
make build-binary          # build on local host
make ctr-binary ctr-commit-blue  # push, keep container
```

Binary-only update (no layer rebuild):
```
make ctr-binary ctr-commit-next  # update binary, increment version
```

## Structure

```
buildah/
├── Makefile           # build system (buildah + build binary orchestration)
├── entrypoint.sh      # shell entrypoint
├── entrypoint.execline # execline entrypoint (optional)
└── SELF_BUILDING.md   # approach comparison
```

## Buildah vs Podman

| Concern | Tool |
|---------|------|
| Build image layers | **buildah** (no daemon, builds inside containers) |
| Run/test image | **podman** |

The Makefile IS the build definition — not a Dockerfile.

## See Also

- [SELF_BUILDING.md](./SELF_BUILDING.md) — approach comparison
- [Podman setup](../podman/) — runtime configuration