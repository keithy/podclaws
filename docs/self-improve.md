## Self-Improve

### 1. **Pip/NPM & Runtimes  (Managed via `mise`)**:

We do not bake `python` or `node` into our minimal base images. Instead, we map a set of **lazy shims** into the container's `PATH` via `service.goclaw.yml`. 
   - When an agent calls a tool for the first time (e.g., `python` or `node`), our lazy shim intercepts it.
   - The shim bootstraps `mise` and installs the requested tool globally (`mise use -g python@latest`).
   - `mise` natively generates its own shims in `~/.local/share/mise/shims`.
   - Because `~/.local/share/mise/shims` is mapped to the *very front* of the container's `PATH`, all subsequent calls hit the native `mise` shim and bypass our lazy wrapper completely.

### 2. **Persistence**:

Since packages and runtimes are virtually installed into the container's filesystem by `mise` and its ability to use shims , the shims are persisted by requesting the host to commit the running container to an image, rather than relying on volume mounts.

Volume mounts are in fact used behind the scenes to provide a shared library of all the actual tool binaries and libraries.

### 3. Secure Host Communication (Sensible)

- AI agents inside the container use `sensible` to queue and execute validated `execlineb` scripts on the host, eliminating the need for direct shell or SSH access from the container to the host. The host defines a very restricted whitelist of valid actions.

```

 "whitelist": [
    "^podman commit",
    "^podman rmi",
    "^podman tag",
    "^podman restart"
  ],
  "blacklist": ["^.*"]
  ```

### 4. `goclaw` uses `pkg-helper`

By default, `goclaw` has built in code that uses `pkg-helper` (a privileged daemon) to install packages into a container.
This is used when goclaw imports skills, scanning and installing dependencies including `apk` packages. 

Since the `self-improve` mechanism above is simpler and more universal, rootless podman is more secure, and the host can commit our *improved* environments, `pkg-helper` is mostly redundant. However because `goclaw` has this feature coded in we support it.

In podclaws deployment the `pkg-helper` daemon socket is not provided. As a fallback (PR#1210) it runs `/bin/pkg-helper <pkg>`. This unprivileged binary (our version) detects that it is not root and automatically prefixes its internal commands with `sudo -n apk`, leveraging the container's sudo capabilities directly. We allow sudo in the container, because we are confident of the security of rootless podman and other security measures.

### 5. How GoClaw's Existing Code Flows Through This

Because the lazy shims sit at the front of the container's `PATH`, **all of GoClaw's existing dependency installation code automatically benefits** from the mise architecture without any upstream changes:

- `pip3 install pandas` (from `internal/skills/dep_installer.go`) → hits our `pip3` lazy shim → bootstraps mise → installs pandas to the shared ZFS site-packages.
- `npm install -g typescript` → hits our `npm` lazy shim → bootstraps Node → installs to the shared global node_modules.
- `python3 --version` (from `internal/skills/runtime_check.go`) → hits our `python3` shim → instantly resolves via mise.

GoClaw is completely unaware of `mise`, ZFS volumes, or shim directories. It just calls `pip3`/`node`/`npm` like any normal process, and the architecture transparently handles toolchain provisioning, persistence, and sharing.

#### Per-Version Package Isolation

Because `mise` installs each tool version into its own directory (e.g., `/srv/mise/installs/glibc/installs/python/3.11.x/`, `python/3.12.x/`, etc.), pip packages are *strictly scoped* to their parent interpreter. 

- `pip3 install pandas` invoked under Python 3.11 installs to `python/3.11.x/lib/.../site-packages/pandas/`.
- `pip3 install pandas` invoked under Python 3.12 installs to `python/3.12.x/lib/.../site-packages/pandas/`.

This means a project locked to Python 3.11 (via its local `mise/config.toml`) will see its own clean set of packages, completely isolated from another project on Python 3.12. `mise` automatically routes the `pip3` call to the correct interpreter's site-packages, and the shared ZFS volume keeps everything efficient (common wheels/tarballs are cached once in `/srv/mise/cache` and reused across all versions and containers).

Note: this is *not* a true Python `venv` (no `pyvenv.cfg`, no `bin/activate`, no `sys.prefix` redirection). It is simply a per-version global site-packages directory. This is perfectly adequate for the majority of AI agent workflows (where you typically want one stable set of packages per Python version across the whole system). 

When true `venv` isolation is required, `mise` provides first-class support. Per the [official documentation](https://mise.jdx.dev/lang/python.html#python-venv-configuration), the recommended pattern in our ZFS-backed setup is to point the venv at a shared volume path so all containers can activate the identical environment:

```toml
[tools]
python = "3.12"

[env]
# Default for our architecture: venv lives on the shared ZFS volume,
# not in the project directory, so every container sees the same env.
_.python.venv = { path = "/srv/mise/venvs/my-project", create = true }
```

The `_` prefix in `_.python.venv` is a mise-specific directive telling mise to manage the venv transparently. When the project directory is entered, mise prepends the venv's `bin/` to `PATH` and (if `create = true`) auto-builds it using `uv` (if available) or `python -m venv`.

> **⚠️ Caveat with our shim-based setup:** The upstream docs note that *"Virtualenv activation requires `mise activate` or `mise exec`. When using shims alone, the venv's `bin/` directory is not added to PATH."* This means that for GoClaw processes (which do not source a shell profile and therefore never trigger `mise activate`), a venv's installed CLI scripts will *not* shadow our `sbin/*` shims on the `PATH`. The shim will be found first. This is generally fine for typical GoClaw workflows (which call `python3 -c "import pandas"` or `pip install <pkg>`), but projects that rely on invoking scripts *from inside the venv's bin/* must either invoke them via their full path or use `mise exec -- <script>`.

Per-version and venv packages can coexist: `[tools].python.postinstall` installs into the core interpreter, while venv packages live in the venv itself. The venv takes precedence on `PATH`, with the core interpreter as a fallback — but only when the calling shell has activated mise (not when using bare shims as GoClaw does).