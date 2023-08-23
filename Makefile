# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))

.POSIX:
.SILENT:

.DEFAULT: all
.PHONY: all
all: bootstrap test build run

.PHONY: bootstrap
bootstrap:
	mkdir -p linters/bin

	printf '. linters ' | \
		tr ' ' '\n' | \
		xargs -P0 -n1 npm install --no-save --no-progress --no-audit --quiet --prefix

	printf 'build-dependencies/gitman/venv build-dependencies/yq/venv ' | \
		tr ' ' '\n' | \
		xargs -P0 -n1 python3 -m venv

	cd "$(PROJECT_DIR)/build-dependencies/gitman" && \
		PATH="$$PWD/venv/bin:$$PATH" \
		PIP_DISABLE_PIP_VERSION_CHECK=1 \
			pip install --requirement requirements.txt --quiet --upgrade

	cd "$(PROJECT_DIR)/build-dependencies/yq" && \
		PATH="$$PWD/venv/bin:$$PATH" \
		PIP_DISABLE_PIP_VERSION_CHECK=1 \
			pip install --requirement requirements.txt --quiet --upgrade

	find linters/gitman-repos -mindepth 1 -maxdepth 1 -type d -print0 | \
		PATH="$(PROJECT_DIR)/build-dependencies/gitman/venv/bin:$$PATH" xargs -0 -n1 -P0 gitman install --quiet --force --root
	if [ "$(shell uname -s)" != Linux ]; then \
		sh utils/apply-git-patches.sh linters/git-patches/loksh linters/gitman-repos/shell-loksh/gitman/loksh && \
	true; fi

	cd linters/gitman-repos/shell-loksh/gitman/loksh && \
		meson setup --fatal-meson-warnings --prefix="$$PWD/install" build && \
		ninja --quiet -C build install && \
		cp install/bin/ksh "$(PROJECT_DIR)/linters/bin/loksh"

	cd linters/gitman-repos/shell-oksh/gitman/oksh && \
		./configure && \
		make && \
		DESTDIR="$$PWD/install" make install && \
		cp install/usr/local/bin/oksh "$(PROJECT_DIR)/linters/bin/"

	PATH="$(PROJECT_DIR)/venv/bin:$$PATH" \
	PYTHONPATH="$(PROJECT_DIR)/linters/python" \
	PIP_DISABLE_PIP_VERSION_CHECK=1 \
		pip install --requirement linters/requirements.txt --target linters/python --quiet --upgrade

	# Create cache ahead of time, because it can fail when creating during runtime
	mkdir -p "$$HOME/.cache/proselint"

	gem install bundler --install-dir linters/ruby
	PATH="$(PROJECT_DIR)/linters/ruby/bin:$$PATH" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_PATH__SYSTEM=false \
	BUNDLE_PATH="$(PROJECT_DIR)/linters/bundle" \
	BUNDLE_GEMFILE="$(PROJECT_DIR)/linters/Gemfile" \
		bundle install --quiet

	PATH="$(PROJECT_DIR)/build-dependencies/yq/venv/bin:$$PATH" \
		tomlq -r '."dev-dependencies" | to_entries | map("\(.key) \(.value)")[]' linters/Cargo.toml | \
		xargs -n2 -P0 sh -c \
		'cd "$$PWD" && cargo install "$$0" --quiet --force --root "$(PROJECT_DIR)/linters/cargo" --version "$$1" --profile dev'

	cd linters && \
		composer install --quiet

	cd linters/gitman-repos/go-checkmake/gitman/checkmake && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make && \
		cp checkmake "$(PROJECT_DIR)/linters/bin/"

	cd linters/gitman-repos/go-editorconfig-checker/gitman/editorconfig-checker && \
		make build && \
		cp bin/ec "$(PROJECT_DIR)/linters/bin/"

	printf 'mvdan.cc/sh/v3/cmd/shfmt@latest\ngithub.com/freshautomations/stoml@latest\ngithub.com/pelletier/go-toml/cmd/tomljson@latest\ngithub.com/rhysd/actionlint/cmd/actionlint@latest\n' | \
		GOPATH="$(PROJECT_DIR)/linters/go" GO111MODULE=on xargs -P0 -n1 go install -modcacherw

	cd linters/gitman-repos/circleci-cli/gitman/circleci-cli && \
		mkdir -p install && \
		if [ "$(shell uname)" = Darwin ] && [ "$(shell uname -m)" = arm64 ]; then \
			DESTDIR="$$PWD/install/" arch -x86_64 /bin/bash install.sh; \
		else \
			DESTDIR="$$PWD/install/" bash install.sh; \
		fi && \
		cp install/circleci "$(PROJECT_DIR)/linters/bin/"

	if command -v brew >/dev/null 2>&1; then \
		HOMEBREW_NO_ANALYTICS=1 \
		HOMEBREW_NO_AUTO_UPDATE=1 \
			brew bundle --help --quiet >/dev/null; \
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
	time docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: multirun
multirun:
	time docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" --platform linux/amd64 matejkosiarcik/azlint:dev-amd64 lint
	time docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" --platform linux/arm64 matejkosiarcik/azlint:dev-arm64 lint

.PHONY: test
test:
	npm test

.PHONY: clean
clean:
	find linters/gitman-repos -name gitman -type d -prune -exec rm -rf {} \;
	rm -rf "$(PROJECT_DIR)/build-dependencies/python-gitman/venv" \
		"$(PROJECT_DIR)/build-dependencies/yq/venv" \
		"$(PROJECT_DIR)/docs/demo/gitman" \
		"$(PROJECT_DIR)/linters/bin" \
		"$(PROJECT_DIR)/linters/bundle" \
		"$(PROJECT_DIR)/linters/cargo" \
		"$(PROJECT_DIR)/linters/go" \
		"$(PROJECT_DIR)/linters/node_modules" \
		"$(PROJECT_DIR)/linters/python" \
		"$(PROJECT_DIR)/linters/ruby" \
		"$(PROJECT_DIR)/linters/target" \
		"$(PROJECT_DIR)/linters/vendor" \
		"$(PROJECT_DIR)/node_modules" \
		"$(PROJECT_DIR)/venv"

.PHONY: demo
demo:
	$(MAKE) -C docs/demo bootstrap record
