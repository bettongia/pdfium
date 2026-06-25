# BEGIN: PDFium binary targets
#
# Pre-built PDFium binaries are fetched from GitHub Releases rather than
# compiled locally. The pdfium-build orphan branch owns the build matrix.
#
# Canonical developer workflow:
#   make fetch_pdfium            — download binary + public headers matching PDFIUM_VERSION
#   make check_pdfium_version    — verify installed binary and headers match PDFIUM_VERSION
#   make ffi_bindings            — regenerate Dart FFI bindings after a SHA bump
#   make update_pdfium_manifest  — update version_pdfium.json + pdfium_version.dart from
#                                  the checksums published in the GitHub Release
#
# Bumping the PDFium SHA (two-commit workflow):
#   Commit 1 — trigger the build:
#     1. Update PDFIUM_VERSION with the new commit SHA.
#     2. Push main — CI rebuilds all platform binaries and publishes a new GitHub Release.
#   Wait for CI to finish.
#   Commit 2 — update the hook manifest:
#     3. make update_pdfium_manifest  (reads checksums from the just-published release)
#     4. make fetch_pdfium            (install new binary + headers locally)
#     5. make ffi_bindings            (only if the public API changed)
#     6. Commit version_pdfium.json, lib/src/pdfium_version.dart, and any updated bindings.

PDFIUM_BIN := third_party/pdfium_bin

fetch_pdfium:
	@scripts/fetch_pdfium.sh

.PHONY: fetch_pdfium

check_pdfium_version:
	@scripts/check_pdfium_version.sh

.PHONY: check_pdfium_version

update_pdfium_manifest:
	@scripts/update_pdfium_manifest.sh

.PHONY: update_pdfium_manifest

ffi_bindings:
	@echo "ffi_bindings: regenerating Dart FFI bindings from third_party/pdfium/public/ ..."
	dart run ffigen --config ffigen.yaml
	@echo "ffi_bindings: done. Review and commit lib/src/generated/pdfium_bindings.dart"

.PHONY: ffi_bindings

fixtures:
	@echo "fixtures: installing Python dependencies ..."
	pip3 install --break-system-packages -r test/fixtures/generate/requirements.txt || pip3 install -r test/fixtures/generate/requirements.txt
	@echo "fixtures: generating PDF test fixtures ..."
	cd test/fixtures/generate && python3 generate_fixtures.py
	@echo "fixtures: done. Commit the generated PDFs in test/fixtures/"

.PHONY: fixtures

# END: PDFium binary targets
