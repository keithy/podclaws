# TODO

## Multi-deployment coexistence
- [x] Network key in podclaws compose files renamed from `goclaw-net` to `default` (single bridge network)
- [x] Drop the `goclaw-net` declaration from `compose.yml`; everything uses the default bridge
- [ ] Verify `sensible-tasks` volume naming doesn't conflict between deployments

## GoClaw Upstream PRs
- [ ] PR to remove absolute dependency on `/tmp/pkg.sock` in `dep_installer.go`. Enable alternative strategies (e.g., check for `sudo` and run `sudo apk` directly, or fallback to executing `/bin/pkg-helper <pkg>` directly if socket is unavailable).