# AURORA OS build and run entry points.
#
# `make iso` needs root (live-build creates a chroot). Everything else works
# as a normal user. All test images are disposable; nothing targets a host disk.

SHELL := /bin/sh
VERSION := $(shell cat VERSION)
BUILD_DIR ?= $(HOME)/aurora-build
ARTIFACTS := $(BUILD_DIR)/artifacts
ISO := $(ARTIFACTS)/aurora-os-$(VERSION)-amd64.iso

.PHONY: help check test-gate iso release verify boot clean

help:
	@echo "make check     static checks + auth-gate regression (no root, no build)"
	@echo "make test-gate run the production auth-gate regression tests only"
	@echo "make iso       build the TEST-profile ISO (scripts/build-iso.sh)"
	@echo "make release   build the release-profile ISO; gated before publish (root)"
	@echo "make verify    inspect the built ISO without booting it"
	@echo "make boot      boot the built ISO in QEMU (TCG, loopback VNC)"
	@echo "make clean     remove live-build work state via 'lb clean --purge'"

check:
	scripts/check.sh

test-gate:
	tests/test-auth-gate.sh

iso:
	scripts/build-iso.sh

release:
	scripts/build-release-iso.sh

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
