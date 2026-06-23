---
name: goclaw-workflow-knowledge
description: Operational knowledge about the goclaw agent's environment, workflows, and active work.
---

# goclaw Agent Knowledge

## Working Environment

- **Source tree:** `/code/podclaws/goclaw` (Go 1.x, goclaw upstream).
- **Agent definition:** `/code/podclaws/agents/goclaw/` (agent.json, manifest.json, context_files/).
- **Agent TODOs:** `/code/podclaws/agents/goclaw/TODO.md`.
- **CI/workflows:** `/code/workflows/.github/` (separate repo, not under goclaw).

## CI / Daily Workflows (`/code/workflows/.github/workflows/`)

- `sync-fork.yml` — force-syncs `keithy/goclaw` from `nextlevelbuilder/goclaw` for given branches.
- `merge-prs-workflow.yml` — reusable: merges a comma-separated PR list onto an upstream branch, pushes to a named branch in `keithy/goclaw` with auto-backup.
- `goclaw-daily.yml` — weekday 06:00 UTC: sync → merge essential PRs into both `main` & `dev` → merge testing PRs into `main` only.

### Current PR configuration (as of 2026-06-15)

- Essential (`main+essential-prs`, `dev+essential-prs`): `1135`
- Testing (`main+testing-prs`): `1135`
- PR `1210` was removed from both lists (no longer needed).

## Branch State (as of 2026-06-15)

- Switched to `main` (fast-forwarded to `2f3d68e8`, in sync with `upstream/main`).
- Current tag: **v3.14.0**.
- Earlier branch state (now superseded): `feature/pkg-helper-fallback` (1 behind `origin`). PR #1210 (sudo fallback for pkg-helper) was merged into main via the daily workflow; the branch is no longer the working branch.

## pkg-helper Availability Check (server-side)

Location: `internal/skills/runtime_check.go:59-65` (function `CheckRuntimes`).

```go
pkgInfo := RuntimeInfo{Name: "pkg-helper"}
if fi, err := os.Stat(pkgHelperSocket); err == nil && fi.Mode().Type()&os.ModeSocket != 0 {
    pkgInfo.Available = true
    pkgInfo.Version = "socket"
}
```

- Detection is **socket-based** on `/tmp/pkg.sock` (constant `pkgHelperSocket` in `internal/skills/dep_installer.go:40`).
- UI surfaces this via `use-runtimes` hook (`ui/web/src/pages/skills/hooks/use-runtimes.ts`).
- Fallback path in `dep_installer.go:308-310` uses `exec.LookPath("pkg-helper")` and a 5s dial timeout.
- The fix (now on main) executes `/bin/pkg-helper <pkg>` as a standard subprocess; the unprivileged binary detects non-root and prefixes its commands with `sudo -n apk`.

## Mise Bootstrap Shims (podclaws)

Location: shims at `/code/podclaws/use/self-improve/shared-sbin/`, Alpine installers at `/code/podclaws/use/alpine/installers/`, Debian installers at `/code/podclaws/use/debian/installers/`, and the optional mise-based installers at `/code/podclaws/use/self-improve/mise-installers/`. Mounted into the goclaw container at `/usr/local/sbin/` (shims) and `/usr/local/bin/` (installers), and the `self-improve` skill at `/app/bundled-skills/self-improve` via the `+self-improve.yml` overlay. For mise, use `+mise-improve.yml` instead of `+self-improve.yml` (mutually exclusive).

### Architecture (as of 2026-06-16)

The shim is a **thin delegator** to a corresponding `add-*` script. The shim has no policy on install strategy or version; that's all in the `add-*` script.

- **`shim-common.sh`** (`lib/shim-common.sh`) provides `shim_main`. It:
  1. Spoofs `--version`/`-V`/`-v` by running `$ADD --version` and printing its output. The add-* script returns the version it **would** install (via `apk policy`, `npm view`, or a hardcoded variable). **Single source of truth for versions.**
  2. Walks `$PATH` looking for a non-self executable named `$TOOL`. If found, exec it.
  3. If not found, runs `$SELF_DIR/$ADD`. Re-walks `$PATH`. If found, exec. Else exit 127 with a not-installed message.
- The PATH walk is manual (not `command -v`) because the shim's own path is in PATH ahead of `/usr/bin/<tool>`, so `command -v` would always return the shim.
- The `add-*` script supports `--version` (print what would be installed) and the default mode (do the install). For apk-based scripts, `--version` uses `apk policy <pkg>` which is offline in steady state.

### The shims

11 shims use `shim-common.sh`:
`python`, `python3`, `pip`, `pip3`, `pipx` → `add-python` (apk: python 3.12.13, pip 25.1.1)
`node`, `npm` → `add-node` (apk: nodejs 24.14.1, npm 11.11.0)
`go` → `add-go` (apk: go 1.25.10)
`gh` → `add-gh` (apk: github-cli 2.83.0)
`mise` → `add-mise` (staged from `/usr/share/mise/RELEASES/mise/2025.8.20/aarch64/mise` via the `mise-musl` volume; needs lua 5.1 lib side-staged)
`pg_dump` → `add-pg-client` (apk: postgresql18-client 18.4, hardcoded)

`claude` and `psql` have custom flows (no stub, no `shim-common.sh`) and are out of scope of the standard shim layer.

### The 12 `add-*` scripts

Today we ship **three installer dirs**, each with a full set of 12 add-* scripts:

- `use/alpine/installers/` — apk-based. Default Alpine path.
- `use/debian/installers/` — apt-based. Default Debian path.
- `use/self-improve/mise-installers/` — mise for languages (python, node, go, claude), apk/apt for system tools (bash, git, gh, etc.). Used via the `+mise-improve.yml` overlay.

To migrate an `add-*` from apk to mise (or vice versa), change that single file in the relevant installer dir — the shim contract is unchanged.

Versions as of 2026-06-16 (alpine 3.23):
- python 3.12.13, pip 25.1.1
- nodejs 24.14.1, npm 11.11.0
- go 1.25.10
- bash 5.3.3, git 2.52.0
- gh 2.83.0 (apk, alpine community as `github-cli`)
- mise 2025.8.20 (staged in the `mise-musl` volume at `/usr/share/mise/RELEASES/mise/2025.8.20/aarch64/mise`; lua 5.1 lib side-staged at `/usr/share/mise/RELEASES/lua/5.1.5/aarch64/liblua.so.5.1.5`; lua 5.1 symlink recreated on each `add-mise` call because `/usr/lib` doesn't persist across `podman compose down`)
- postgresql18-client 18.4 (hardcoded; live probe at install time, fallback 18)
- execline 2.9.7.0, pandoc 3.8.2.1, poppler-utils 25.12.0

### Tests

- `use/self-improve/tests/` currently contains specs for `sensible_on_host_do.sh` and `podman_on_host.sh` only. **No shim tests yet.** A future test should:
  1. Verify the spoof is fast (<10ms) and contains the install command.
  2. Verify a non-version call triggers `add-*` and exec's the real tool.
  3. Verify the PATH walk avoids the shim (no recursion).
  4. Verify the post-install PATH walk finds the new binary.

## podclaws Build & Deploy

- `mise/config.toml` defines `GOCLAW_USE_BRANCH = "main"` (env var).
- `use/goclaw/Makefile` reads it. `build` target compiles goclaw + pkg-helper to `RELEASES/goclaw/$GOARCH/$VERSION/`. `sync-upstream` target fast-forwards local branch to `upstream/<branch>`. `checkout-branch` and `build` are decoupled.
- `mise run goclaw:build` chains `checkout-branch` + `build`.
- `mise run goclaw:sync` runs `sync-upstream` for both `main` and `dev`.
- `mise run goclaw:image` runs `use/goclaw/Makefile image` to build the skeleton Alpine container.

## podclaws Compose Layout

- Root: `podman-compose.yml` — declares `default` + `goclaw-net` networks. Named volumes `mise-musl` and `mise-cache` are declared in the `+mise-improve.yml` overlay (only when using mise).
- Services/overlays live under `use/<agent>/` and other top-level dirs.
- Filename convention: `foo.yml` (service), `+foo.yml` (overlay), `foo.bar.yml` (root).
- `podman/compose-services-select.sh` (wrapped by `mise run services:select`) manages the `COMPOSE_FILE` variable in `.env` based on selections in `.env-compose`.
- See `/code/podclaws/docs/compose-selection.md` for the full mechanism.

## Outstanding Items

See `/code/podclaws/agents/goclaw/TODO.md` for tracked work.
