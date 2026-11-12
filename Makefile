# Command Line Tools ship the Swift Testing macros outside the default plugin path; full Xcode has no such directory and needs no flag.
TESTING_PLUGINS := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing
TESTING_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))
PREFIX ?= $(HOME)/.local

.PHONY: build test fingerprint install sheets
build:
	swift build -c release
	mkdir -p plugin/bin
	install -m 755 .build/release/elvis plugin/bin/elvis

test:
	swift test $(TESTING_FLAGS)

fingerprint:
	ELVIS_FINGERPRINT=1 swift test $(TESTING_FLAGS) --filter Fingerprint 2>&1 | grep -E "FINGERPRINT|error:|✘"

install: build
	mkdir -p $(PREFIX)/bin
	install -m 755 .build/release/elvis $(PREFIX)/bin/elvis

sheets: build
	.build/release/elvis sheets sheets
