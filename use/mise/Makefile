# use/mise/Makefile — fetch and stage mise binaries for the goclaw stack.
#
# Fetches upstream prebuilt mise binaries (musl for Alpine, glibc for
# Debian/RHEL) from jdx/mise's GitHub releases, verifies the SHA256,
# and stages them under /srv/auto_mise-{musl,glibc}/_data/RELEASES/mise/<v>/<arch>/
# so the goclaw container's add-mise shim can copy them out to /bin/mise.
#
# Targets:
#   make fetch-musl  VERSION=2026.6.13 ARCH=aarch64
#   make fetch-glibc VERSION=2026.6.13 ARCH=aarch64
#   make stage-musl  VERSION=2026.6.13 ARCH=aarch64
#   make stage-glibc VERSION=2026.6.13 ARCH=aarch64
#   make latest                            - update 'latest' symlinks in both volumes
#   make all                               - fetch + stage + latest (default)
#   make clean                             - remove local build artifacts
#
# Bump MISE_VERSION in versions.env, then re-run `make all`.

# ---- Configuration ----
WORK_DIR    := $(abspath $(CURDIR))
BUILD_DIR   := $(WORK_DIR)/build
include $(WORK_DIR)/versions.env

ARCH        ?= aarch64
UPSTREAM_ARCH := arm64
MISE_REPO   := https://github.com/jdx/mise/releases
VERSION     ?= $(MISE_VERSION)

# Volume mount roots (set by zfs/+zfs.yml or the host's mise setup)
MUSL_VOLUME  := /srv/auto_mise-musl
GLIBC_VOLUME := /srv/auto_mise-glibc

# Note: mise 2026.6.x is statically linked (both musl and glibc variants)
# so no separate lua lib staging is needed. Older versions (< 2024) needed
# a side-staged liblua.so.5 for musl Alpine; this is no longer required.

# ---- URL templates ----
# Upstream mise release tarball names. Glibc is the plain "linux-<arch>";
# musl has the "-musl" suffix. Both come from the same upstream release.
# Upstream uses "arm64" in the URL; we use "aarch64" for the staging path
# to match the existing /srv/auto_mise-*/_data/RELEASES/mise/.../aarch64/
# layout and the add-mise shim's MISE_SRC hardcoded path.
MUSL_TARBALL  := mise-v$(VERSION)-linux-$(UPSTREAM_ARCH)-musl.tar.gz
GLIBC_TARBALL := mise-v$(VERSION)-linux-$(UPSTREAM_ARCH).tar.gz
MUSL_URL      := $(MISE_REPO)/download/v$(VERSION)/$(MUSL_TARBALL)
GLIBC_URL     := $(MISE_REPO)/download/v$(VERSION)/$(GLIBC_TARBALL)
SHASUMS_URL   := $(MISE_REPO)/download/v$(VERSION)/SHASUMS256.txt

# ---- Targets ----

.PHONY: all fetch-musl fetch-glibc stage-musl stage-glibc latest clean help verify-musl verify-glibc

all: fetch-musl fetch-glibc stage-musl stage-glibc latest ## Fetch, verify, stage, and link both targets

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

# (All other targets below)

# ---- Fetch (download upstream prebuilts) ----

fetch-musl: ## Download musl prebuilt from upstream
	@mkdir -p $(BUILD_DIR)
	@echo "  → $(MUSL_TARBALL)"
	curl -fsSL -o $(BUILD_DIR)/$(MUSL_TARBALL) $(MUSL_URL)
	@echo "  → SHASUMS256.txt"
	curl -fsSL -o $(BUILD_DIR)/SHASUMS256.txt $(SHASUMS_URL)
	$(MAKE) verify-musl
	@echo "  → extracting mise/bin/mise"
	rm -rf $(BUILD_DIR)/mise-musl
	mkdir -p $(BUILD_DIR)/mise-musl
	tar -xzf $(BUILD_DIR)/$(MUSL_TARBALL) -C $(BUILD_DIR)/mise-musl --strip-components=1
	@ls -la $(BUILD_DIR)/mise-musl/bin/mise

fetch-glibc: ## Download glibc prebuilt from upstream
	@mkdir -p $(BUILD_DIR)
	@echo "  → $(GLIBC_TARBALL)"
	curl -fsSL -o $(BUILD_DIR)/$(GLIBC_TARBALL) $(GLIBC_URL)
	@echo "  → SHASUMS256.txt"
	curl -fsSL -o $(BUILD_DIR)/SHASUMS256.txt $(SHASUMS_URL)
	$(MAKE) verify-glibc
	@echo "  → extracting mise/bin/mise"
	rm -rf $(BUILD_DIR)/mise-glibc
	mkdir -p $(BUILD_DIR)/mise-glibc
	tar -xzf $(BUILD_DIR)/$(GLIBC_TARBALL) -C $(BUILD_DIR)/mise-glibc --strip-components=1
	@ls -la $(BUILD_DIR)/mise-glibc/bin/mise

# ---- Verify (SHA256 against upstream's SHASUMS256.txt) ----

verify-musl: ## Verify musl tarball SHA256
	@cd $(BUILD_DIR) && \
		expected=$$(grep -F "./$(MUSL_TARBALL)" SHASUMS256.txt | awk '{print $$1}') && \
		actual=$$(sha256sum $(MUSL_TARBALL) | awk '{print $$1}') && \
		if [ "$$expected" != "$$actual" ]; then \
			echo "  SHA256 mismatch for $(MUSL_TARBALL)" >&2; \
			echo "    expected: $$expected" >&2; \
			echo "    actual:   $$actual" >&2; \
			exit 1; \
		fi && \
		echo "  ✓ SHA256 OK: $(MUSL_TARBALL)"

verify-glibc: ## Verify glibc tarball SHA256
	@cd $(BUILD_DIR) && \
		expected=$$(grep -F "./$(GLIBC_TARBALL)" SHASUMS256.txt | awk '{print $$1}') && \
		actual=$$(sha256sum $(GLIBC_TARBALL) | awk '{print $$1}') && \
		if [ "$$expected" != "$$actual" ]; then \
			echo "  SHA256 mismatch for $(GLIBC_TARBALL)" >&2; \
			echo "    expected: $$expected" >&2; \
			echo "    actual:   $$actual" >&2; \
			exit 1; \
		fi && \
		echo "  ✓ SHA256 OK: $(GLIBC_TARBALL)"

# ---- Stage (copy to /srv/auto_mise-<libc>/_data/RELEASES/mise/<v>/<arch>/) ----

stage-musl: ## Stage musl binary to /srv/auto_mise-musl/
	@echo "  → $(MUSL_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)/mise"
	install -d -m 0755 $(MUSL_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)
	install -m 0755 $(BUILD_DIR)/mise-musl/bin/mise $(MUSL_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)/mise

stage-glibc: ## Stage glibc binary to /srv/auto_mise-glibc/
	@echo "  → $(GLIBC_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)/mise"
	install -d -m 0755 $(GLIBC_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)
	install -m 0755 $(BUILD_DIR)/mise-glibc/bin/mise $(GLIBC_VOLUME)/_data/RELEASES/mise/$(VERSION)/$(ARCH)/mise

# ---- Latest symlinks ----
# 1. RELEASES/mise/latest → <VERSION>  (so the shim can walk via the
#    versioned directory tree)
# 2. bin/mise → ../RELEASES/mise/latest/aarch64/mise  (so /usr/share/mise/bin/
#    is a real binary on PATH, no shim copy needed; the add-mise shim
#    is a one-line passthrough to this)

latest: ## Update 'latest' symlinks and bin/mise pointer in both volumes
	@echo "  → $(MUSL_VOLUME)/_data/RELEASES/mise/latest → $(VERSION)"
	ln -sfn $(VERSION) $(MUSL_VOLUME)/_data/RELEASES/mise/latest
	@echo "  → $(MUSL_VOLUME)/_data/bin/mise → ../RELEASES/mise/latest/$(ARCH)/mise"
	install -d -m 0755 $(MUSL_VOLUME)/_data/bin
	ln -sfn ../RELEASES/mise/latest/$(ARCH)/mise $(MUSL_VOLUME)/_data/bin/mise
	@echo "  → $(GLIBC_VOLUME)/_data/RELEASES/mise/latest → $(VERSION)"
	ln -sfn $(VERSION) $(GLIBC_VOLUME)/_data/RELEASES/mise/latest
	@echo "  → $(GLIBC_VOLUME)/_data/bin/mise → ../RELEASES/mise/latest/$(ARCH)/mise"
	install -d -m 0755 $(GLIBC_VOLUME)/_data/bin
	ln -sfn ../RELEASES/mise/latest/$(ARCH)/mise $(GLIBC_VOLUME)/_data/bin/mise
	@ls -la $(MUSL_VOLUME)/_data/bin/mise $(GLIBC_VOLUME)/_data/bin/mise \
		$(MUSL_VOLUME)/_data/RELEASES/mise/latest $(GLIBC_VOLUME)/_data/RELEASES/mise/latest

# ---- Cleanup ----

clean: ## Remove local build artifacts
	rm -rf $(BUILD_DIR)
