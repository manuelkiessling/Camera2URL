SHELL := /bin/bash

APP_TARGET ?= camera2url_ios
TEST_TARGET ?= camera2url_iosTests
UITEST_TARGET ?= camera2url_iosUITests
CONFIG ?= Debug
XCODE_FLAGS ?= CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

.PHONY: help build test ui-test clean quality

help:
	@echo "camera2url_ios build tooling"
	@echo
	@echo "Targets:"
	@echo "  make build     # Build $(APP_TARGET) ($(CONFIG))"
	@echo "  make test      # Build + run unit tests"
	@echo "  make ui-test   # Build + run UI tests"
	@echo "  make clean     # Clean derived data"
	@echo "  make quality   # Build + unit test in sequence"
	@echo
	@echo "Override CONFIG when needed, e.g. CONFIG=Release."

build:
	xcodebuild -project camera2url_ios.xcodeproj \
		-target $(APP_TARGET) \
		-configuration $(CONFIG) \
		-sdk iphonesimulator \
		$(XCODE_FLAGS) \
		build

test:
	xcodebuild -project camera2url_ios.xcodeproj \
		-target $(APP_TARGET) \
		-target $(TEST_TARGET) \
		-configuration Debug \
		-sdk iphonesimulator \
		$(XCODE_FLAGS) \
		build
	@echo "Tests built successfully. Run in Xcode or simulator for execution."

ui-test:
	xcodebuild -project camera2url_ios.xcodeproj \
		-target $(APP_TARGET) \
		-target $(UITEST_TARGET) \
		-configuration Debug \
		-sdk iphonesimulator \
		$(XCODE_FLAGS) \
		build
	@echo "UI Tests built successfully. Run in Xcode or simulator for execution."

clean:
	xcodebuild -project camera2url_ios.xcodeproj \
		-target $(APP_TARGET) \
		-configuration $(CONFIG) \
		clean
	rm -rf build/

quality: build test
