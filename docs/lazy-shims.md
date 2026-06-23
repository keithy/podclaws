# Lazy Shims and the Install Path

The `use/self-improve/sbin/` directory contains:

- **Lazy shims** (`python`, `python3`, `pip`, `pip3`, `pipx`, `node`, `npm`, `go`, `gh`, `mise`, `pg_dump`): proxy binaries that make goclaw's hardcoded "install dependencies" action work. They are **stubs** that fall back to a real tool if one is on PATH, or to an `add-*` script if not.
- **`add-*` scripts** (`add-bash`, `add-node`, `add-python`, `add-gh`, `add-pg-client`, `add-office`, `add-oils`, `add-execline`, `add-claude`, `add-go`, `add-git`, `add-mise`): install the real tool. Each encodes its own **strategy** (apk, curl from upstream, etc.) and the **pinned version** in a header comment.
- A shared helper: `lib/shim-common.sh` — the shim's delegator logic.

## Why the shim is a thin delegator

The goclaw binary does things like:

```go
cmd := exec.CommandContext(ctx, "pip3", "install", "--no-cache-dir", "--break-system-packages", pkg)
```

(see `internal/skills/dep_installer.go:109`). For that call to succeed, `pip3` must be on PATH inside the container. The shim makes that true by:

1. Returning a fast stub for `--version` so UI/runtime probes (with a 3-second timeout) see a deterministic response.
2. For real invocations, **delegating to the real tool if it's on PATH**, or **running the corresponding `add-*` script to install it** if it isn't.

The shim does **not** decide what to install, what version, or via what mechanism. That's all in the `add-*` script.

## The shim contract

`lib/shim-common.sh` exports `shim_main`. A per-tool shim is typically 4 lines:

```sh
. "$(dirname "$0")/lib/shim-common.sh"
TOOL=pip3
ADD=add-python        # what to run if pip3 isn't on PATH
shim_main "$@"
```

`shim_main` does:

1. If first arg is `--version`, `-V`, or `-v` → run `$ADD --version` and print its output. The `add-*` script returns the version it **would** install (e.g. via `apk policy`). Single source of truth for versions.
2. Walk `$PATH` for an executable named `$TOOL` whose `realpath` differs from the shim's own. If found, exec it.
3. If `$SELF_DIR/$ADD` is executable → run it; then re-walk PATH; if found, exec.
4. Otherwise → print a generic not-installed message to stderr, exit 127.

The PATH walk in step 2 is manual (not `command -v`) because the shim itself lives at `/usr/local/sbin/<tool>` which is in PATH ahead of `/usr/bin`. `command -v` would return the shim path, leading to recursion. Walking PATH manually and skipping the shim's own realpath avoids that.

## The `add-* --version` protocol

Every `add-*` script supports a `--version` mode that prints the version it would install, without actually installing. For apk-based scripts, this is an `apk policy <pkg>` (offline after the first `apk update` per container). For `add-mise` (curl-based), it's a bounded `curl` to GitHub. For `add-gh` (pinned via a shell variable), it just prints the variable.

## Why apk, not mise, in `add-*` (for now)

The user has expressed tension between:

- **mise**: latest versions, per-tool, swappable. But needs network, downloads binaries, and mise's python-build / rust / go plugins need bash + git, which we'd rather keep opt-in.
- **apk**: stable, fast, integrated with the system, offline-capable, no extra dependencies. The package version matches the container base.

The decision encoded in the codebase:

- **Default to apk** (`add-*` scripts) for tools that have Alpine packages. Fast, stable, no transitive deps.
- **mise is opt-in** — when a tool needs a specific version not in apk, or when the user wants to manage multiple versions, swap that single `add-*` script to use mise. The shim contract doesn't change.

This keeps the **minimal dependency tree**: shim → `add-*` → `apk`. No mise required for the install path to work.

The version of each tool is **pinned in a comment in its `add-*` script**. To upgrade python, edit `add-python` and update the comment. No env vars, no central config file.

## Pinned versions (as of 2026-06-16)

| Tool   | Version  | Source         | Script        |
|--------|----------|----------------|---------------|
| python | 3.12.13  | apk (alpine 3.23) | `add-python` |
| pip    | 25.1.1   | apk            | `add-python` |
| nodejs | 24.14.1  | apk            | `add-node`    |
| npm    | 11.11.0  | apk            | `add-node`    |
| go     | 1.25.10  | apk            | `add-go`      |
| gh     | 2.83.0   | apk (github-cli)  | `add-gh`      |
| bash   | 5.3.3    | apk            | `add-bash`    |
| git    | 2.52.0   | apk            | `add-git`     |
| mise   | 2025.8.20 | RELEASES_MUSL/mise/ (staged) | `add-mise` |
| curl   | 8.19.0   | apk (image-baked) | n/a        |
| pandoc | 3.8.2.1  | apk            | `add-office`  |
| poppler-utils | 25.12.0 | apk     | `add-office`  |
| execline | 2.9.7.0 | apk           | `add-execline` |
| pg_dump | 18.4    | apk (postgresql18-client) | `add-pg-client` |

## Test path

Inside a running goclaw container:

```bash
# Fast: defers to add-python --version → "python 3.12.13, pip 25.1.1 (install via add-python)"
python3 --version

# Slow: triggers add-python (sudo apk add python3 py3-pip), then execs real pip3
pip3 list               # → "[Shim] pip3 not found, running add-python..." + apk output + real pip3 list

# After install: real binary is exec'd, no shim log
go version              # → "go version go1.25.10 linux/arm64"
```

Note: `add-* --version` is offline in steady state (`apk policy` queries the local index). On a fresh container the first call triggers an `apk update` (network) which can take a few seconds. The goclaw `getVersion` call has a 3-second timeout, so the first spoof after a container recreate may time out. If that becomes a problem, add a version cache file.

## Caveat: apk installs don't survive container recreation

When the shim triggers `add-<tool>`, the package is installed into the **container's read-write layer**, not a volume. `podman compose down` followed by `up` starts a fresh container with a clean layer — the previously-installed packages are gone.

For a dev workflow this is acceptable: the first call after a recreate takes a few seconds (shim detects missing → runs `add-*` → real binary available). For production, **bake the apk-installed packages into the image** (extend the `RUN apk add` line in the Dockerfile with whatever's needed).

## When to add a new shim

If a tool needs to be callable from the goclaw binary via `exec.Command` (i.e. it's part of the hardcoded install flow), and the tool isn't in the base image:

1. Create `add-<tool>` that does `sudo apk add <package>` (or curl from upstream for tools not in apk).
2. Create `<tool>` shim that sources `lib/shim-common.sh` with `TOOL=<tool>` and `ADD=add-<tool>`.
3. Set the spoof string to name the install command (so the test report is self-describing).

## Migrating an `add-*` from apk to mise

To pin a specific version of a tool that the apk version doesn't match (e.g. you need go 1.24 but apk has 1.25), rewrite that one `add-*` script to use mise:

```sh
#!/bin/sh
# add-go: install Go via mise (apk version is 1.25; we need 1.24)
set -e

# Ensure mise is on PATH (delegates to add-mise if not)
if ! command -v mise >/dev/null 2>&1; then
    "$(dirname "$0")/add-mise"
fi

mise use -g go@1.24
```

The shim contract doesn't change. Other shims that delegate to `add-go` (none today) would automatically pick up the new strategy.
