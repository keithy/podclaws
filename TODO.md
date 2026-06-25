# TODO

## Multi-deployment coexistence
- [x] Network key in podclaws compose files renamed from `goclaw-net` to `default` (single bridge network)
- [x] Drop the `goclaw-net` declaration from `compose.yml`; everything uses the default bridge
- [x] Use `!reset [default]` on goclaw-ui.networks in podman/+network-fix.yml to strip the upstream docker-compose.selfservice.yml's goclaw-net reference, so the merge tree resolves without re-declaring goclaw-net anywhere
- [ ] Replace goclaw/docker-compose.postgres.yml and selfservice.yml with podclaws-local equivalents (service.postgres.yml, service.web.yml) so we no longer depend on the upstream submodule's network references
- [ ] Verify `sensible-tasks` volume naming doesn't conflict between deployments

## GoClaw Upstream PRs
- [ ] PR to remove absolute dependency on `/tmp/pkg.sock` in `dep_installer.go`. Enable alternative strategies (e.g., check for `sudo` and run `sudo apk` directly, or fallback to executing `/bin/pkg-helper <pkg>` directly if socket is unavailable).