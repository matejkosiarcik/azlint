# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
PROJECT_DIR := $(dir $(abspath $(MAKEFILE_LIST)))

# TODO: add "list" target

.PHONY: build
build:
	docker build . --tag azlint:dev

.PHONY: run
run:
	docker run -it --rm --volume $(PROJECT_DIR):/mount azlint:dev
