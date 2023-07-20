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

	npm ci
	npm ci --prefix tests
	npm ci --prefix linters

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

	node utils/cargo-packages.js | while read -r package version; do \
		cargo install "$$package" --force --root "$$PWD/linters/cargo" --version "$$version"; \
	done

	cd linters && \
		composer install

	cd linters/gitman/checkmake && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make
	cp linters/gitman/checkmake/checkmake linters/bin/

	cd linters/gitman/editorconfig-checker && \
		make build
	cp linters/gitman/editorconfig-checker/bin/ec linters/bin/

	GOPATH="$$PWD/linters/go" GO111MODULE=on go install -modcacherw -ldflags='-s -w' 'mvdan.cc/sh/v3/cmd/shfmt@latest'
	GOPATH="$$PWD/linters/go" GO111MODULE=on go install -modcacherw -ldflags='-s -w' "github.com/freshautomations/stoml@latest"
	GOPATH="$$PWD/linters/go" GO111MODULE=on go install -modcacherw -ldflags='-s -w' 'github.com/pelletier/go-toml/cmd/tomljson@latest'
	GOPATH="$$PWD/linters/go" GO111MODULE=on go install -modcacherw -ldflags='-s -w' "github.com/rhysd/actionlint/cmd/actionlint@latest"

	cabal update # && \
		# cabal install hadolint-2.12.0 && \
		# cabal install ShellCheck-0.9.0

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
	docker build . --tag matejkosiarcik/azlint:dev

.PHONY: run
run:
	docker run --interactive --tty --rm \
		--volume "$$PWD:/project:ro" \
		matejkosiarcik/azlint:dev lint

.PHONY: test
test:
	npm test --prefix tests

.PHONY: clean
clean:
	git clean -xdf
	rm -rf "$$PWD/linters/gitman" "$$PWD/docs/demo/gitman"

.PHONY: demo
demo:
	$(MAKE) -C docs/demo bootstrap record
