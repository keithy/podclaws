# TODO

## Multi-deployment coexistence
- [x] Network key in podclaws compose files renamed from `goclaw-net` to `net` (auto-generates as `{project_name}_net`)
- [ ] Note: `goclaw/` submodule defines its own `goclaw-net` key in compose files — cannot change from here, auto-generates as `{project_name}_goclaw-net` for goclaw services
- [ ] Verify `sensible-tasks` volume naming doesn't conflict between deployments

## GoClaw Upstream PRs
- [ ] PR to remove absolute dependency on `/tmp/pkg.sock` in `dep_installer.go`. Enable alternative strategies (e.g., check for `sudo` and run `sudo apk` directly, or fallback to executing `/bin/pkg-helper <pkg>` directly if socket is unavailable).