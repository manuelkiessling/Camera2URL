SHELL := /bin/bash

APP_SCHEME ?= camera2url
UITEST_SCHEME ?= camera2urlUITests
CONFIG ?= Debug
DEST ?= platform=iOS Simulator,name=iPhone 17
XCODE_FLAGS ?= CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

.PHONY: help build test ui-test clean quality

help:
	@echo "camera2url build tooling"
	@echo
	@echo "Targets:"
	@echo "  make build     # Build $(APP_SCHEME) ($(CONFIG))"
	@echo "  make test      # Build + run unit tests"
	@echo "  make ui-test   # Build + run UI tests"
	@echo "  make clean     # Clean derived data"
	@echo "  make quality   # Build + unit test in sequence"
	@echo
	@echo "Override CONFIG or DEST when needed, e.g. DEST=\"platform=iOS Simulator,name=iPhone 15\"."

build:
	xcodebuild -project camera2url.xcodeproj \
		-scheme $(APP_SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DEST)' \
		$(XCODE_FLAGS) \
		build

test:
	xcodebuild -project camera2url.xcodeproj \
		-scheme $(APP_SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DEST)' \
		$(XCODE_FLAGS) \
		test

ui-test:
	xcodebuild -project camera2url.xcodeproj \
		-scheme $(UITEST_SCHEME) \
		-configuration $(CONFIG) \
		-destination '$(DEST)' \
		$(XCODE_FLAGS) \
		test

clean:
	xcodebuild -project camera2url.xcodeproj \
		-scheme $(APP_SCHEME) \
		-configuration $(CONFIG) \
		clean
	rm -rf build/

quality: build test
