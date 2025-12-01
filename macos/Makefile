SHELL := /bin/bash

APP_SCHEME ?= camera2url
UITEST_SCHEME ?= camera2urlUITests
CONFIG ?= Debug
DEST ?= platform=macOS,arch=arm64
XCODE_FLAGS ?=

.PHONY: help build test ui-test clean quality

help:
	@echo "camera2url build tooling"
	@echo
	@echo "Targets:"
	@echo "  make build     # Build $(APP_SCHEME) ($(CONFIG), $(DEST))"
	@echo "  make test      # Build + run unit tests for $(APP_SCHEME)"
	@echo "  make ui-test   # Build + run UI tests ($(UITEST_SCHEME))"
	@echo "  make clean     # Clean derived data for $(APP_SCHEME)"
	@echo "  make quality   # Build + unit test in sequence"
	@echo
	@echo "Override CONFIG or DEST when needed, e.g. DEST=\"platform=macOS\"."

build:
	xcodebuild -scheme $(APP_SCHEME) -configuration $(CONFIG) build -destination '$(DEST)' $(XCODE_FLAGS)

test:
	xcodebuild -scheme $(APP_SCHEME) -configuration $(CONFIG) test -destination '$(DEST)' $(XCODE_FLAGS)

ui-test:
	xcodebuild -scheme $(UITEST_SCHEME) -configuration $(CONFIG) test -destination '$(DEST)' $(XCODE_FLAGS)

clean:
	xcodebuild -scheme $(APP_SCHEME) -configuration $(CONFIG) clean

quality: build test

