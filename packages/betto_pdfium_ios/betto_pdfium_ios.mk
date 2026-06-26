# betto_pdfium_ios.mk — Makefile fragment for the betto_pdfium_ios Flutter plugin.
# Included from the repo-root Makefile via
# `include packages/betto_pdfium_ios/betto_pdfium_ios.mk`.

BETTO_IOS := packages/betto_pdfium_ios

prepare_ios:
	cd $(BETTO_IOS) && flutter pub get
.PHONY: prepare_ios

clean_ios:
	cd $(BETTO_IOS) && flutter clean
.PHONY: clean_ios

analyze_ios:
	cd $(BETTO_IOS) && flutter analyze
.PHONY: analyze_ios

license_check_ios:
	addlicense -l apache -c "The Authors" --check \
	  --ignore="**/*.yml" \
	  --ignore="**/*.yaml" \
	  --ignore="**/*.xml" \
	  --ignore="**/*.sh" \
	  --ignore="**/*.html" \
	  --ignore="**/*.rb" \
	  --ignore="**/*.txt" \
	  --ignore="**/.dart_tool/**" \
	  --ignore="build/**" \
	  $(BETTO_IOS)
.PHONY: license_check_ios

license_add_ios:
	addlicense -l apache -c "The Authors" \
	  --ignore="**/*.yml" \
	  --ignore="**/*.yaml" \
	  --ignore="**/*.xml" \
	  --ignore="**/*.sh" \
	  --ignore="**/*.html" \
	  --ignore="**/*.rb" \
	  --ignore="**/*.txt" \
	  --ignore="**/.dart_tool/**" \
	  --ignore="build/**" \
	  $(BETTO_IOS)
.PHONY: license_add_ios
