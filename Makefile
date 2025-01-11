# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))

.POSIX:
.SILENT:

.DEFAULT: all
.PHONY: all
all: clean bootstrap test docker-build docker-run docker-build-multiarch

.PHONY: bootstrap
bootstrap:
	mkdir -p linters/bin

	printf '%s\0%s\0' . linters | \
		xargs -0 -P0 -n1 npm ci --no-save --no-progress --no-audit --no-fund --loglevel=error --prefix

	# Python dependencies
	printf '%s\n%s\n' build-dependencies/gitman build-dependencies/yq | while read -r dir; do \
		cd "$(PROJECT_DIR)/$$dir" && \
		(deactivate >/dev/null 2>&1 || true) && \
		rm -rf venv && \
		python3 -m venv venv && \
		. ./venv/bin/activate && \
		PATH="$$PWD/venv/bin:$$PATH" \
		PIP_DISABLE_PIP_VERSION_CHECK=1 \
			python3 -m pip install --requirement requirements.txt --quiet --upgrade && \
		deactivate && \
	true; done

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
	PYTHONPATH="$(PROJECT_DIR)/linters/python-vendor" \
	PIP_DISABLE_PIP_VERSION_CHECK=1 \
		python3 -m pip install --requirement linters/requirements.txt --target linters/python-vendor --quiet --upgrade

	# Create cache ahead of time, because it can fail when creating during runtime
	mkdir -p "$$HOME/.cache/proselint"

	gem install bundler
	# --install-dir "$(PROJECT_DIR)/linters/ruby"
	PATH="$(PROJECT_DIR)/linters/ruby/bin:$$PATH" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_FROZEN=true \
	BUNDLE_GEMFILE="$(PROJECT_DIR)/linters/Gemfile" \
	BUNDLE_PATH="$(PROJECT_DIR)/linters/bundle" \
	BUNDLE_PATH__SYSTEM=false \
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

	printf '%s\n%s\n%s\n%s\n' mvdan.cc/sh/v3/cmd/shfmt@latest github.com/freshautomations/stoml@latest github.com/pelletier/go-toml/cmd/tomljson@latest github.com/rhysd/actionlint/cmd/actionlint@latest | \
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
	npm run build

.PHONY: test
test:
	npm test

.PHONY: docker-build
docker-build:
	time docker build . --tag matejkosiarcik/azlint:dev

.PHONY: docker-build-multiarch
docker-build-multiarch:
	printf '%s\n%s\n' amd64 arm64/v8 | \
		while read -r arch; do \
			printf 'Building for linux/%s:\n' "$$arch" && \
			time docker build . --tag "matejkosiarcik/azlint:dev-$$(printf '%s' "$$arch" | tr '/' '-')" --platform "linux/$$arch" && \
		true; done

.PHONY: docker-run
docker-run:
	time docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" matejkosiarcik/azlint:dev lint

.PHONY: docker-multirun
docker-multirun:
	printf '%s\n%s\n' amd64 arm64/v8 | \
		while read -r arch; do \
			printf 'Running on linux/%s:\n' "$$arch" && \
			time docker run --interactive --tty --rm --volume "$(PROJECT_DIR):/project:ro" --platform "linux/$$arch" "matejkosiarcik/azlint:dev-$$(printf '%s' "$$arch" | tr '/' '-')" lint \
		true; done

.PHONY: clean
clean:
	if [ -e "$(PROJECT_DIR)/linters/go" ]; then \
		chown -R "$(shell whoami)" "$(PROJECT_DIR)/linters/go" && \
		find "$(PROJECT_DIR)/linters/go" -type f -exec chmod 0644 {} \; && \
		find "$(PROJECT_DIR)/linters/go" -type d -exec chmod 0755 {} \; && \
	true; fi

	find linters/gitman-repos -name gitman -type d -prune -exec rm -rf {} \;
	rm -rf "$(PROJECT_DIR)/build-dependencies/python-gitman/venv" \
		"$(PROJECT_DIR)/build-dependencies/yq/venv" \
		"$(PROJECT_DIR)/cli-dist" \
		"$(PROJECT_DIR)/docs/demo/gitman" \
		"$(PROJECT_DIR)/linters/bin" \
		"$(PROJECT_DIR)/linters/bundle" \
		"$(PROJECT_DIR)/linters/.bundle" \
		"$(PROJECT_DIR)/linters/cargo" \
		"$(PROJECT_DIR)/linters/go" \
		"$(PROJECT_DIR)/linters/node_modules" \
		"$(PROJECT_DIR)/linters/python-vendor" \
		"$(PROJECT_DIR)/linters/target" \
		"$(PROJECT_DIR)/linters/vendor" \
		"$(PROJECT_DIR)/node_modules" \
		"$(PROJECT_DIR)/venv"

.PHONY: demo
demo:
	$(MAKE) -C docs/demo bootstrap record
