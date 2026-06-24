# BEGIN: PDFium binary targets
#
# Pre-built PDFium binaries are fetched from GitHub Releases rather than
# compiled locally. The pdfium-build orphan branch owns the build matrix.
#
# Canonical developer workflow:
#   make fetch_pdfium          — download the binary matching PDFIUM_VERSION
#   make check_pdfium_version  — verify the installed binary matches PDFIUM_VERSION
#   make ffi_bindings          — regenerate Dart FFI bindings after a SHA bump
#
# Bumping the PDFium SHA:
#   1. Update PDFIUM_VERSION with the new commit SHA.
#   2. git subtree pull to update third_party/pdfium/ (public headers).
#   3. make ffi_bindings to regenerate lib/src/generated/pdfium_bindings.dart.
#   4. Push main — CI rebuilds all platform binaries and publishes a release.
#   5. make fetch_pdfium to pull the new binary into third_party/pdfium_bin/.

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
