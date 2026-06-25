# BEGIN: PDFium binary targets
#
# Pre-built PDFium binaries are fetched from GitHub Releases rather than
# compiled locally. The pdfium-build orphan branch owns the build matrix.
#
# Canonical developer workflow:
#   make fetch_pdfium          — download binary + public headers matching PDFIUM_VERSION
#   make check_pdfium_version  — verify installed binary and headers match PDFIUM_VERSION
#   make ffi_bindings          — regenerate Dart FFI bindings after a SHA bump
#
# Bumping the PDFium SHA:
#   1. Update PDFIUM_VERSION with the new commit SHA.
#   2. Push main — CI rebuilds all platform binaries, packages public headers
#      from the same commit, and publishes a new GitHub Release.
#   3. make fetch_pdfium to install the new binary and headers locally.
#   4. If the public API changed: make ffi_bindings to regenerate bindings.

PDFIUM_BIN := third_party/pdfium_bin

fetch_pdfium:
	@scripts/fetch_pdfium.sh

.PHONY: fetch_pdfium

check_pdfium_version:
	@scripts/check_pdfium_version.sh

.PHONY: check_pdfium_version

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
