# Bug: goclaw running as PID 1 does not reap child processes, accumulates zombies

## Summary

When goclaw runs as PID 1 in a container (or any environment where it is PID 1), child processes are never reaped and remain in the `Z` (zombie) state. Over time the process count grows until the container hits its cgroup `pids.max` ceiling, at which point `fork(2)` returns `EAGAIN` (`Resource temporarily unavailable`) and any tool invocation that needs to spawn a process fails.

This is a well-known issue for Go programs running as PID 1: the Go runtime does not install a `SIGCHLD` handler that calls `wait4(2)`, so children are never reaped unless the parent explicitly calls `cmd.Wait()`.

## Reproduction (podman, rootless)

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
2. Inside the container, repeatedly trigger tools that spawn short-lived children. In our case, calling a `mise` bootstrap shim that runs `wget -qO- https://mise.run | sh` was enough — each attempt leaks a small process tree.
3. Watch `podman top auto_goclaw_1` — after a few minutes, dozens of `[ssl_client]` and `[mise]` entries appear in `STAT = Z`.
4. The container's `pids.current` rises to `pids.max` (200/200).
5. New `fork()` calls start returning `EAGAIN`:
   ```
   sh: can't fork: Resource temporarily unavailable
   wget: fork: Resource temporarily unavailable
   ```

## Expected

goclaw should reap its children (zombie processes should be cleaned up promptly) regardless of whether it is PID 1. This is the standard behaviour of any well-behaved init process.

## Actual

Children accumulate as zombies. After ~25 minutes in our reproduction, ~180 of 200 PID slots were consumed by zombies, blocking any new `fork()`.

## Suggested fix

Install a `SIGCHLD` handler in the goclaw process that reaps children in a loop. Either:

- A small `signal.Notify` goroutine that calls `syscall.Wait4(-1, nil, syscall.WALL)` repeatedly, or
- Adopt a library such as [`github.com/jmmv/go-zombies`](https://github.com/jmmv/go-zombies) which does this correctly.

Either is preferable to the workaround of running goclaw with `init: true` in compose, which:
- Adds an extra process to the cgroup's PID budget
- Doesn't help users running goclaw under systemd, in k8s, or in any environment where it is the first process in a PID namespace
- Doesn't fix the underlying issue

## Environment

- goclaw: `v3.14.0` (commit `2f3d68e8`)
- Runtime: rootless podman with bridge networking (default network)
- Container: Alpine 3.23, goclaw binary directly (no entrypoint wrapper)
- cgroup v2, `pids.max = 200`

## Observed process tree (excerpt)

```
USER  PID  PPID  STAT  COMMAND
auto  1    0     S     /bin/goclaw
auto  14   1     Z     [mise]            ← zombie, not reaped
auto  18   1     Z     [ssl_client]      ← zombie
auto  38   1     Z     [ssl_client]
auto  41   1     Z     [mise]
...
```

`pids.current = 198`, `pids.max = 200`. `fork()` returns EAGAIN.
