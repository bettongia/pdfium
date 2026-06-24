# BEGIN: PDFium build targets
#
# Local workflow (macOS arm64 only):
#   make setup              — bootstrap depot_tools + gclient sync (run once)
#   make build_pdfium_macos — compile libpdfium.dylib and stage to dist/
#   make clean_build        — delete build/ entirely to start fresh
#
# Linux x64, Android, and WASM builds run on GitHub Actions ubuntu runners
# (native x86_64). Call the same Makefile targets directly on the runner —
# no containers required.
#
# Note: gclient writes a small authentication cache to ~/.config/gclient.
# Everything else (depot_tools, source tree, clang toolchain) stays under build/.
#
# Note: depot_tools is used at HEAD (unpinned). If gclient sync breaks in the
# future due to a depot_tools update, pinning will need to be revisited.

export BUILD_DIR := $(CURDIR)/build

# Guard path: both setup and build targets check for the presence of the
# pdfium source tree at this path, not just build/. This ensures that a partial
# gclient sync failure (where build/ exists but the source download was
# incomplete) is retried rather than silently skipped.
export PDFIUM_SRC := $(BUILD_DIR)/pdfium_checkout/pdfium

export DEPOT_TOOLS := $(BUILD_DIR)/depot_tools

export PDFIUM_DIST := $(CURDIR)/dist
export PDFIUM_REVISION ?= $(shell git fetch origin main && git show main:PDFIUM_VERSION)

RAW_OS := $(shell uname -s)

ifeq ($(RAW_OS),Linux)
    export HOST_OS := linux
    export GN := $(PDFIUM_SRC)/buildtools/linux64/gn
else ifeq ($(RAW_OS),Darwin)
    export HOST_OS := mac
    export GN := $(PDFIUM_SRC)/buildtools/mac/gn
else
    ifneq ($(findstring MINGW,$(RAW_OS)),)
        export HOST_OS := win
    else
        export HOST_OS := unknown
    endif
endif

export BASE_DIR := $(CURDIR)

.DEFAULT_GOAL := info

info:
	@scripts/info.sh
.PHONY: info

setup:
	@scripts/setup.sh
.PHONY: setup

build_pdfium_macos: export PDFIUM_OS := mac
build_pdfium_macos: export PDFIUM_CPU := arm64
build_pdfium_macos: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_macos: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_macos: setup
	@scripts/build_macos.sh
.PHONY: build_pdfium_macos

build_pdfium_linux_setup:
	cd $(PDFIUM_SRC) && build/install-build-deps.sh --no-prompt --no-chromeos-fonts
.PHONY: build_pdfium_linux_setup

build_pdfium_linux_x64: export PDFIUM_OS := linux
build_pdfium_linux_x64: export PDFIUM_CPU := x64
build_pdfium_linux_x64: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_linux_x64: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_linux_x64: setup build_pdfium_linux_setup
	@scripts/build_linux.sh
.PHONY: build_pdfium_linux_x64

build_pdfium_linux_arm64: export PDFIUM_OS := linux
build_pdfium_linux_arm64: export PDFIUM_CPU := arm64
build_pdfium_linux_arm64: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_linux_arm64: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_linux_arm64: setup build_pdfium_linux_setup
	python3 $(PDFIUM_SRC)/build/linux/sysroot_scripts/install-sysroot.py --arch=arm64
	@scripts/build_linux.sh
.PHONY: build_pdfium_linux_arm64

build_pdfium_ios: export PDFIUM_OS := ios
build_pdfium_ios: export PDFIUM_CPU := arm64
build_pdfium_ios: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_ios: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_ios: setup
	@scripts/build_ios.sh
.PHONY: build_pdfium_ios

build_pdfium_android_arm64: export PDFIUM_OS := android
build_pdfium_android_arm64: export PDFIUM_CPU := arm64
build_pdfium_android_arm64: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_android_arm64: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_android_arm64: setup
	@scripts/build_android.sh
.PHONY: build_pdfium_android_arm64

build_pdfium_android_x64: export PDFIUM_OS := android
build_pdfium_android_x64: export PDFIUM_CPU := x64
build_pdfium_android_x64: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_android_x64: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_android_x64: setup
	@scripts/build_android.sh
.PHONY: build_pdfium_android_x64

build_pdfium_wasm: export PDFIUM_OS := linux
build_pdfium_wasm: export PDFIUM_CPU := wasm
build_pdfium_wasm: export PDFIUM_PLATFORM := $(PDFIUM_OS)-$(PDFIUM_CPU)
build_pdfium_wasm: export PDFIUM_OUT := $(PDFIUM_SRC)/out/$(PDFIUM_PLATFORM)
build_pdfium_wasm: setup build_pdfium_linux_setup
	@scripts/build_wasm.sh
.PHONY: build_pdfium_wasm

clean:
	@echo "purge: removing $(PDFIUM_SRC)/out."
	rm -rf $(PDFIUM_SRC)/out
	@echo "purge: removing $(PDFIUM_DIST)."
	rm -rf $(PDFIUM_DIST)
.PHONY: clean

purge: clean
	@echo "purge: removing build/ workspace ..."
	rm -rf $(BUILD_DIR)
	@echo "purge: done. Run 'make setup' to start fresh."
.PHONY: purge

# END: PDFium build targets
