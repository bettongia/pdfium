.DEFAULT_GOAL := default

include build_targets.mk
include site.mk

# BEGIN: Primary tasks

default: prepare license_check format analyze coverage doc_site
.PHONY: default

pre_commit: check_pdfium_version format_check analyze license_check test
.PHONY: pre_commit

cicd: clean default
.PHONY: cicd

# END: Primary tasks

format:
	dart format .
.PHONY: format

format_check:
	dart format --output=none --set-exit-if-changed lib/ test/ example/
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
	genhtml coverage/lcov.info -o site/coverage/html

prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare_dart

clean:
	rm -rf site dist coverage
	rm -f *.log

.PHONY: clean
