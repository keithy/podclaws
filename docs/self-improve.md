## Self-Improve

By default, goclaw uses `pkg-helper` (a privileged daemon) to install packages into a container.
Since we use rootless Podman and commit our environments, this behavior is changed:

1. **System Packages (`apk`)**: The `pkg-helper` daemon is bypassed. Because of upstream PR (#1210), GoClaw runs `/bin/pkg-helper <pkg>` as a standard subprocess. This unprivileged binary detects it is not root and automatically prefixes its internal commands with `sudo -n apk`, leveraging the container's sudo capabilities directly. We allow sudo in the container, because we are confident of the security of rootless podman and other security measures.

2. **Pip/NPM & Runtimes (Managed via `mise`)**: We do not bake `python` or `node` into our minimal base images. Instead, we map a set of **lazy shims** into the container's `PATH` via `service.goclaw.yml`. 
   - When an agent calls a tool for the first time (e.g., `python` or `node`), our lazy shim intercepts it.
   - The shim bootstraps `mise` and installs the requested tool globally (`mise use -g python@latest`).
   - `mise` natively generates its own shims in `~/.local/share/mise/shims`.
   - Because `~/.local/share/mise/shims` is mapped to the *very front* of the container's `PATH`, all subsequent calls hit the native `mise` shim and bypass our lazy wrapper completely.
3. **Persistence**: Since packages and runtimes are installed directly into the container's filesystem by `mise`, they are persisted by committing the Podman container to an image, rather than relying on volume mounts.


