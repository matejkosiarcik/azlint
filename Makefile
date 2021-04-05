# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
PROJECT_DIR := $(dir $(abspath $(MAKEFILE_LIST)))
AZLINT_VERSION ?= dev
DESTDIR ?= $${HOME}/bin
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
run:
	docker run --interactive --tty --volume "$${PWD}:/project" matejkosiarcik/azlint:dev
