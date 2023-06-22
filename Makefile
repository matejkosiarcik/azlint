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
