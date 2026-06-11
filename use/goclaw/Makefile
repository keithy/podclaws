# Makefile for building goclaw binary for Alpine Linux (volume mounting)
#
#   make build              Build current arch → RELEASES/goclaw/$GOARCH/$VERSION/goclaw
#   make clean              Remove RELEASES/goclaw/
#   make image              Build image from Dockerfile
#
# Run from use/goclaw/ directory:
#   cd use/goclaw && make build
#
# Version is derived from the goclaw submodule git tag:
#   cd ../goclaw && git describe --tags --abbrev=0 --match "v[0-9]*"
#
# Output structure (at RELEASES/goclaw/):
#   goclaw/
#     v1.9.0/goclaw        ← binary
#     v1.9.0/goclaw.sha256 ← checksum
#     latest -> v1.9.0     ← symlink

SHELL := /bin/bash
GOCLAW_DIR := $(abspath $(CURDIR)/../../goclaw)
RELEASES_DIR := $(abspath $(CURDIR)/../../RELEASES/goclaw)

VERSION := $(shell cd $(GOCLAW_DIR) && git describe --tags --abbrev=0 --match "v[0-9]*" 2>/dev/null || echo dev)
LDFLAGS := -s -w -X github.com/nextlevelbuilder/goclaw/cmd.Version=$(VERSION)

GOOS := linux
GOARCH := $(shell go env GOARCH 2>/dev/null || echo amd64)

.PHONY: build clean image help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

# --------------------------------------------------------------------
# Build current host architecture
# --------------------------------------------------------------------

build: $(RELEASES_DIR)/$(VERSION)/goclaw $(RELEASES_DIR)/$(VERSION)/pkg-helper latest-link

$(RELEASES_DIR)/$(VERSION)/goclaw:
	@mkdir -p $(RELEASES_DIR)/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build -ldflags="$(LDFLAGS)" -o $(RELEASES_DIR)/$(VERSION)/goclaw .
	@cd $(RELEASES_DIR)/$(VERSION) && sha256sum goclaw > goclaw.sha256
	@echo "  VERSION  $(VERSION)"
	@echo "  ARCH     $(GOOS)/$(GOARCH)"
	@echo "  OUTPUT   $(RELEASES_DIR)/$(VERSION)/"
	@echo "Built: $(RELEASES_DIR)/$(VERSION)/goclaw"

$(RELEASES_DIR)/$(VERSION)/pkg-helper:
	@mkdir -p $(RELEASES_DIR)/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build -ldflags="-s -w" -o $(RELEASES_DIR)/$(VERSION)/pkg-helper ./cmd/pkg-helper
	@cd $(RELEASES_DIR)/$(VERSION) && sha256sum pkg-helper > pkg-helper.sha256
	@echo "Built: $(RELEASES_DIR)/$(VERSION)/pkg-helper"

# --------------------------------------------------------------------
# Symlink: RELEASES/goclaw/latest → RELEASES/goclaw/$VERSION
# --------------------------------------------------------------------

latest-link:
	@ln -sfn $(VERSION) $(RELEASES_DIR)/latest
	@echo "  latest → $(VERSION)"

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------

clean: ## Remove all versioned releases
	rm -rf $(RELEASES_DIR)
	@echo "Removed $(RELEASES_DIR)/"

# --------------------------------------------------------------------
# Image management
# --------------------------------------------------------------------

image: ## Build image from Dockerfile
	podman pull alpine:3.23
	podman build -t localhost/goclaw:current .
	podman tag localhost/goclaw:current localhost/goclaw:base
	@echo "Built: localhost/goclaw:current"