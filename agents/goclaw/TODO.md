# goclaw Agent TODO

## Pending

- [ ] **Fix pkg-helper availability check** — `internal/skills/runtime_check.go:60-65` uses an `os.Stat` socket-only check on `/tmp/pkg.sock`. Confirm whether this is the right check, whether the UI surfaces it correctly, and fix as needed. Tied to `use-runtimes` hook in `ui/web/src/pages/skills/hooks/use-runtimes.ts`.
- [ ] **Create k8s/Makefile and test Kubernetes support** — `k8s/Makefile` does not exist yet. Scope: define what "Kubernetes support" means for goclaw (deployment manifests? operator? CI runner?). Create the Makefile, add basic targets (build/deploy/test), and verify against a test cluster or kind/minikube.

  ### Approach (agreed 2026-06-15)

  Translate the existing `podman-compose` fragments to k8s, then hand-fix the bits podclaws needs that compose tools can't infer.

  **Tooling**: `podman compose kube` (built into podman) for the 90% baseline, then a small Makefile that runs the translation and applies patches.

  **Target**: single-node k3s as the realistic homelab/dev target — supports `hostPath` cleanly, single binary, mirrors the current podman single-node model. Multi-node would force PVCs for mise and a different sensible-bridge shape; defer.

  **What podclaws needs to preserve** (compose translators don't handle these):
  1. **Binary volume mount** — `${RELEASES}/goclaw/$ARCH/$VER/{goclaw,pkg-helper}` → `hostPath` on the binary path. No auto-update on rebuild, same as podman.
  2. **`pkg-helper` root socket** — privileged init container creates `/tmp/pkg.sock` (emptyDir), goclaw container connects via shared volume. `securityContext.privileged: true` on the init, not the main container.
  3. **`sensible` host bridge** — no compose equivalent. Needs a node-local sidecar (DaemonSet) or external service. The "executes on host" semantic requires the pod to reach a host process; on k8s that's a service backed by a nodePort + hostNetwork, or accepting that sensible is a process the pod calls over the network and trusting the whitelist.
  4. **Mise named volumes (`mise-musl`, `mise-cache`)** — `hostPath` to whatever path you choose on the host. The current podclaws setup leaves these as default podman-managed named volumes. Single-node only.
  5. **`extra_hosts: host.docker.internal:host-gateway`** → manual `spec.hostAliases` (or drop — only needed for sensible).
  6. **Healthcheck** → `livenessProbe`/`readinessProbe` on `:18790/health`.

  **What translates cleanly**: `cap_drop: ALL` + `cap_add: SETUID/SETGID/CHOWN` → `securityContext.capabilities`. `no-new-privileges` → `allowPrivilegeEscalation: false`. `tmpfs: /tmp:rw,noexec,nosuid,size=256m` → `emptyDir.medium: Memory` with `sizeLimit`. `depends_on: condition: service_healthy` → init container gating.

  **Deliverables**:
  - `k8s/Makefile` with `manifest` (run `podman compose kube`), `patch` (apply hand-fixes), `test` (kind/k3s apply + smoke `curl /health`), `clean`.
  - `k8s/base/` — translated + patched manifests for the core stack: goclaw, pkg-helper init, postgres (external by default, in-cluster toggle), upgrade Job, sensible bridge.
  - `k8s/overlays/` — equivalents of the compose overlays (postgres, redis, browser, otel, tailscale, sandbox). Defer to v2.
  - Documentation in `docs/k8s.md` (status, target, known limitations vs podman).

  **Out of scope for v1**: multi-node, multi-tenant, operator/CRD, helm chart, any of the optional overlays (postgres/redis/browser/otel/tailscale/sandbox).

  **Blocker (2026-06-15)**: the port of goclaw from docker to rootless podman is not complete yet (per user). Kubernetes work should wait until the podman port is stable — otherwise the k8s manifests will be translating moving targets.

- [ ] **Agent: detect shim stubs and trigger the right `add-*` install** — The lazy shims in `use/self-improve/shared-sbin/{python,python3,pip,pip3,pipx,node,npm,go,gh,mise,pg_dump}` now spoof `--version`/`-V`/`-v` with a self-describing stub string (e.g. `python3 3.12.13 (shim stub — install via add-python)`). The `claude` and `psql` shims have custom flows (no stub) and are out of scope. The agent should:
  1. Probe a tool via `<tool> --version` before using it.
  2. Detect a stub by grepping for `shim stub` in the output.
  3. Extract the install command from the message (`add-<tool>`).
  4. Run the install via `sudo` (the goclaw user is in `/etc/sudoers.d/anyuser` with NOPASSWD).
  5. Re-probe to confirm the real tool is now in PATH.

  **Architecture agreed 2026-06-16 (apk-first, mise-later)**:
  - Shims are **thin delegators**: spoof version, exec real if on PATH, else run `add-<tool>`.
  - The shim has **no policy** on install strategy — that lives in `add-*` scripts.
  - All current `add-*` scripts use **apk** (or curl from upstream for `gh`/`mise`).
  - **Version pinning** lives as a comment in each `add-*` script (no env vars, no central config).
  - Migrating an `add-*` from apk to mise is a single-file change; the shim contract is unchanged.

  **Foundation in place** (as of 2026-06-16):
  - `use/self-improve/shared-sbin/lib/shim-common.sh` — `shim_main` helper.
  - 11 shims use it: `python`, `python3`, `pip`, `pip3`, `pipx`, `node`, `npm`, `go`, `gh`, `mise`, `pg_dump`. `claude` and `psql` have custom flows and are out of scope.
  - 12 `add-*` scripts: `add-bash`, `add-claude`, `add-execline`, `add-gh`, `add-git`, `add-go`, `add-mise`, `add-node`, `add-office`, `add-oils`, `add-pg-client`, `add-python`. Each header comments the strategy and the pinned version.
  - **Three installer dirs** (each variant picks one via its compose overlay):
    - `use/alpine/installers/` — apk-based, default Alpine path.
    - `use/debian/installers/` — apt-based, used by the Debian variant.
    - `use/self-improve/mise-installers/` — mise for languages (python, node, go), OS package manager as fallback for system tools. Used via `+mise-improve.yml`. Works on both Alpine and Debian.
  - `mise-reset` script clears the bootstrap state for re-testing (legacy; `add-mise` is now the proper path).

  **Pinned versions** (apk, alpine 3.23): python 3.12.13, pip 25.1.1, nodejs 24.14.1, npm 11.11.0, go 1.25.10, gh 2.93.0 (curl), bash 5.3.3, git 2.52.0.

  **Not yet done**: the agent-side logic. Could live as a skill (`skills/shim-bootstrap/`) or as a pattern in the agent's system prompt. Probably best as a small skill so other agents in the fleet can reuse it.
