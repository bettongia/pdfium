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
# Pre-built binaries are fetched from bblanchon/pdfium-binaries GitHub
# Releases. BBLANCHON_BUILD holds the numeric build number (e.g. 7906).
#
# Developer workflow:
#   make fetch_pdfium            — download binary + headers matching BBLANCHON_BUILD
#   make check_pdfium_version    — verify installed binary/headers match BBLANCHON_BUILD
#   make ffi_bindings            — regenerate Dart FFI bindings after a build bump
#   make update_pdfium_manifest  — rewrite version_pdfium.json + pdfium_version.dart
#   make repack_ios_xcframework  — build pdfium.xcframework from bblanchon iOS tarballs
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

# repack_ios_xcframework: download the bblanchon iOS device + simulator tarballs,
# build a pdfium.xcframework with patched install names, zip it, and upload it
# to the bettongia/pdfium GitHub Release tagged bblanchon-chromium-<BUILD>.
# Run this before update_pdfium_manifest when bumping the bblanchon version.
repack_ios_xcframework:
	cd $(BETTO_PKG) && scripts/repack_ios_xcframework.sh
.PHONY: repack_ios_xcframework

ffi_bindings:
	@echo "ffi_bindings: regenerating Dart FFI bindings from third_party/pdfium/public/ ..."
	cd $(BETTO_PKG) && dart run ffigen --config ffigen.yaml
	@echo "ffi_bindings: done. Review and commit lib/src/generated/pdfium_bindings.dart"
.PHONY: ffi_bindings

# build_wasm_worker: regenerate the checked-in PDFium Worker entry-point
# bundle (lib/assets/pdfium_worker.js) from lib/src/document/_pdfium_worker_entry.dart.
# Maintainer-only — run after changing _pdfium_worker_entry.dart or any file
# it depends on (the marshalling engine, wire protocol, or JS interop
# bindings). Consumers never run this; they receive the pre-compiled artifact
# via `make fetch_wasm_assets`. Analogous in spirit to
# `make repack_ios_xcframework` — a release-time regeneration step.
build_wasm_worker:
	@mkdir -p $(BETTO_PKG)/lib/assets
	cd $(BETTO_PKG) && dart compile js -O2 \
	  -o lib/assets/pdfium_worker.js \
	  lib/src/document/_pdfium_worker_entry.dart
	@echo "build_wasm_worker: done. Review and commit lib/assets/pdfium_worker.js"
.PHONY: build_wasm_worker

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
# The PDFium xcframework is fetched by SPM via the URL binaryTarget in
# betto_pdfium_ios/Package.swift during flutter pub get; no manual download.
ios_test: sync_fixtures
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

# ---------------------------------------------------------------------------
# Web (WASM) targets
#
# PDFium WASM assets (pdfium.js + pdfium.wasm) are distributed as static
# files that must be served alongside the Flutter web app. They are not
# bundled by the native-assets hook (which only runs for native targets).
#
# Developer workflow:
#   make fetch_wasm_assets   — download + verify pdfium-wasm.tgz, extract to
#                              integration_test_app/web/assets/pdfium/
#   make web_test            — run the dedicated web test suite in headless Chrome
#   make web_coverage        — measure and enforce ≥ 90% web coverage
#
# WASM_OUTPUT_DIR env var overrides the default output directory for
# fetch_wasm_assets. Set it to your app's web/assets/pdfium/ directory.
# ---------------------------------------------------------------------------

# fetch_wasm_assets: download the PDFium WASM + JS assets from bblanchon and
# place them in integration_test_app/web/assets/pdfium/ (or WASM_OUTPUT_DIR).
fetch_wasm_assets:
	cd $(BETTO_PKG) && scripts/fetch_wasm_assets.sh
.PHONY: fetch_wasm_assets

# stage_wasm_test_assets: copy the WASM assets into test/assets/pdfium/ so that
# `dart test -p chrome` can serve them. The Chrome test page is served at
# /test/<name>.html, so `assets/pdfium/pdfium.js` resolves to
# /test/assets/pdfium/pdfium.js on the test HTTP server.
#
# fetch_wasm_assets writes to integration_test_app/web/assets/pdfium/; we
# symlink from test/assets/pdfium/ to avoid duplicating the ~4 MB WASM binary.
stage_wasm_test_assets: fetch_wasm_assets
	@mkdir -p $(BETTO_PKG)/test/assets/pdfium
	@for f in pdfium.js pdfium.wasm; do \
	  src=$(BETTO_PKG)/integration_test_app/web/assets/pdfium/$$f; \
	  dst=$(BETTO_PKG)/test/assets/pdfium/$$f; \
	  if [ ! -f "$$src" ]; then \
	    echo "stage_wasm_test_assets: $$src not found — run 'make fetch_wasm_assets' first"; \
	    exit 1; \
	  fi; \
	  ln -sf "$(CURDIR)/$$src" "$$dst" 2>/dev/null || cp "$$src" "$$dst"; \
	done
	@echo "stage_wasm_test_assets: WASM assets staged at $(BETTO_PKG)/test/assets/pdfium/"
.PHONY: stage_wasm_test_assets

# web_test: run the dedicated web test suite (test/pdf_document_web_test.dart)
# in headless Chrome. Requires Chrome to be installed on the host.
# Fixtures are served from the test/ directory by dart test's local server.
#
# Also runs the platform-agnostic unit-test files (no dart:io/dart:ffi
# imports) under the browser platform, alongside the dedicated web suite —
# without these, their coverage never counts toward web_coverage below, even
# though the code they test (shared model/utility files) is real web-relevant
# source.
WEB_TEST_FILES := test/pdf_document_web_test.dart test/bitmap_util_test.dart \
	test/pdf_types_test.dart test/pdf_date_parser_test.dart \
	test/pdf_page_size_test.dart

web_test: stage_wasm_test_assets
	cd $(BETTO_PKG) && dart test -p chrome $(WEB_TEST_FILES)
.PHONY: web_test

# web_coverage: measure web test coverage and enforce ≥ 90% line coverage.
# Produces lcov data at coverage/web/lcov.info for the browser run.
# The raw browser lcov includes every script Chrome instrumented on the test
# page, which — unlike the VM-based `coverage` target — includes transitive
# third-party dependencies bundled into the same compiled JS (package:test,
# package:async, package:collection, etc.). `lcov --extract` narrows the
# report to this package's own lib/ sources before the threshold is computed,
# mirroring the `*/generated/*` exclusion in the `coverage` target above.
# The 90% threshold applies independently of the native coverage gate.
web_coverage: stage_wasm_test_assets
	cd $(BETTO_PKG) && dart test -p chrome --coverage-path=coverage/web/lcov.info $(WEB_TEST_FILES)
	@if [ -f $(BETTO_PKG)/coverage/web/lcov.info ]; then \
	  lcov --extract $(BETTO_PKG)/coverage/web/lcov.info '*/betto_pdfium/lib/*' -o $(BETTO_PKG)/coverage/web/lcov.info; \
	  echo "web_coverage: computing web coverage ..."; \
	  LINES_FOUND=$$(grep -c '^DA:' $(BETTO_PKG)/coverage/web/lcov.info || echo 0); \
	  LINES_HIT=$$(grep '^DA:' $(BETTO_PKG)/coverage/web/lcov.info | grep -v ',0$$' | wc -l | tr -d '[:space:]'); \
	  echo "  lines found: $$LINES_FOUND  lines hit: $$LINES_HIT"; \
	  if [ "$$LINES_FOUND" -gt 0 ]; then \
	    PCT=$$((LINES_HIT * 100 / LINES_FOUND)); \
	    echo "  web line coverage: $$PCT%"; \
	    if [ "$$PCT" -lt 90 ]; then \
	      echo "web_coverage: FAIL — coverage $$PCT% is below the 90% threshold"; \
	      exit 1; \
	    fi; \
	    echo "web_coverage: PASS ($$PCT% >= 90%)"; \
	  fi; \
	else \
	  echo "web_coverage: skipping — no web lcov.info found; run 'make web_test' first"; \
	fi
.PHONY: web_coverage
