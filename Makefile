# Command Line Tools ship the Swift Testing macros outside the default plugin path.
TESTING_PLUGINS := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing
PREFIX ?= $(HOME)/.local

.PHONY: build test install sheets
build:
	swift build -c release
	mkdir -p plugin/bin
	install -m 755 .build/release/elvis plugin/bin/elvis

test:
	swift test -Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS)

install: build
	mkdir -p $(PREFIX)/bin
	install -m 755 .build/release/elvis $(PREFIX)/bin/elvis

sheets: build
	.build/release/elvis sheets sheets
