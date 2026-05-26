# Self-Building Container: Approach Comparison

Three approaches to adding modules at runtime.

## Approach 1: Full rebuild based upon Dockerfile

**Pros:**
- Proven, standard approach
- Isolated build environment

**Cons:**
- Dockerfile is an anti-pattern
- Slow: minutes to hours
- Static not dynamic
- Full rebuild even for single module add

## Approach 2: Package Helper

Container runs a privileged helper process that installs packages at runtime.

```
Entrypoint starts pkg-helper (root, listens on /tmp/pkg.sock)
       ↓
Agent sends package request to socket
       ↓
pkg-helper runs: apk add --no-cache NEW_PACKAGE
       ↓
pkg-helper persists package list to /app/data/.runtime/apk-packages
       ↓
On container restart: entrypoint re-installs from apk-packages
```

**Pros:**
- Fast: instant package install
- No image rebuild
- Persists across restarts

**Cons:**
- Privileged helper (security surface)
- Only handles apk packages (no pip/npm self-contained)
- pkg-helper process to maintain
- Container still depends on external image for base changes

## Approach 3: Self-Building Container (This Project)

Container contains buildah and builds its own layers.

```
Agent requests module (examples are in the MakeFile)
       ↓
make ctr-NEWMODULE          # buildah run -- apk add NEW_PACKAGE
       ↓
make ctr-commit-next        # buildah commit → new image layer
       ↓
Container execs new goclaw process (or restart for full layer)
       ↓
Updated image immediately available locally or pushed to registry
```

**Pros:**
- Container evolves autonomously
- Standard OCI images (Docker/podman compatible)
- No privileged helper process
- Blue-green deployments without registry complexity
- Modules own their environment (no global state)

**Cons:**
- buildah + fuse-overlayfs in container (larger base)
- Security: container can install anything
- Layer accumulation over time

## Comparison

| Aspect | CI/CD | pkg-helper | Self-Building |
|--------|-------|------------|---------------|
| Speed | Minutes | Seconds | Seconds |
| External deps | CI, registry | None | None |
| Privileged process | No | Yes | No |
| OCI image output | Yes | No | Yes |
| Blue-green ready | Yes | No | Yes |
| Container autonomy | None | Partial | Full |
| Module isolation | Dockerfile | Helper process | Layer |

## When to Use Each

**CI/CD:** When you need audit trail, security hardening (container can't self-modify), or builds are rare.

**pkg-helper:** When you only need apk packages, want fast installs, and trust the container (privileged helper).

**Self-Building:** When you want the container to discover and evolve, need pip/npm isolation per layer, or want true blue-green without registry complexity.

## Security Note

All approaches run code inside the container. The security boundary is the container itself, not how packages get installed.
(all have similar attack surface inside the container).
