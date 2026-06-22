# BEGIN: PDFium build targets
#
# These targets manage the clean-room PDFium build workspace in .build/ and
# stage the resulting dylib to third_party/pdfium_bin/.
#
# Canonical workflow:
#   make setup              — bootstrap depot_tools + gclient sync (run once)
#   make build_pdfium_macos — compile libpdfium.dylib and stage to third_party/pdfium_bin/
#   make ffi_bindings       — regenerate Dart FFI bindings from public headers
#   make clean_build        — delete .build/ entirely to start fresh
#
# Note: gclient writes a small authentication cache to ~/.config/gclient.
# Everything else (depot_tools, source tree, clang toolchain) stays under .build/.
#
# Note: depot_tools is used at HEAD (unpinned). If gclient sync breaks in the
# future due to a depot_tools update, pinning will need to be revisited.

# Guard path: both setup and build_pdfium_macos check for the presence of the
# pdfium source tree at this path, not just .build/. This ensures that a partial
# gclient sync failure (where .build/ exists but the source download was
# incomplete) is retried rather than silently skipped.
PDFIUM_SRC := .build/pdfium_checkout/pdfium
PDFIUM_OUT := $(PDFIUM_SRC)/out/mac-arm64
DEPOT_TOOLS := .build/depot_tools
PDFIUM_BIN := third_party/pdfium_bin

# gn is bundled with the PDFium source tree; use it directly rather than
# relying on the depot_tools wrapper, which requires a separate bootstrap step.
GN := $(CURDIR)/$(PDFIUM_SRC)/buildtools/mac/gn

# Inline PATH so no shell profile changes are required.
# DEPOT_TOOLS_UPDATE=0 prevents depot_tools from auto-updating during
# incremental builds, which could cause unexpected network fetches.
BUILD_ENV := PATH="$(CURDIR)/$(DEPOT_TOOLS):$(PATH)" DEPOT_TOOLS_UPDATE=0

setup:
	@if [ -d "$(PDFIUM_SRC)" ]; then \
		echo "setup: $(PDFIUM_SRC) already exists — skipping (remove with make clean_build to retry)"; \
	else \
		echo "setup: cloning depot_tools into $(DEPOT_TOOLS) ..."; \
		mkdir -p .build; \
		if [ ! -d "$(DEPOT_TOOLS)" ]; then \
			git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $(DEPOT_TOOLS); \
		fi; \
		mkdir -p .build/pdfium_checkout; \
		cd "$(CURDIR)/.build/pdfium_checkout" && $(BUILD_ENV) gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git; \
		echo "setup: running gclient sync — this downloads several GB and may take 20–40 minutes on first run ..."; \
		cd "$(CURDIR)/.build/pdfium_checkout" && $(BUILD_ENV) gclient sync; \
		echo "setup: gclient sync complete. PDFium source is at $(PDFIUM_SRC)"; \
	fi

.PHONY: setup

build_pdfium_macos: setup
	@echo "build_pdfium_macos: configuring GN build for mac arm64 ..."
	mkdir -p $(PDFIUM_OUT)
	printf 'is_debug = false\npdf_is_standalone = true\nis_component_build = true\npdf_enable_xfa = false\npdf_enable_v8 = false\nuse_custom_libcxx = false\nclang_use_chrome_plugins = false\ntarget_cpu = "arm64"\ntarget_os = "mac"\n' > $(PDFIUM_OUT)/args.gn
	cd $(PDFIUM_SRC) && $(BUILD_ENV) $(GN) gen out/mac-arm64
	@echo "build_pdfium_macos: running ninja (this may take 10–30 minutes on first build) ..."
	cd $(PDFIUM_SRC) && $(BUILD_ENV) ninja -C out/mac-arm64 pdfium -j$$(sysctl -n hw.logicalcpu)
	@echo "build_pdfium_macos: staging all dylibs to $(PDFIUM_BIN)/macos_arm64/ ..."
	mkdir -p $(PDFIUM_BIN)/macos_arm64
	cp $(PDFIUM_OUT)/*.dylib $(PDFIUM_BIN)/macos_arm64/
	install_name_tool -id @rpath/libpdfium.dylib $(PDFIUM_BIN)/macos_arm64/libpdfium.dylib
	@echo "build_pdfium_macos: writing VERSION file ..."
	@printf "pdfium_commit=%s\nbuild_date=%s\n" \
		$$(cd $(PDFIUM_SRC) && git rev-parse HEAD) \
		$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		> $(PDFIUM_BIN)/VERSION
	@echo "build_pdfium_macos: done. Binary at $(PDFIUM_BIN)/macos_arm64/libpdfium.dylib"
	@echo ""
	@echo "Note: a locally-built dylib is never assigned the com.apple.quarantine"
	@echo "xattr, so Gatekeeper does not apply and dlopen() loads it without signing."
	@echo "Ad-hoc codesigning is deferred to plan_pdfium_build_pipeline.md, where"
	@echo "pipeline-fetched binaries are downloaded and will be quarantined."

.PHONY: build_pdfium_macos

clean_build:
	@echo "clean_build: removing .build/ workspace ..."
	rm -rf .build
	@echo "clean_build: done. Run 'make setup' to start fresh."

.PHONY: clean_build

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

# END: PDFium build targets
