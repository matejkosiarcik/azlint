# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))

.POSIX:

.DEFAULT: all
.PHONY: all
all: bootstrap test build run

.PHONY: bootstrap
bootstrap:
	mkdir -p linters/bin

	parallel npm install --no-save --prefix ::: . linters

	# check if virtual environment exists or create it
	[ -n "$${VIRTUAL_ENV+x}" ] || [ -d venv ] \
		|| python3 -m venv venv \
		|| python -m venv venv \
		|| virtualenv venv \
		|| mkvirtualenv venv

	PATH="$(PROJECT_DIR)/venv/bin:$(PATH)" \
		pip install --requirement requirements.txt --quiet

	PATH="$(PROJECT_DIR)/venv/bin:$(PATH)" \
		parallel gitman install --quiet --force --root ::: $(shell find linters/gitman-repos -mindepth 1 -maxdepth 1 -type d) && \
		sh utils/apply-gitman-patches.sh

	# find linters/gitman-repos -mindepth 1 -maxdepth 1 -type d | while read -r dir; do \
	# 	PATH="$(PROJECT_DIR)/venv/bin:$(PATH)" gitman install --force --root "$$dir"; \
	# done && \
	# 	sh utils/apply-gitman-patches.sh

	cd linters/gitman-repos/shell-loksh/gitman/loksh && \
		meson setup --prefix="$$PWD/install" build && \
		ninja -C build install && \
		cp install/bin/ksh "$(PROJECT_DIR)/linters/bin/loksh"

	cd linters/gitman-repos/shell-oksh/gitman/oksh && \
		./configure && \
		make && \
		DESTDIR="$$PWD/install" make install && \
		cp install/usr/local/bin/oksh "$(PROJECT_DIR)/linters/bin/"

	PATH="$$PWD/venv/bin:$(PATH)" \
	PYTHONPATH="$$PWD/linters/python" \
	PIP_DISABLE_PIP_VERSION_CHECK=1 \
		pip install --requirement linters/requirements.txt --target linters/python --quiet --force-reinstall

	# Create cache ahead of time, because it can fail when creating during runtime
	mkdir -p "$$HOME/.cache/proselint"

	gem install bundler --install-dir linters/ruby
	PATH="$$PWD/linters/ruby/bin:$(PATH)" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_PATH__SYSTEM=false \
	BUNDLE_PATH="$$PWD/linters/bundle" \
	BUNDLE_GEMFILE="$$PWD/linters/Gemfile" \
		bundle install --quiet

	node utils/cargo-packages.js | xargs -n2 -P0 sh -c \
		'cargo install "$$0" --quiet --force --root "$$PWD/linters/cargo" --version "$$1" --profile dev'

	cd linters && \
		composer install --quiet

	cd linters/gitman-repos/go-checkmake/gitman/checkmake && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make && \
		cp checkmake "$(PROJECT_DIR)/linters/bin/"

	cd linters/gitman-repos/go-editorconfig-checker/gitman/editorconfig-checker && \
		make build && \
		cp bin/ec "$(PROJECT_DIR)/linters/bin/"

	# GOPATH="$$PWD/linters/go" GO111MODULE=on \
	# 	go install -modcacherw github.com/mikefarah/yq/v4@latest

	GOPATH="$$PWD/linters/go" GO111MODULE=on parallel ::: \
		'go install -modcacherw "mvdan.cc/sh/v3/cmd/shfmt@latest"' \
		'go install -modcacherw "github.com/freshautomations/stoml@latest"' \
		'go install -modcacherw "github.com/pelletier/go-toml/cmd/tomljson@latest"' \
		'go install -modcacherw "github.com/rhysd/actionlint/cmd/actionlint@latest"'

	# cabal update
	# parallel ::: \
	# 	'cabal install hadolint-2.12.0' \
	# 	'cabal install ShellCheck-0.9.0'

	cd linters/gitman-repos/circleci-cli/gitman/circleci-cli && \
		mkdir -p install && \
		if [ "$(shell uname)" = Darwin ] && [ "$(shell uname -m)" = arm64 ]; then \
			DESTDIR="$$PWD/install/" arch -x86_64 /bin/bash install.sh; \
		else \
			DESTDIR="$$PWD/install/" bash install.sh; \
		fi && \
		cp install/circleci "$(PROJECT_DIR)/linters/bin/"

	if command -v brew >/dev/null 2>&1; then \
		brew bundle --help >/dev/null; \
	fi

.PHONY: build
build:
	time docker build . --tag matejkosiarcik/azlint:dev

.PHONY: multibuild
multibuild:
	time docker build . --tag matejkosiarcik/azlint:dev-amd64 --platform linux/amd64
	time docker build . --tag matejkosiarcik/azlint:dev-arm64 --platform linux/arm64

.PHONY: run
run:
	time docker run --interactive --tty --rm --volume "$$PWD:/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: multirun
multirun:
	time docker run --interactive --tty --rm --volume "$$PWD:/project:ro" --platform linux/amd64 matejkosiarcik/azlint:dev-amd64 lint
	time docker run --interactive --tty --rm --volume "$$PWD:/project:ro" --platform linux/arm64 matejkosiarcik/azlint:dev-arm64 lint

.PHONY: test
test:
	npm test

.PHONY: clean
clean:
	find linters/gitman-repos -name gitman -type d -prune -exec rm -rf {} \;

	rm -rf "$$PWD/docs/demo/gitman" \
		"$$PWD/linters/bin" \
		"$$PWD/linters/bundle" \
		"$$PWD/linters/cargo" \
		"$$PWD/linters/go" \
		"$$PWD/linters/node_modules" \
		"$$PWD/linters/python" \
		"$$PWD/linters/ruby" \
		"$$PWD/linters/target" \
		"$$PWD/linters/vendor" \
		"$$PWD/node_modules" \
		"$$PWD/venv"

.PHONY: demo
demo:
	$(MAKE) -C docs/demo bootstrap record
