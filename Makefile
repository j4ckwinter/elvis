# Command Line Tools ship the Swift Testing macros outside the default plugin path; full Xcode has no such directory and needs no flag.
TESTING_PLUGINS := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing
TESTING_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))
PREFIX ?= $(HOME)/.local

.PHONY: build universal test fingerprint claude-check install restart sheets
build:
	swift build -c release
	mkdir -p plugin/bin
	install -m 755 .build/release/elvis plugin/bin/elvis

universal:
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p plugin/bin
	install -m 755 "$$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/elvis" plugin/bin/elvis
	codesign --force --sign - plugin/bin/elvis

test:
	swift test $(TESTING_FLAGS)

fingerprint:
	ELVIS_FINGERPRINT=1 swift test $(TESTING_FLAGS) --filter Fingerprint 2>&1 | grep -E "FINGERPRINT|error:|✘"

claude-check:
	scripts/claude-code-marks-git-work.sh

install: build
	mkdir -p $(PREFIX)/bin
	ln -sf "$(CURDIR)/plugin/bin/elvis" $(PREFIX)/bin/elvis

restart: build
	plugin/bin/elvis restart

sheets: build
	.build/release/elvis sheets sheets
