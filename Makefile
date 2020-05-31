# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
PROJECT_DIR := $(dir $(abspath $(MAKEFILE_LIST)))
AZLINT_VERSION ?= dev

.PHONY: build
build:
	sh .ci/build.sh

.PHONY: run
run:
	AZLINT_VERSION=$(AZLINT_VERSION) node runner/main.js
	# docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project" --volume '/var/run/docker.sock:/var/run/docker.sock' "azlint:$(AZLINT_VERSION)"
