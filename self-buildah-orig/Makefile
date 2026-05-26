# Makefile for building GoClaw image with buildah (no daemon required)
# Usage: make [target]
#
# Container lifecycle:
#   ctr-create         Create container from alpine + base OS packages
#   ctr-files          Copy entrypoint and create directories
#   ctr-env            Set environment variables
#   ctr-cmd            Set entrypoint and command
#
# Optional layers:
#   ctr-python         Install Python runtime and packages
#   ctr-node           Install Node.js runtime and packages
#   ctr-bash           Install bash shell (optional)
#   ctr-execline      Install execline (optional, included in base)
#   ctr-office         Install office tools (pandoc, poppler-utils)
#   ctr-gh            Install GitHub CLI
#   ctr-buildah      Install buildah for self-upgrade (container builds its own layers)
#
# Build:
#   build              Full pipeline: base + python + node + commit (default)
#   build/partial      Resume from existing container (no ctr-create)
#
# Commit:
#   ctr-commit         Commit current state as :latest, remove container
#   ctr-commit-next   Commit current state, auto-increment :v1, :v2, ...
#   ctr-commit-bluegreen  Alternate between :blue and :green
#   ctr-commit-blue   Commit as :blue, keep container
#   ctr-commit-green  Commit as :green, keep container
#
# Cleanup:
#   ctr-rm             Remove intermediate container
#   rmi                Remove built images
#   prune              Clean up all buildah containers and cache
#
# Utilities:
#   help               Show this help message

IMAGE_NAME ?= ghcr.io/nextlevelbuilder/goclaw
IMAGE_TAG  ?= latest
IMAGE      := $(IMAGE_NAME):$(IMAGE_TAG)

CTR_NAME   := goclaw-build
CTR        := $(CTR_NAME)

SCRIPT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
GOCLAW_DIR ?= $(abspath $(SCRIPT_DIR)/../../..)
GOCLAW_BINARY := $(abspath $(GOCLAW_DIR)/goclaw)

.PHONY: \
	build-binary \
	ctr-create ctr-base ctr-files ctr-binary ctr-env ctr-cmd \
	ctr-python ctr-node ctr-bash ctr-office ctr-gh \
	build build/partial \
	ctr-commit ctr-commit-next ctr-commit-bluegreen ctr-commit-blue ctr-commit-green \
	ctr-rm rmi prune help

# =============================================================================
# Container lifecycle
# =============================================================================

ctr-create: ## Create container from alpine + base OS packages
	@echo "📦 Creating container from alpine:3.23..."
	buildah rm $(CTR) 2>/dev/null || true
	buildah from --name $(CTR) alpine:3.23
	@$(MAKE) --no-print-directory ctr-base
	@$(MAKE) --no-print-directory ctr-files
	@$(MAKE) --no-print-directory ctr-binary
	@$(MAKE) --no-print-directory ctr-env
	@$(MAKE) --no-print-directory ctr-cmd

ctr-base: ## Install base OS packages (apk)
	@echo "   → Updating apk cache..."
	buildah run $(CTR) -- apk update
	@echo "   → Installing base packages..."
	buildah run $(CTR) -- apk add --no-cache \
		ca-certificates wget su-exec \
		bash coreutils grep sed gawk tar gzip \
		execline

ctr-files: ## Copy entrypoint and create directories
	@echo "   → Copying entrypoint..."
	buildah copy $(CTR) $(SCRIPT_DIR)/entrypoint.sh /app/entrypoint.sh
	buildah run $(CTR) -- chmod +x /app/entrypoint.sh
	buildah run $(CTR) -- mkdir -p /app/workspace /app/data/.claude /app/skills /app/tsnet-state /app/.goclaw
	@echo "   → Copying build files..."
	buildah copy $(CTR) $(SCRIPT_DIR)/Makefile /app/Makefile
	buildah copy $(CTR) $(SCRIPT_DIR)/entrypoint.execline /app/entrypoint.execline
	buildah run $(CTR) -- chmod +x /app/entrypoint.execline /app/Makefile

ctr-binary: ## Copy goclaw binary into container
	@echo "   → Copying goclaw binary..."
	buildah copy $(CTR) $(GOCLAW_BINARY) /app/goclaw
	buildah run $(CTR) -- chmod +x /app/goclaw

ctr-env: ## Set environment variables
	@echo "   → Setting environment variables..."
	buildah config --env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
		--env GOCLAW_CONFIG=/app/config.json \
		--env GOCLAW_WORKSPACE=/app/workspace \
		--env GOCLAW_DATA_DIR=/app/data \
		--env GOCLAW_SKILLS_DIR=/app/skills \
		--env GOCLAW_MIGRATIONS_DIR=/app/migrations \
		--env GOCLAW_HOST=0.0.0.0 \
		--env GOCLAW_PORT=18790 $(CTR)
ctr-cmd: ## Set entrypoint and command
	@echo "   → Setting entrypoint and command..."
	buildah config --entrypoint '["/app/entrypoint.sh"]' $(CTR)
	buildah config --cmd '["serve"]' $(CTR)

# =============================================================================
# Optional layers
# =============================================================================

ctr-python: ## Install Python runtime and packages
	@echo "   → Installing Python runtime..."
	buildah run $(CTR) -- apk add --no-cache python3 py3-pip
	buildah run $(CTR) -- mkdir -p /app/data/.runtime/pip /app/data/.runtime/pip-cache
	@echo "   → Installing Python packages..."
	buildah copy $(CTR) $(GOCLAW_DIR)/docker/requirements-base.txt /tmp/requirements-base.txt
	buildah run $(CTR) -- pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements-base.txt
	buildah run $(CTR) -- rm -f /tmp/requirements-base.txt
	@echo "   → Setting Python env vars..."
	buildah config --env "PATH=/app/data/.runtime/npm-global/bin:/app/data/.runtime/pip/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
		--env PYTHONPATH=/app/data/.runtime/pip \
		--env PIP_TARGET=/app/data/.runtime/pip \
		--env PIP_BREAK_SYSTEM_PACKAGES=1 \
		--env PIP_CACHE_DIR=/app/data/.runtime/pip-cache $(CTR)

ctr-node: ## Install Node.js runtime and packages
	@echo "   → Installing Node.js runtime..."
	buildah run $(CTR) -- apk add --no-cache nodejs npm
	buildah run $(CTR) -- mkdir -p /app/data/.runtime/npm-global/lib /app/data/.runtime/pip-cache
	@echo "   → Installing Node.js packages..."
	buildah run $(CTR) -- npm install -g docx@^9.6.1 pptxgenjs@^4.0.1
	@echo "   → Setting Node.js env vars..."
	buildah config --env "PATH=/app/data/.runtime/npm-global/bin:/app/data/.runtime/pip/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
		--env NPM_CONFIG_PREFIX=/app/data/.runtime/npm-global \
		--env NODE_PATH=/usr/local/lib/node_modules:/app/data/.runtime/npm-global/lib/node_modules $(CTR)

ctr-bash: ## Install bash shell
	@echo "   → Installing bash..."
	buildah run $(CTR) -- apk add --no-cache bash

ctr-office: ## Install office tools (pandoc, poppler-utils)
	@echo "   → Installing office tools..."
	buildah run $(CTR) -- apk add --no-cache pandoc poppler-utils

ctr-gh: ## Install GitHub CLI
	@echo "   → Installing GitHub CLI..."
	buildah run $(CTR) -- apk add --no-cache github-cli

ctr-buildah: ## Install buildah for self-upgrade (container builds its own layers)
	@echo "   → Installing buildah..."
	buildah run $(CTR) -- apk add --no-cache buildah fuse-overlayfs

# =============================================================================
# Build targets
# =============================================================================

build-binary: ## Build goclaw binary locally (static, for container)
	@echo "🔨 Building goclaw binary..."
	cd $(GOCLAW_DIR) && \
		CGO_ENABLED=0 GOOS=linux go build \
		-ldflags="-s -w -X github.com/nextlevelbuilder/goclaw/cmd.Version=$$(git describe --tags 2>/dev/null || echo 'dev')" \
		$(if $(TAGS),-tags $(TAGS)) \
		-o $(GOCLAW_BINARY) .
	@echo "✅ Binary: $(GOCLAW_BINARY)"

build: ctr-create ctr-python ctr-node ctr-office ctr-gh ctr-buildah ctr-commit ## Build full GoClaw image

# =============================================================================
# Commit targets
# =============================================================================

# Version counter for blue-green deployments
VERSION_FILE := $(CTR_NAME).version
VERSION := $(shell if [ -f $(VERSION_FILE) ]; then \
	cat $(VERSION_FILE); \
else \
	echo 0; \
fi)
NEXT_VERSION := $(shell echo $$(($(VERSION) + 1)))

ctr-commit-next: ## Commit current state, increment version tag, keep container
	@echo "📤 Committing :v$(NEXT_VERSION)..."
	buildah commit $(CTR) $(IMAGE_NAME):v$(NEXT_VERSION)
	@echo $(NEXT_VERSION) > $(VERSION_FILE)
	@echo "✅ Image: $(IMAGE_NAME):v$(NEXT_VERSION)"
	@echo "   Next commit will be :v$$(($(NEXT_VERSION) + 1))"

ctr-commit-blue: ## Commit as :blue, keep container
	@echo "📤 Committing :blue..."
	buildah commit $(CTR) $(IMAGE_NAME):blue
	@echo "✅ Image: $(IMAGE_NAME):blue"

ctr-commit-green: ## Commit as :green, keep container
	@echo "📤 Committing :green..."
	buildah commit $(CTR) $(IMAGE_NAME):green
	@echo "✅ Image: $(IMAGE_NAME):green"

ctr-commit-bluegreen: ## Alternate blue/green commit, keep container
	@COLOR=$$(if [ -f $(CTR_NAME).bluegreen ]; then \
		cat $(CTR_NAME).bluegreen; \
		else echo blue; \
		fi); \
	echo "📤 Committing :$$COLOR..."; \
	buildah commit $(CTR) $(IMAGE_NAME):$$COLOR; \
	if [ "$$COLOR" = blue ]; then \
		echo green > $(CTR_NAME).bluegreen; \
	else \
		echo blue > $(CTR_NAME).bluegreen; \
	fi; \
	echo "✅ Image: $(IMAGE_NAME):$$COLOR"

ctr-commit: ## Commit as :latest, remove container
	@echo "📤 Committing :latest..."
	buildah commit $(CTR) $(IMAGE)
	buildah rm $(CTR) 2>/dev/null || true
	@echo "✅ Build complete: $(IMAGE)"

ctr-rm: ## Remove intermediate container
	@buildah rm $(CTR) 2>/dev/null || true

# =============================================================================
# Cleanup targets
# =============================================================================

rmi: ## Remove all built images
	@buildah rmi $(IMAGE_NAME):latest $(shell buildah images -n --format '{{.names}}' 2>/dev/null | grep -E '^$(IMAGE_NAME):' | tr '\n' ' ') 2>/dev/null || true
	@rm -f $(VERSION_FILE) $(CTR_NAME).bluegreen
	@echo "Removed all images"

prune: ## Clean up all buildah containers and cache
	@buildah prune -a -f && echo "Pruned all buildah cache"

# =============================================================================
# Utilities
# =============================================================================

help: ## Show this help message
	@echo "GoClaw buildah build targets"
	@echo ""
	@echo "Container lifecycle:"
	@echo "  ctr-create         Create container (alpine + base packages)"
	@echo "  ctr-files          Copy entrypoint and create directories"
	@echo "  ctr-env            Set environment variables"
	@echo "  ctr-cmd            Set entrypoint and command"
	@echo ""
	@echo "Optional layers:"
	@echo "  ctr-python         Install Python runtime and packages"
	@echo "  ctr-node           Install Node.js runtime and packages"
	@echo "  ctr-bash           Install bash shell (optional)"
	@echo "  ctr-office         Install office tools (pandoc, poppler-utils)"
	@echo "  ctr-gh            Install GitHub CLI"
	@echo "  ctr-buildah      Install buildah for self-upgrade"
	@echo ""
	@echo "Build:"
	@echo "  build              Full pipeline: base + python + node + office + gh + buildah + :latest"
	@echo "  build-binary       Build goclaw binary locally (static, for container)"
	@echo "  build/partial      Resume from existing container"
	@echo ""
	@echo "Binary update (no layer rebuild):"
	@echo "  make ctr-binary ctr-commit-blue   # update binary, keep container"
	@echo ""
	@echo "Commit:"
	@echo "  ctr-commit          Commit current state as :latest, remove container"
	@echo "  ctr-commit-next     Commit current state, increment :v1, :v2, ..."
	@echo "  ctr-commit-bluegreen  Alternate between :blue and :green"
	@echo "  ctr-commit-blue    Commit as :blue, keep container"
	@echo "  ctr-commit-green   Commit as :green, keep container"
	@echo ""
	@echo "Cleanup:"
	@echo "  ctr-rm             Remove intermediate container"
	@echo "  rmi                Remove all built images"
	@echo "  prune              Clean up all buildah containers and cache"
