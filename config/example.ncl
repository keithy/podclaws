# config/example.ncl — starter config for podclaws.
#
# How to use:
#   1. Copy this file to config/config.ncl:
#        cp config/example.ncl config/config.ncl
#   2. Edit the `fragments` list below to pick which services
#      and overlays you want enabled.
#   3. Render:
#        nickel export --format yaml config/config.ncl > compose.yml
#      or, via the wrapper at nickel-compose/wrappers/from-nickel-compose.sh:
#        NICKEL_COMPOSE='config/config.ncl' ../nickel-compose/wrappers/from-nickel-compose.sh
#   4. Validate:
#        podman-compose -f compose.yml config
#
# Why this lives under ./config/ (gitignored) and not at the repo root:
# your selection is personal. A developer enabling +code.yml or +dev.yml
# overlays shouldn't dirty the repo for everyone else. config/example.ncl
# is the committed template; config/config.ncl is your local copy.
#
# Podclaws historically used podman/compose-services-select.sh to build
# a COMPOSE_FILE list from .env-compose. This Nickel file replaces that
# shell script — same selection mechanism, but typed and merge-aware.

let build = import "../../nickel-compose/lib/merge.ncl" in

let fragments = [
  # goclaw service — the main agent runtime
  import "../use/goclaw/service.goclaw.yml",

  # Overlays — comment out what you don't want
  import "../use/goclaw/+code.yml",
  import "../use/goclaw/+self-improve.yml",
  import "../podman/+network-fix.yml",
] in

build fragments