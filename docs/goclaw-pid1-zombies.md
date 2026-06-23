# goclaw as PID 1: Zombie Reaping

## Symptom

When goclaw runs as PID 1 in a container (or any environment where it is PID 1), child processes are never reaped and remain in the `Z` (zombie) state. Over time the process count grows until the container hits its cgroup `pids.max` ceiling, at which point `fork(2)` returns `EAGAIN` (`Resource temporarily unavailable`) and any tool invocation that needs to spawn a process fails.

This is a well-known issue for Go programs running as PID 1: the Go runtime does not install a `SIGCHLD` handler that calls `wait4(2)`, so children are never reaped unless the parent explicitly calls `cmd.Wait()`.

## Reproduction

```yaml
# compose fragment
services:
  goclaw:
    image: localhost/goclaw:current
    command: ["/bin/goclaw"]
    # NOTE: no `init: true` — goclaw is PID 1
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '2.0'
          pids: 200   # the cap that triggers the failure
```

1. Start the container: `podman compose up -d goclaw`
2. Trigger tools that spawn short-lived children. (In our case, calling a `mise` bootstrap shim that runs `wget -qO- https://mise.run | sh` was enough — each attempt leaks a small process tree.)
3. Watch `podman top auto_goclaw_1` — after a few minutes, dozens of `[ssl_client]` and `[mise]` entries appear with `STAT = Z`.
4. The container's `pids.current` rises to `pids.max`.
5. New `fork()` calls start returning `EAGAIN`:
   ```
   sh: can't fork: Resource temporarily unavailable
   wget: fork: Resource temporarily unavailable
   ```

## Expected

goclaw should reap its children (zombie processes should be cleaned up promptly) regardless of whether it is PID 1. This is the standard behaviour of any well-behaved init process.

## Local Workaround

`use/goclaw/service.goclaw.yml` sets `init: true`. This wraps the goclaw command with `tini`, which reaps zombies and proxies signals. Trade-offs:

- **Adds a process to the cgroup's PID budget.** tini is PID 1, goclaw becomes PID 2.
- **Doesn't fix the upstream bug.** Anyone running goclaw as PID 1 directly (bare Docker, k8s without an init container, systemd) still hits the issue.
- **Doesn't help users in non-podman environments.**

To apply after editing the compose file:

```bash
# init is not a runtime-configurable knob — must recreate the container
podman compose up -d
```

## Upstream Fix

Install a `SIGCHLD` handler in the goclaw process that reaps children in a loop. Two reasonable options:

- A small `signal.Notify` goroutine that calls `syscall.Wait4(-1, nil, syscall.WALL)` repeatedly, or
- Adopt a library such as [`github.com/jmmv/go-zombies`](https://github.com/jmmv/go-zombies) which does this correctly.

The bug is tracked at `/code/podclaws/BUG_REPORT_GOCLAW_PID1_ZOMBIES.md` (draft for filing upstream).
