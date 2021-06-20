# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
PROJECT_DIR := $(dir $(abspath $(MAKEFILE_LIST)))
SHELL := /bin/sh
.SHELLFLAGS := -ec

.POSIX:

.DEFAULT: all
.PHONY: all
all: build run

.PHONY: build
build:
	docker build . --tag matejkosiarcik/azlint:dev

.PHONY: run
run: run-fmt run-lint

.PHONY: run-lint
run-lint:
	docker run --interactive --tty --volume "$(PROJECT_DIR):/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: run-fmt
run-fmt:
	docker run --interactive --tty --volume "$(PROJECT_DIR):/project" matejkosiarcik/azlint:dev fmt

.PHONY: doc
doc:
	@$(MAKE) -C$(PROJECT_DIR)/doc/demo bootstrap record
