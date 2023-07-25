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
	mkdir -p linters/bin

	parallel ::: \
		'npm install --no-save' \
		'npm install --no-save --prefix tests' \
		'npm install --no-save --prefix linters'

	# check if virtual environment exists or create it
	[ -n "$${VIRTUAL_ENV+x}" ] || [ -d venv ] \
		|| python3 -m venv venv \
		|| python -m venv venv \
		|| virtualenv venv \
		|| mkvirtualenv venv

	PATH="$$PWD/venv/bin:$(PATH)" \
	PYTHONPATH="$$PWD/python" \
		pip install --requirement requirements.txt

	cd linters && \
		PATH="$(PROJECT_DIR)/venv/bin:$(PATH)" \
			gitman install --force
	sh utils/apply-git-patches.sh

	cd linters/gitman/loksh && \
		meson setup --prefix="$$PWD/install" build && \
		ninja -C build install
	cp linters/gitman/loksh/install/bin/ksh linters/bin/loksh

	cd linters/gitman/oksh && \
		./configure && \
		make && \
		DESTDIR="$$PWD/install" make install
	cp linters/gitman/oksh/install/usr/local/bin/oksh linters/bin/oksh

	PATH="$$PWD/venv/bin:$(PATH)" \
	PYTHONPATH="$$PWD/linters/python" \
		pip install --requirement linters/requirements.txt --target linters/python

	# Create cache ahead of time, because it can fail when creating during runtime
	mkdir -p "$$HOME/.cache/proselint"

	gem install bundler --install-dir linters/ruby
	PATH="$$PWD/linters/ruby/bin:$(PATH)" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_PATH__SYSTEM=false \
	BUNDLE_PATH="$$PWD/linters/bundle" \
	BUNDLE_GEMFILE="$$PWD/linters/Gemfile" \
		bundle install

	node utils/cargo-packages.js | xargs -n2 -P0 sh -c \
		'cargo install "$$0" --force --root "$$PWD/linters/cargo" --version "$$1" --profile dev'

	cd linters && \
		composer install

	cd linters/gitman/checkmake && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make
	cp linters/gitman/checkmake/checkmake linters/bin/

	cd linters/gitman/editorconfig-checker && \
		make build
	cp linters/gitman/editorconfig-checker/bin/ec linters/bin/

	GOPATH="$$PWD/linters/go" GO111MODULE=on parallel ::: \
		'go install -modcacherw "mvdan.cc/sh/v3/cmd/shfmt@latest"' \
		'go install -modcacherw "github.com/freshautomations/stoml@latest"' \
		'go install -modcacherw "github.com/pelletier/go-toml/cmd/tomljson@latest"' \
		'go install -modcacherw "github.com/rhysd/actionlint/cmd/actionlint@latest"'

	cabal update
	# parallel ::: \
	# 	'cabal install hadolint-2.12.0' \
	# 	'cabal install ShellCheck-0.9.0'

	cd linters/gitman/circleci-cli && \
		mkdir -p install && \
		if [ "$(shell uname)" = Darwin ] && [ "$(shell uname -m)" = arm64 ]; then \
			DESTDIR="$$PWD/install/" arch -x86_64 /bin/bash install.sh; \
		else \
			DESTDIR="$$PWD/install/" bash install.sh; \
		fi
	cp linters/gitman/circleci-cli/install/circleci linters/bin/

	if command -v brew >/dev/null 2>&1; then \
		brew bundle --help >/dev/null; \
	fi

.PHONY: build
build:
	docker build . --tag matejkosiarcik/azlint:dev --pull

.PHONY: multibuild
multibuild:
	docker build . --tag matejkosiarcik/azlint:dev-amd64 --platform linux/amd64 --pull
	docker build . --tag matejkosiarcik/azlint:dev-arm64 --platform linux/arm64 --pull

.PHONY: run
run:
	docker run --interactive --tty --rm --volume "$$PWD:/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: test
test:
	npm test --prefix tests

.PHONY: clean
clean:
	rm -rf "$$PWD/docs/demo/gitman" \
		"$$PWD/linters/bin" \
		"$$PWD/linters/bundle" \
		"$$PWD/linters/cargo" \
		"$$PWD/linters/gitman" \
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
