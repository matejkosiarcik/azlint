# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))

.POSIX:

.DEFAULT: all
.PHONY: all
all: bootstrap build test run

.PHONY: bootstrap
bootstrap:
	npm ci
	npm ci --prefix tests-cli
	npm ci --prefix dependencies

	# check if virtual environment exists or create it
	[ -n "$${VIRTUAL_ENV+x}" ] || [ -d dependencies/venv ] \
		|| python3 -m venv dependencies/venv \
		|| python -m venv dependencies/venv \
		|| virtualenv dependencies/venv \
		|| mkvirtualenv dependencies/venv
	# install dependencies
	PATH="$(PROJECT_DIR)/dependencies/venv/bin:$(PATH)" pip install --requirement dependencies/requirements.txt

	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_PATH__SYSTEM=false \
	BUNDLE_PATH="$(PROJECT_DIR)/dependencies/.bundle" \
	BUNDLE_GEMFILE="$(PROJECT_DIR)/dependencies/Gemfile" \
		bundle install

	node "cargo-packages.js" | while read package version; do \
		cargo install "$$package" --force --root "$(PROJECT_DIR)/dependencies/.cargo" --version "$$version"; \
	done

	(cd dependencies && composer install --no-cache)

.PHONY: build
build:
	docker build . --tag matejkosiarcik/azlint:dev

.PHONY: test
test:
	npm test --prefix tests-cli

.PHONY: run
run: run-fmt run-lint

.PHONY: run-lint
run-lint:
	docker run --interactive --volume "$(PROJECT_DIR):/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: run-fmt
run-fmt:
	docker run --interactive --volume "$(PROJECT_DIR):/project" matejkosiarcik/azlint:dev fmt

.PHONY: doc
doc:
	@$(MAKE) -C$(PROJECT_DIR)/doc/demo bootstrap record
