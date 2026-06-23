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
# Build tags are read from GOCLAW_BUILD_TAGS in ../../.env (e.g. to
# enable the redis cache, set GOCLAW_BUILD_TAGS=embedui,otel,tsnet,redis).
# Override on the command line: make build GOCLAW_BUILD_TAGS=...
#
# Output structure (at RELEASES/goclaw/):
#   goclaw/
#     v1.9.0/goclaw        ← binary
#     v1.9.0/goclaw.sha256 ← checksum
#     latest -> v1.9.0     ← symlink

SHELL := /bin/bash
GOCLAW_DIR := $(abspath $(CURDIR)/../../goclaw)
RELEASES_DIR := $(abspath $(CURDIR)/../../RELEASES/goclaw)
PROJECT_ROOT := $(abspath $(CURDIR)/../..)
GOCLAW_USE_BRANCH ?= main

# Build tags are read from .env at the project root. To enable optional
# features (e.g. redis), set GOCLAW_BUILD_TAGS in .env and rebuild.
# Pass GOCLAW_BUILD_TAGS on the make command line to override.
ifneq (,$(wildcard $(PROJECT_ROOT)/.env))
include $(PROJECT_ROOT)/.env
endif
export GOCLAW_BUILD_TAGS

VERSION := $(shell cd $(GOCLAW_DIR) && git describe --tags --abbrev=0 --match "v[0-9]*" 2>/dev/null || echo dev)
LDFLAGS := -s -w -X github.com/nextlevelbuilder/goclaw/cmd.Version=$(VERSION)
TAGS_FLAG := $(if $(GOCLAW_BUILD_TAGS),-tags $(GOCLAW_BUILD_TAGS),)

GOOS := linux
GOARCH := $(shell go env GOARCH 2>/dev/null || echo amd64)

.PHONY: build clean image help checkout-branch sync-upstream

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

# --------------------------------------------------------------------
# Build current host architecture
# --------------------------------------------------------------------

build: $(RELEASES_DIR)/$(VERSION)/goclaw $(RELEASES_DIR)/$(VERSION)/pkg-helper latest-link ## Build goclaw + pkg-helper binaries

checkout-branch:
	@if [ -n "$$(cd $(GOCLAW_DIR) && git status --porcelain)" ]; then \
		echo "ERROR: $(GOCLAW_DIR) has uncommitted changes." >&2; \
		echo "Commit or stash them before building." >&2; \
		exit 1; \
	fi
	@echo "Checking out $(GOCLAW_USE_BRANCH) in $(GOCLAW_DIR)"
	@cd $(GOCLAW_DIR) && git checkout $(GOCLAW_USE_BRANCH) && git pull --ff-only

# --------------------------------------------------------------------
# Sync local branch in $(GOCLAW_DIR) with upstream
# --------------------------------------------------------------------

sync-upstream: ## Fast-forward local branch to upstream/<branch>
	@if [ -n "$$(cd $(GOCLAW_DIR) && git status --porcelain)" ]; then \
		echo "ERROR: $(GOCLAW_DIR) has uncommitted changes." >&2; \
		echo "Commit or stash them before syncing." >&2; \
		exit 1; \
	fi
	@echo "Fetching upstream in $(GOCLAW_DIR)"
	@cd $(GOCLAW_DIR) && git fetch upstream
	@echo "Fast-forwarding $(GOCLAW_USE_BRANCH) to upstream/$(GOCLAW_USE_BRANCH)"
	@cd $(GOCLAW_DIR) && git checkout $(GOCLAW_USE_BRANCH)
	@cd $(GOCLAW_DIR) && git merge --ff-only upstream/$(GOCLAW_USE_BRANCH)

$(RELEASES_DIR)/$(VERSION)/goclaw:
	@mkdir -p $(RELEASES_DIR)/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build $(TAGS_FLAG) -ldflags="$(LDFLAGS)" -o $(RELEASES_DIR)/$(VERSION)/goclaw .
	@cd $(RELEASES_DIR)/$(VERSION) && sha256sum goclaw > goclaw.sha256
	@echo "  VERSION  $(VERSION)"
	@echo "  TAGS     $(GOCLAW_BUILD_TAGS)"
	@echo "  ARCH     $(GOOS)/$(GOARCH)"
	@echo "  OUTPUT   $(RELEASES_DIR)/$(VERSION)/"
	@echo "Built: $(RELEASES_DIR)/$(VERSION)/goclaw"

$(RELEASES_DIR)/$(VERSION)/pkg-helper:
	@mkdir -p $(RELEASES_DIR)/$(VERSION)
	cd $(GOCLAW_DIR) && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build $(TAGS_FLAG) -ldflags="-s -w" -o $(RELEASES_DIR)/$(VERSION)/pkg-helper ./cmd/pkg-helper
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
	podman build -t localhost/goclaw:current .
	podman tag localhost/goclaw:current localhost/goclaw:base
	@echo "Built: localhost/goclaw:current"