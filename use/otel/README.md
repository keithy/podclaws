# OTel overlays

OpenTelemetry backend overlays for goclaw. Each provides an OTLP receiver
that goclaw can export traces to, plus a UI for visualization.

The overlays follow a two-file split mirroring the redis pattern:

  service.<backend>.yml     the backend container itself (image, ports, etc.)
  +goclaw-<backend>.yml     goclaw-side wiring (env vars, depends_on)

This lets the backend container be used independently (e.g. pointed at by
multiple services) while the goclaw-side patches stay focused.

## Requirements (all overlays)

- `GOCLAW_BUILD_TAGS` in `../../.env` must include `otel` (e.g. `otel,tsnet,redis`).
- Rebuild the goclaw binary after changing `GOCLAW_BUILD_TAGS`:
  ```bash
  cd use/goclaw && make build
  ```

## Available overlays

| Service file | Overlay file | Backend | RAM | Persistence | UI scope |
|---|---|---|---|---|---|
| `service.jaeger.yml` | `+goclaw-jaeger.yml` | Jaeger all-in-one | 50–100 MB | BadgerDB (disk) | Traces |
| `service.aspire.yml` | `+goclaw-aspire.yml` | .NET Aspire Dashboard | 40–80 MB | In-memory | Traces + logs + metrics |

### Which to use?

- **Aspire** — modern UI with traces + logs + metrics in one view, lowest RAM.
  Best for active debugging. Traces lost on container restart.
- **Jaeger** — trace-only UI, persists to disk. Best when you want trace
  history across restarts.

Both accept OTLP gRPC on port 4317. Switch between them by changing which
`-f` overlays you include in your compose command.

## Usage

```bash
# Jaeger (two-file pattern)
docker compose -f use/goclaw/service.goclaw.yml \
               -f use/otel/service.jaeger.yml \
               -f use/otel/+goclaw-jaeger.yml up -d

# Aspire (two-file pattern)
docker compose -f use/goclaw/service.goclaw.yml \
               -f use/otel/service.aspire.yml \
               -f use/otel/+goclaw-aspire.yml up -d
```

Add `-f zfs/+zfs.yml` to either to enable Jaeger persistence via the
shared `misc` ZFS dataset.

## Endpoints

| Port | Service | Purpose |
|---|---|---|
| 16686 | Jaeger UI | Trace search and visualization |
| 18888 | Aspire UI | Traces + logs + metrics dashboard |
| 4317 | both | OTLP gRPC receiver |
| 4318 | Jaeger only | OTLP HTTP receiver |

After `up -d`, access the UI on:
- Jaeger: `http://localhost:16686`
- Aspire: `http://localhost:18888`

## Adding a new backend

Create the two-file pair following the aspire pattern:
1. `service.<backend>.yml` — backend container, ports, restart policy
2. `+goclaw-<backend>.yml` — env vars on the goclaw service, depends_on

Keep both files under ~30 lines each.