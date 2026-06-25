# OTel overlays

OpenTelemetry backend overlays for goclaw. Each provides an OTLP receiver
that goclaw can export traces to, plus a UI for visualization.

## Requirements (all overlays)

- `GOCLAW_BUILD_TAGS` in `../../.env` must include `otel` (e.g. `otel,tsnet,redis`).
- Rebuild the goclaw binary after changing `GOCLAW_BUILD_TAGS`:
  ```bash
  cd use/goclaw && make build
  ```

## Available overlays

| File | Backend | RAM | Persistence | UI scope |
|---|---|---|---|---|
| `+goclaw-jaeger.yml` | Jaeger all-in-one | 50–100 MB | BadgerDB (disk) | Traces |
| `+goclaw-aspire.yml` | .NET Aspire Dashboard | 40–80 MB | In-memory | Traces + logs + metrics |

### Which to use?

- **Aspire** — modern UI with traces + logs + metrics in one view, lowest RAM.
  Best for active debugging. Traces lost on container restart.
- **Jaeger** — trace-only UI, persists to disk. Best when you want trace
  history across restarts.

Both accept OTLP gRPC on port 4317. Switch between them by changing which
`-f` overlay you include in your compose command; no other changes needed.

## Usage

Pick one overlay and add it to your stack:

```bash
# Jaeger
docker compose -f use/goclaw/service.goclaw.yml \
               -f use/otel/+goclaw-jaeger.yml up -d

# Aspire
docker compose -f use/goclaw/service.goclaw.yml \
               -f use/otel/+goclaw-aspire.yml up -d
```

## Endpoints

| Port | Service | Purpose |
|---|---|---|
| 16686 | Jaeger UI | Trace search and visualization |
| 18888 | Aspire UI | Traces + logs + metrics dashboard |
| 4317 | both | OTLP gRPC receiver |
| 4318 | Jaeger only | OTLP HTTP receiver |

## Endpoints

After `up -d`, access the UI on:
- Jaeger: `http://localhost:16686`
- Aspire: `http://localhost:18888`

## Adding a new backend

Create `+goclaw-<backend>.yml` following the existing pattern:
1. Add a service for the backend container
2. Set `GOCLAW_TELEMETRY_*` env vars on the `goclaw` service block
3. Add `depends_on` for the backend

Keep the file under ~30 lines; this is a simple "add a backend" overlay,
not a config-management layer.