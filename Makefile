# Root Makefile — monorepo compositor.
# Composes per-package .mk fragments and owns cross-package targets.
# Per-package targets (dart, test, doc, license, etc.) are defined in:
#   packages/betto_pdfium/betto_pdfium.mk
#   packages/betto_pdfium_ios/betto_pdfium_ios.mk

.DEFAULT_GOAL := default

include site.mk
include packages/betto_pdfium/betto_pdfium.mk
include packages/betto_pdfium_ios/betto_pdfium_ios.mk

export EMULATOR_IOS ?= ios-emulator
export EMULATOR_IOS_DEVICE ?= iPhone\ 17
export EMULATOR_IOS_RUNTIME ?= iOS26.5

export ADB_BINARY_PATH ?= ~/Library/Android/sdk/platform-tools
export EMULATOR_ANDROID ?= android-emulator
export EMULATOR_ANDROID_DEVICE ?= pixel_9
export EMULATOR_ANDROID_ABI ?= arm64-v8a

# ---------------------------------------------------------------------------
# Cross-package targets
# ---------------------------------------------------------------------------

default: prepare license_check license_check_ios format analyze analyze_ios test coverage doc_site
.PHONY: default

cicd: prepare format_check analyze analyze_ios license_check license_check_ios test doc_site
.PHONY: cicd

pre_commit: format_check analyze analyze_ios license_check license_check_ios test
.PHONY: pre_commit

clean: clean_dart clean_ios
	cd $(BETTO_ITA) && flutter clean
	rm -rf site
.PHONY: clean

purge: clean
	rm -rf $(BETTO_PKG)/.dart_tool
	rm -rf $(BETTO_PKG)/third_party
	$(MAKE) prepare
.PHONY: purge

# ---------------------------------------------------------------------------
# Emulator lifecycle targets
# ---------------------------------------------------------------------------

emulators_stop: emulators_stop_android emulators_stop_ios
.PHONY: emulators_stop

emulators_stop_ios:
	xcrun simctl shutdown $(EMULATOR_IOS) || true
.PHONY: emulators_stop_ios

emulator_ios_create:
	xcrun simctl create $(EMULATOR_IOS) $(EMULATOR_IOS_DEVICE) $(EMULATOR_IOS_RUNTIME)
.PHONY: emulator_ios_create

emulators_stop_android:
	$(ADB_BINARY_PATH)/adb emu kill || true
.PHONY: emulators_stop_android

emulator_android_create:
	avdmanager create avd --name $(EMULATOR_ANDROID_DEVICE) --package "system-images;android-35;google_apis;$(EMULATOR_ANDROID_ABI)" --device "pixel_9" --force
.PHONY: emulator_android_create
