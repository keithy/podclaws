# Proposal: Goclaw Wrapper + Subcommands Architecture

## Problem

Current goclaw binary contains ~20 commands (agent, auth, backup, channels, config, cron, doctor, migrate, onboard, pairing, providers, restore, sessions, setup, skills, tenant-backup, tenant-restore, upgrade, version, gateway) all in one monolithic binary.

This creates issues:
- **Large attack surface** — container only needs `upgrade` but ships all commands
- **Unused code** — most deployments only use a subset of commands
- **Blurred separation** — upgrade service runs same binary as gateway, but needs only migration capability
- **Security principle** — minimal binaries reduce vulnerability blast radius

## Proposed Solution

Follow the **sensible** pattern: wrapper binary + focused subcommands.

```
cmd/
  goclaw/           # Wrapper/main entrypoint
  goclaw-upgrade/   # Standalone upgrade binary (DB migrations only)
  goclaw-agent/      # Agent management
  goclaw-backup/     # Backup/restore operations
  goclaw-onboard/    # Initial setup
  ...
```

### Wrapper (`goclaw`)
```go
var rootCmd = &cobra.Command{
    Use:   "goclaw",
    Short: "GoClaw — AI agent gateway",
    Run: func(cmd *cobra.Command, args []string) {
        runGateway()  // Default: run gateway
    },
}
// Registers all subcommands...
```

### Subcommand (`goclaw-upgrade`)
```go
//go:build minimal
// +build minimal

package main

func main() {
    // Only registers: upgrade, migrate, onboard, version
    // Imports only: config, migrations, database
}
```

### Build Pattern (like sensible)
```makefile
build:
    go build -o build/goclaw ./cmd/goclaw
    go build -o build/goclaw-upgrade ./cmd/goclaw-upgrade
    go build -o build/goclaw-backup ./cmd/goclaw-backup
    ...
```

## Benefits

1. **Minimal upgrade container** — only needs `goclaw-upgrade` binary, not full goclaw
2. **Attack surface reduction** — unused commands not present in container
3. **Clear separation** — upgrade service cannot become gateway, gateway cannot run migrations
4. **Independent versioning** — subcommands can be updated separately
5. **Follows sensible pattern** — proven architecture already in use

## Implementation Options

### Option A: Build Tags
Use `//go:build` tags per subcommand. Single `main.go` imports only needed packages per binary.

### Option B: Separate cmd directories
Each subcommand in own `cmd/goclaw-<name>/main.go`. Build script generates all binaries.

### Option C: Plugin architecture
Main binary loads commands from `$PATH` or lib directory at runtime. More complex but flexible.

## Recommendation

**Option B** — most explicit, easiest to understand, follows sensible pattern exactly.

## Files to Create

- `cmd/goclaw-upgrade/main.go` — standalone upgrade binary
- `cmd/goclaw-backup/main.go` — backup/restore binary  
- Update `Makefile` to build all binaries
- `Dockerfile.upgrade` — minimal container with only `goclaw-upgrade`

## Backward Compatibility

- `goclaw` without args → runs gateway (current behavior)
- `goclaw upgrade` → delegates to `goclaw-upgrade` if present, else runs inline upgrade
- Or: drop delegation entirely, user must call `goclaw-upgrade` directly

## Container Strategy

For upgrade service:
```dockerfile
FROM alpine:3.23
RUN apk add --no-cache ca-certificates
COPY goclaw-upgrade /bin/goclaw-upgrade
ENTRYPOINT ["/bin/goclaw-upgrade"]
CMD ["upgrade"]
```

No goclaw binary needed, no wrapper, just the single binary that does one thing.