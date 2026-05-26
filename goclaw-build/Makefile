# Makefile for building versioned goclaw binaries for Alpine Linux (volume mounting)
#
#   make build              Build current arch → RELEASES/goclaw/$GOARCH/$VERSION/goclaw
#   make build-amd64       Build amd64 only
#   make build-arm64       Build arm64 only
#   make build-all         Build both amd64 + arm64, update latest symlinks
#   make clean             Remove RELEASES/goclaw/
#
# Run from goclaw-build/ directory:
#   cd goclaw-build && make build
#
# Version is derived from the goclaw submodule git tag:
#   cd ../goclaw && git describe --tags --abbrev=0 --match "v[0-9]*"
#
# Output structure (at goclaw-prod/RELEASES/goclaw/):
#   goclaw/amd64/
#     v1.9.0/goclaw        ← binary
#     v1.9.0/goclaw.sha256 ← checksum
#     latest -> v1.9.0     ← symlink
#   goclaw/arm64/
#     v1.9.0/goclaw
#     v1.9.0/goclaw.sha256
#     latest -> v1.9.0

SHELL := /bin/bash
GOCLAW_DIR := $(abspath $(CURDIR)/../goclaw)
RELEASES_DIR := $(abspath $(CURDIR)/../RELEASES/goclaw)

VERSION := $(shell cd $(GOCLAW_DIR) && git describe --tags --abbrev=0 --match "v[0-9]*" 2>/dev/null || echo dev)
LDFLAGS := -s -w -X github.com/nextlevelbuilder/goclaw/cmd.Version=$(VERSION)

GOOS := linux
GOARCH := $(shell go env GOARCH 2>/dev/null || echo amd64)

.PHONY: build build-amd64 build-arm64 build-all clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

# --------------------------------------------------------------------
# Build current host architecture
# --------------------------------------------------------------------

build: build-$(GOARCH) latest-link

# --------------------------------------------------------------------
# Build amd64
# --------------------------------------------------------------------

build-amd64: $(RELEASES_DIR)/amd64/$(VERSION)/goclaw

$(RELEASES_DIR)/amd64/$(VERSION)/goclaw:
	@mkdir -p $(RELEASES_DIR)/amd64/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=amd64 \
		go build -ldflags="$(LDFLAGS)" -o $(RELEASES_DIR)/amd64/$(VERSION)/goclaw .
	@cd $(RELEASES_DIR)/amd64/$(VERSION) && sha256sum goclaw > goclaw.sha256
	@echo "  VERSION  $(VERSION)"
	@echo "  ARCH     $(GOOS)/amd64"
	@echo "  OUTPUT   $(RELEASES_DIR)/amd64/$(VERSION)/"
	@echo "Built: $(RELEASES_DIR)/amd64/$(VERSION)/goclaw"

# --------------------------------------------------------------------
# Build arm64
# --------------------------------------------------------------------

build-arm64: $(RELEASES_DIR)/arm64/$(VERSION)/goclaw

$(RELEASES_DIR)/arm64/$(VERSION)/goclaw:
	@mkdir -p $(RELEASES_DIR)/arm64/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=arm64 \
		go build -ldflags="$(LDFLAGS)" -o $(RELEASES_DIR)/arm64/$(VERSION)/goclaw .
	@cd $(RELEASES_DIR)/arm64/$(VERSION) && sha256sum goclaw > goclaw.sha256
	@echo "  VERSION  $(VERSION)"
	@echo "  ARCH     $(GOOS)/arm64"
	@echo "  OUTPUT   $(RELEASES_DIR)/arm64/$(VERSION)/"
	@echo "Built: $(RELEASES_DIR)/arm64/$(VERSION)/goclaw"

# --------------------------------------------------------------------
# Build all architectures
# --------------------------------------------------------------------

build-all: build-amd64 build-arm64 latest-link
	@echo ""
	@echo "All architectures built:"
	@find $(RELEASES_DIR) -type f -name "goclaw*" | sort

# --------------------------------------------------------------------
# Symlinks: RELEASES/goclaw/$GOARCH/latest → RELEASES/goclaw/$GOARCH/$VERSION
# --------------------------------------------------------------------

latest-link:
	@ln -sfn $(VERSION) $(RELEASES_DIR)/$(GOARCH)/latest
	@echo "  $(GOARCH)/latest → $(VERSION)"

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------

clean: ## Remove all versioned releases
	rm -rf $(RELEASES_DIR)
	@echo "Removed $(RELEASES_DIR)/"