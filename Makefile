# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
PROJECT_DIR := $(dir $(abspath $(MAKEFILE_LIST)))
AZLINT_VERSION ?= dev

.DEFAULT: all
.PHONY: all
all: bootstrap build run

.PHONY: bootstrap
bootstrap:
	npm install --prefix runner

.PHONY: build
build:
	sh utils/build.sh

.PHONY: run
run:
	AZLINT_VERSION=$(AZLINT_VERSION) node runner/main.js

.PHONY: run-docker
run-docker:
	docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" --volume '/var/run/docker.sock:/var/run/docker.sock' "matejkosiarcik/azlint:$(AZLINT_VERSION)"
