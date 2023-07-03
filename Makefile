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
	npm ci --prefix tests
	npm ci --prefix linters

	# check if virtual environment exists or create it
	[ -n "$${VIRTUAL_ENV+x}" ] || [ -d linters/venv ] \
		|| python3 -m venv linters/venv \
		|| python -m venv linters/venv \
		|| virtualenv linters/venv \
		|| mkvirtualenv linters/venv

	PATH="$(PROJECT_DIR)/linters/venv/bin:$(PATH)" \
	PYTHONPATH="$(PROJECT_DIR)/linters/python" \
		pip install --requirement linters/requirements.txt --target linters/python
	mkdir -p "$$HOME/.cache/proselint"

	gem install bundler --install-dir linters/ruby
	PATH="$(PROJECT_DIR)/linters/ruby/bin:$(PATH)" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_PATH__SYSTEM=false \
	BUNDLE_PATH="$(PROJECT_DIR)/linters/bundle" \
	BUNDLE_GEMFILE="$(PROJECT_DIR)/linters/Gemfile" \
		bundle install

	node utils/cargo-packages.js | while read -r package version; do \
		cargo install "$$package" --force --root "$(PROJECT_DIR)/linters/cargo" --version "$$version"; \
	done

	cd linters && \
		composer install

	cd linters && \
		gitman install # TODO: use locally installed gitman (not system one)

	cd linters/gitman/checkmake && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make

	cd linters/gitman/editorconfig-checker && \
		make build

	mkdir -p linters/bin && \
		cp linters/gitman/checkmake/checkmake linters/bin/ && \
		cp linters/gitman/editorconfig-checker/bin/ec linters/bin/

	GOPATH="$(PROJECT_DIR)/linters/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/freshautomations/stoml@latest'
	GOPATH="$(PROJECT_DIR)/linters/go" GO111MODULE=on go install -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest'
	GOPATH="$(PROJECT_DIR)/linters/go" GO111MODULE=on go install -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'

	cabal update
		# cabal install hadolint-2.12.0 && \
		# cabal install ShellCheck-0.9.0

	$(MAKE) -C docs/demo bootstrap

.PHONY: build
build:
	docker build . --tag matejkosiarcik/azlint:dev

.PHONY: run
run:
	docker run --interactive --tty --rm \
		--volume "$(PROJECT_DIR):/project:ro" \
		--env CONFIG_DIR=.config \
		matejkosiarcik/azlint:dev lint

.PHONY: test
test:
	npm test --prefix tests
