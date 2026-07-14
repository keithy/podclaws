# config/example.ncl — starter config for podclaws.
#
# Podclaws historically used podman/compose-services-select.sh to build
# a COMPOSE_FILE list from .env-compose. This Nickel file replaces that
# shell script — same selection mechanism, but typed and merge-aware.
#
# How to use:
#   1. Copy this file to config/config.ncl:
#        cp config/example.ncl config/config.ncl
#   2. Edit the `fragments` list below to pick which services
#      and overlays you want enabled. Comment out an import to
#      disable it (just like the `#` lines in .env-compose).
#   3. Render:
#        nickel export --format yaml config/config.ncl > compose.yaml
#   4. Validate:
#        podman-compose -f compose.yaml config
#
# Why this lives under ./config/ (gitignored) and not at the repo root:
# your selection is personal. A developer enabling +code.yml or +dev.yml
# overlays shouldn't dirty the repo for everyone else. config/example.ncl
# is the committed template; config/config.ncl is your local copy.

let composer = import "../../nickel-compose/nickel-compose.ncl" in

let fragments = [
  # === ROOT (required) ===
  import "../compose.yml",

  # === SERVICE (optional) ===
  import "../goclaw/docker-compose.postgres.yml",
  import "../goclaw/docker-compose.selfservice.yml",
  # import "../goclaw/docker-compose.upgrade.yml",
  import "../use/goclaw/service.goclaw.yml",
  import "../use/goclaw/service.upgrade.yml",
  # import "../goclaw/docker-compose.browser.yml",
  # import "../goclaw/docker-compose.claude-cli.yml",
  # import "../goclaw/docker-compose.otel.yml",
  # import "../goclaw/docker-compose.redis.yml",
  # import "../goclaw/docker-compose.sandbox.yml",
  # import "../goclaw/docker-compose.tailscale.yml",
  # import "../picoclaw/docker/docker-compose.yml",
  # import "../picoclaw/docker/docker-compose.full.yml",
  # import "../use/debian/goclaw/service.goclaw.yml",
  # import "../use/debian/goclaw/service.sandbox.yml",
  # import "../use/goclaw/service.redis.yml",
  # import "../use/goclaw/service.sandbox.yml",
  # import "../use/otel/service.aspire.yml",
  # import "../use/otel/service.jaeger.yml",

  # === OVERLAY (optional) ===
  import "../podman/+network-fix.yml",
  import "../podman/+user-fix.yml",
  import "../use/goclaw/+self-improve.yml",
  # import "../use/debian/goclaw/+self-improve.yml",
  # import "../use/goclaw/+code.yml",
  # import "../use/goclaw/+mise-improve.yml",
  # import "../use/otel/+goclaw-aspire.yml",
  # import "../use/otel/+goclaw-jaeger.yml",
  # import "../use/postgres/+low-cpu.yml",
  # import "../zfs/+zfs.yml",

  # === POST-OVERLAY (final, applied last) ===
  # import "../use/goclaw/~reset-build.yml",
] in

composer.merge fragments