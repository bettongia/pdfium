.DEFAULT_GOAL := default

include build_targets.mk
include site.mk

# BEGIN: Primary tasks

default: prepare license_check format analyze coverage doc_site
.PHONY: default

pre_commit: format_check analyze license_check test
.PHONY: pre_commit

cicd: prepare format_check analyze license_check test doc_site
.PHONY: cicd

# END: Primary tasks

format:
	dart format .
.PHONY: format

format_check:
	dart format --output=none --set-exit-if-changed lib/ test/ example/ hook/
.PHONY: format_check

analyze:
	dart analyze
.PHONY: analyze

checks: coverage.log license_check
.PHONY: checks

test:
	dart test
.PHONY: test

license_check:
	cat addlicense_config.txt | xargs addlicense --check

license_add:
	cat addlicense_config.txt | xargs addlicense

coverage: coverage.log
.PHONY: coverage

coverage.log: lib/** test/**
	dart test --coverage-path=coverage/lcov.info
	# Exclude auto-generated FFI bindings from the coverage report.
	# The generated file exposes the full PDFium surface, most of which the
	# library intentionally does not exercise. Measuring it would inflate the
	# denominator and give a misleading coverage percentage. The exclusion is
	# applied to the raw lcov.info before genhtml runs.
	lcov --remove coverage/lcov.info '*/generated/*' -o coverage/lcov.info
	rm -rf site/coverage
	mkdir -p site/coverage
	genhtml coverage/lcov.info -o site/coverage

prepare:
	dart pub global activate coverage
	dart pub get
	@scripts/check_pdfium_version.sh || echo "  → Run 'make fetch_pdfium' before running tests."
.PHONY: prepare_dart

purge: clean
	rm -rf .dart_tool
	rm -rf third_party
	$(MAKE) prepare

clean:
	rm -rf site dist coverage doc
	rm -f *.log

.PHONY: clean

# ---------------------------------------------------------------------------
# Mobile integration test targets
# ---------------------------------------------------------------------------

BETTO_ITA := integration_test_app

export EMULATOR_IOS ?= ios-emulator
export EMULATOR_IOS_DEVICE ?= iPhone\ 17
export EMULATOR_IOS_RUNTIME ?= iOS26.5

# Android emulator device ID — typically emulator-5554 when one emulator is
# running. arm64-v8a is the default ABI on Apple Silicon Macs (native speed);
# x86_64 emulators can be used but run under translation.
export ADB_BINARY_PATH ?= ~/Library/Android/sdk/platform-tools
export EMULATOR_ANDROID ?= android-emulator
export EMULATOR_ANDROID_DEVICE ?= pixel_9
export EMULATOR_ANDROID_ABI ?= arm64-v8a

# sync_fixtures: copy test/fixtures/ and test/data/ into
# integration_test_app/assets/ so the on-device suite has the same PDFs as
# the desktop suite. Run this before a mobile test run to keep fixtures in sync.
sync_fixtures:
	rsync -a --delete test/fixtures/ $(BETTO_ITA)/assets/fixtures/
	rsync -a --delete test/data/ $(BETTO_ITA)/assets/data/
.PHONY: sync_fixtures

# fetch_mobile_binaries: download the iOS xcframework and Android .so files
# from the GitHub Release identified in version_pdfium.json.
fetch_mobile_binaries:
	$(BETTO_ITA)/scripts/fetch_mobile_binaries.sh
.PHONY: fetch_mobile_binaries

# ios_test: run the integration test suite on the configured iOS simulator.
# Boots the simulator if not already booted, then runs flutter test.
ios_test: sync_fixtures fetch_mobile_binaries
	cd $(BETTO_ITA) && flutter pub get
	xcrun simctl list | grep "$(EMULATOR_IOS)" | grep -q "Booted" || xcrun simctl boot $(EMULATOR_IOS)
	open -a Simulator
	cd $(BETTO_ITA) && flutter test integration_test/ --device-id $(EMULATOR_IOS)
.PHONY: ios_test

# android_test: run the integration test suite on the configured Android emulator.
# Launches the emulator and waits for device, then runs flutter test.
android_test: sync_fixtures fetch_mobile_binaries
	cd $(BETTO_ITA) && flutter pub get
	flutter emulators --launch $(EMULATOR_ANDROID) || true
	$(ADB_BINARY_PATH)/adb wait-for-device
	cd $(BETTO_ITA) && flutter test integration_test/ --device-id emulator-5554
.PHONY: android_test

# Emulator lifecycle targets.
emulator_ios_create:
	xcrun simctl create $(EMULATOR_IOS) $(EMULATOR_IOS_DEVICE) $(EMULATOR_IOS_RUNTIME)
.PHONY: emulator_ios_create

emulator_android_create:
	avdmanager create avd --name $(EMULATOR_ANDROID_DEVICE) --package "system-images;android-35;google_apis;$(EMULATOR_ANDROID_ABI)" --device "pixel_9" --force
.PHONY: emulator_android_create

emulators_stop: emulators_stop_android emulators_stop_ios
.PHONY: emulators_stop

emulators_stop_ios:
	xcrun simctl shutdown $(EMULATOR_IOS) || true
.PHONY: emulators_stop_ios

emulators_stop_android:
	$(ADB_BINARY_PATH)/adb emu kill || true
.PHONY: emulators_stop_android
