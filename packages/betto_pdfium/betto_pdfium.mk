# betto_pdfium.mk — Makefile fragment for the betto_pdfium Dart package.
# Included from the repo-root Makefile via
# `include packages/betto_pdfium/betto_pdfium.mk`.
# All targets that run Dart tooling cd into the package directory first so that
# pubspec.yaml, analysis_options.yaml, and the native-assets cache are resolved
# relative to the package root, not the repo root.

BETTO_PKG := packages/betto_pdfium
BETTO_ITA := packages/betto_pdfium/integration_test_app

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

prepare_dart:
	cd $(BETTO_PKG) && dart pub global activate coverage && dart pub get
.PHONY: prepare_dart

prepare_flutter: prepare_dart
	cd $(BETTO_ITA) && flutter pub get
.PHONY: prepare_flutter

prepare: prepare_flutter prepare_ios
.PHONY: prepare

clean_dart:
	rm -rf $(BETTO_PKG)/coverage
	rm -rf $(BETTO_PKG)/doc
	rm -rf $(BETTO_PKG)/site
.PHONY: clean_dart

# ---------------------------------------------------------------------------
# Dart quality gates
# ---------------------------------------------------------------------------

format:
	cd $(BETTO_PKG) && dart format lib/ test/ hook/ example/
.PHONY: format

format_check:
	cd $(BETTO_PKG) && dart format --output=none --set-exit-if-changed lib/ test/ hook/ example/
.PHONY: format_check

analyze:
	cd $(BETTO_PKG) && dart analyze
.PHONY: analyze

test:
	cd $(BETTO_PKG) && dart test
.PHONY: test

license_check:
	cd $(BETTO_PKG) && cat addlicense_config.txt | xargs addlicense --check
.PHONY: license_check

license_add:
	cd $(BETTO_PKG) && cat addlicense_config.txt | xargs addlicense
.PHONY: license_add

coverage:
	cd $(BETTO_PKG) && dart test --coverage-path=coverage/lcov.info
	lcov --remove $(BETTO_PKG)/coverage/lcov.info '*/generated/*' -o $(BETTO_PKG)/coverage/lcov.info
	$(MAKE) --no-print-directory coverage_html
.PHONY: coverage

coverage_html:
	@if [ -f $(BETTO_PKG)/coverage/lcov.info ]; then \
	  rm -rf $(SITE_DIR)/coverage && \
	  genhtml $(BETTO_PKG)/coverage/lcov.info -o $(SITE_DIR)/coverage; \
	else \
	  echo "coverage_html: skipping — no lcov.info found; run 'make coverage' first"; \
	fi
.PHONY: coverage_html

# ---------------------------------------------------------------------------
# PDFium binary management
#
# Pre-built binaries are fetched from GitHub Releases rather than compiled
# locally. The pdfium-build orphan branch owns the build matrix.
#
# Developer workflow:
#   make fetch_pdfium            — download binary + headers matching PDFIUM_VERSION
#   make check_pdfium_version    — verify installed binary/headers match PDFIUM_VERSION
#   make ffi_bindings            — regenerate Dart FFI bindings after a SHA bump
#   make update_pdfium_manifest  — rewrite version_pdfium.json + pdfium_version.dart
# ---------------------------------------------------------------------------

fetch_pdfium:
	cd $(BETTO_PKG) && scripts/fetch_pdfium.sh
.PHONY: fetch_pdfium

check_pdfium_version:
	cd $(BETTO_PKG) && scripts/check_pdfium_version.sh
.PHONY: check_pdfium_version

update_pdfium_manifest:
	cd $(BETTO_PKG) && scripts/update_pdfium_manifest.sh
.PHONY: update_pdfium_manifest

ffi_bindings:
	@echo "ffi_bindings: regenerating Dart FFI bindings from third_party/pdfium/public/ ..."
	cd $(BETTO_PKG) && dart run ffigen --config ffigen.yaml
	@echo "ffi_bindings: done. Review and commit lib/src/generated/pdfium_bindings.dart"
.PHONY: ffi_bindings

fixtures:
	@echo "fixtures: installing Python dependencies ..."
	pip3 install --break-system-packages -r $(BETTO_PKG)/test/fixtures/generate/requirements.txt \
	  || pip3 install -r $(BETTO_PKG)/test/fixtures/generate/requirements.txt
	@echo "fixtures: generating PDF test fixtures ..."
	cd $(BETTO_PKG)/test/fixtures/generate && python3 generate_fixtures.py
	@echo "fixtures: done. Commit the generated PDFs in test/fixtures/"
.PHONY: fixtures

# ---------------------------------------------------------------------------
# Mobile integration test targets
# ---------------------------------------------------------------------------

# sync_fixtures: copy test/fixtures/ and test/data/ into
# integration_test_app/assets/ so the on-device suite has the same PDFs as
# the desktop suite. Run this before a mobile test run to keep fixtures in sync.
sync_fixtures:
	rsync -a --delete --include='*.pdf' --exclude='*' $(BETTO_PKG)/test/fixtures/ $(BETTO_ITA)/assets/fixtures/
	rsync -a --delete --include='*.pdf' --exclude='*' $(BETTO_PKG)/test/data/ $(BETTO_ITA)/assets/data/
.PHONY: sync_fixtures

# fetch_mobile_binaries: download the iOS xcframework and Android .so files
# from the GitHub Release identified in version_pdfium.json.
fetch_mobile_binaries:
	$(BETTO_ITA)/scripts/fetch_mobile_binaries.sh
.PHONY: fetch_mobile_binaries

# ios_test: run the integration test suite on the configured iOS simulator.
ios_test: sync_fixtures fetch_mobile_binaries
	cd $(BETTO_ITA) && flutter pub get
	xcrun simctl list | grep "$(EMULATOR_IOS)" | grep -q "Booted" || xcrun simctl boot $(EMULATOR_IOS)
	open -a Simulator
	cd $(BETTO_ITA) && flutter test integration_test/ --device-id $(EMULATOR_IOS)
.PHONY: ios_test

# android_test: run the integration test suite on the configured Android emulator.
android_test: sync_fixtures fetch_mobile_binaries
	cd $(BETTO_ITA) && flutter pub get
	flutter emulators --launch $(EMULATOR_ANDROID) || true
	$(ADB_BINARY_PATH)/adb wait-for-device
	cd $(BETTO_ITA) && flutter test integration_test/ --device-id emulator-5554
.PHONY: android_test
