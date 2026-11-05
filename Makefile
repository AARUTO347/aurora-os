# AURORA OS build and run entry points.
#
# `make iso` needs root (live-build creates a chroot). Everything else works
# as a normal user. All test images are disposable; nothing targets a host disk.

SHELL := /bin/sh
VERSION := $(shell cat VERSION)
BUILD_DIR ?= $(HOME)/aurora-build
ARTIFACTS := $(BUILD_DIR)/artifacts
ISO := $(ARTIFACTS)/aurora-os-$(VERSION)-amd64.iso

.PHONY: help check iso verify boot clean

help:
	@echo "make check    static checks (no root, no build)"
	@echo "make iso      build artifacts/aurora-os-$(VERSION)-amd64.iso"
	@echo "make verify   inspect the built ISO without booting it"
	@echo "make boot     boot the built ISO in QEMU (TCG, loopback VNC)"
	@echo "make clean    remove live-build work state via 'lb clean --purge'"

check:
	scripts/check.sh

iso:
	scripts/build-iso.sh

verify: $(ISO)
	scripts/verify-iso.sh $(ISO)

boot: $(ISO)
	scripts/run-qemu.sh $(ISO)

clean:
	@if [ -d "$(BUILD_DIR)/work" ]; then \
		cd "$(BUILD_DIR)/work" && lb clean --purge; \
	else \
		echo "no build work directory at $(BUILD_DIR)/work"; \
	fi
