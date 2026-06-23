# Minimal goclaw runtime - binary mounted from RELEASES
FROM alpine:3.23

# sudo:   needed for pkg-helper fallback and add-<tool> scripts
# curl:   real HTTP client with --retry, used by the mise bootstrap shim
#         (BusyBox wget has no --tries/--waitretry and drops large downloads)
#
# bash, git, and ca-certificates are intentionally NOT installed:
#   - bash:    install on demand with `add-bash` (some mise plugins like
#              python-build invoke /usr/bin/env bash)
#   - git:     only needed if you `mise use -g` a tool that compiles from
#              source. Pre-built tools (node, go) work without it.
#   - ca-certificates: the host's CA bundle is bind-mounted at
#              /etc/ssl/certs/ca-certificates.crt at runtime, so the
#              container picks up CA updates without rebuilding. See
#              service.goclaw.yml (PODCLAWS_CA_BUNDLE).
RUN apk add --no-cache sudo curl

COPY ./ROOT /

# Uncomment to wrap the command (e.g. set umask 0002)
ENTRYPOINT [ "/entrypoint.sh" ]

