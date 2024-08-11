# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))
PATH := $(PROJECT_DIR)/venv/bin:$(PROJECT_DIR)/node_modules/.bin:$(PATH)

.POSIX:

.DEFAULT: all
.PHONY: all
all: bootstrap record

.PHONY: bootstrap
bootstrap:
	npm ci --no-save --no-progress --no-audit --no-fund --quiet

	# check if virtual environment exists or create it
	[ -n "$${VIRTUAL_ENV+x}" ] || [ -d venv ] \
		|| python3 -m venv venv \
		|| python -m venv venv \
		|| virtualenv venv \
		|| mkvirtualenv venv

	python3 -m pip install --requirement requirements.txt
	gitman install

.PHONY: record
record:
	sh main.sh
