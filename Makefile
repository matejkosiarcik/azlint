# Helper Makefile to group scripts for development

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.SHELLFLAGS := -ec
PROJECT_DIR := $(abspath $(dir $(MAKEFILE_LIST)))
DOCKER_ARCHS := amd64 arm64/v8
DOCKER_IMAGE := matejkosiarcik/azlint:dev
NPM_COMPONENTS := $(shell find '.' -type f -name 'package-lock.json' -not \( -path '*/bundle/*' -or -path '*/cargo/*' -or -path '*/gitman-repos/*' -or -path '*/go/*' -or -path '*/node_modules/*' -or -path '*/python-vendor/*' -or -path '*/target/*' -or -path '*/vendor/*' -or -path '*/venv/*' \) -exec dirname {} \; | LC_ALL=C sort -u | base64)
PYTHON_COMPONENTS := $(shell find '.' -type f -name 'requirements.txt' -not \( -path '*/bundle/*' -or -path '*/cargo/*' -or -path '*/gitman-repos/*' -or -path '*/go/*' -or -path '*/node_modules/*' -or -path '*/python-vendor/*' -or -path '*/target/*' -or -path '*/vendor/*' -or -path '*/venv/*' \) -exec dirname {} \; | LC_ALL=C sort -u | base64)

# Define portable datetime format
define_log_function := log_timestamp() { date_supports_milliseconds="$$(date '+%3N')"; case "$${date_supports_milliseconds}" in [0-9][0-9][0-9]) milliseconds_format='%3N' ;; *) milliseconds_format='000' ;; esac; date "+%Y-%m-%dT%H:%M:%S.$${milliseconds_format}Z"; }; log() { log_level="$$1"; shift; log_timestamp="$$(log_timestamp)"; printf '%s\n' "$${*}" | while IFS= read -r log_message || [ -n "$${log_message}" ]; do printf '%s [%s]: %s\n' "$${log_timestamp}" "$$log_level" "$${log_message}"; done >&2; }

# TODO: Remove workaround with python3.14 after version compatibility - https://github.com/google/re2/issues/647
PYTHON ?= $(shell command -v python3.14 2>/dev/null || command -v python3)

.POSIX:
.SILENT:

.DEFAULT: all
.PHONY: all
all: clean bootstrap build test docker-build docker-run docker-build-multiarch

.PHONY: bootstrap
bootstrap:
	# Check if there is an active virtualenv and abort
	$(define_log_function); \
	if [ -n "$${VIRTUAL_ENV+x}" ]; then \
		log ERROR 'There is an active Python virtualenv. Run "deactivate" and try again.'; \
		exit 1; \
	fi

	mkdir -p './linters/bin'

	# NOTE: Shouldn't run in parallel, because it can collide when creating the same temporary cache directory
	printf '%s' "$(NPM_COMPONENTS)" | tr -d ' ' | base64 -d | while IFS= read -r component; do \
		npm ci --prefix "$(PROJECT_DIR)/$${component}" --no-save --no-progress --no-audit --no-fund --loglevel=error && \
	true; done

	# Python dependencies
	printf '%s' "$(PYTHON_COMPONENTS)" | tr -d ' ' | base64 -d | while IFS= read -r component; do \
		cd "$(PROJECT_DIR)/$${component}" && \
		rm -rf './venv' && \
		$(PYTHON) -m venv './venv' && \
		PATH="$${PWD}/venv/bin:$${PATH}" \
		PIP_DISABLE_PIP_VERSION_CHECK='1' \
		PYTHONDONTWRITEBYTECODE='1' \
			python3 -m pip install --quiet --no-compile --require-hashes --requirement './requirements.txt' && \
	true; done

	rm -rf "$(PROJECT_DIR)/venv"
	$(PYTHON) -m venv "$(PROJECT_DIR)/venv"
	PATH="$(PROJECT_DIR)/venv/bin:$${PATH}" \
	PYTHONPATH="$(PROJECT_DIR)/linters/python-vendor" \
	PIP_DISABLE_PIP_VERSION_CHECK='1' \
	PYTHONDONTWRITEBYTECODE='1' \
		python3 -m pip install --quiet --no-compile --require-hashes --requirement './linters/requirements.txt' --target './linters/python-vendor'

	find './linters/gitman-repos' -mindepth 1 -maxdepth 1 -type d -print0 | \
		PATH="$(PROJECT_DIR)/build-dependencies/gitman/venv/bin:$${PATH}" xargs -0 -n1 -P0 gitman install --quiet --force --root
	sh './utils/apply-git-patches.sh' './linters/git-patches/checkmake' './linters/gitman-repos/go-checkmake/gitman/checkmake'
	if [ "$$(uname -s)" != Linux ]; then \
		sh './utils/apply-git-patches.sh' './linters/git-patches/loksh' './linters/gitman-repos/shell-loksh/gitman/loksh' && \
	true; fi

	cd './linters/gitman-repos/shell-loksh/gitman/loksh' && \
		meson setup --fatal-meson-warnings --prefix="$${PWD}/install" './build' && \
		ninja --quiet -C './build' install && \
		cp './install/bin/ksh' "$(PROJECT_DIR)/linters/bin/loksh"

	cd './linters/gitman-repos/shell-oksh/gitman/oksh' && \
		'./configure' && \
		make && \
		DESTDIR="$${PWD}/install" make install && \
		cp './install/usr/local/bin/oksh' "$(PROJECT_DIR)/linters/bin/"

	# Create cache ahead of time, because it can fail when creating during runtime
	mkdir -p "$${HOME}/.cache/proselint"

	gem install bundler
	# --install-dir "$(PROJECT_DIR)/linters/ruby"
	PATH="$(PROJECT_DIR)/linters/ruby/bin:$${PATH}" \
	BUNDLE_DISABLE_SHARED_GEMS=true \
	BUNDLE_FROZEN=true \
	BUNDLE_GEMFILE="$(PROJECT_DIR)/linters/Gemfile" \
	BUNDLE_PATH="$(PROJECT_DIR)/linters/bundle" \
	BUNDLE_PATH__SYSTEM=false \
		bundle install --quiet

	PATH="$(PROJECT_DIR)/build-dependencies/yq/venv/bin:$${PATH}" \
		tomlq -r '."dev-dependencies" | to_entries | map("\(.key) \(.value)")[]' './linters/Cargo.toml' | \
		xargs -n2 -P0 sh -c \
		'cd "$${PWD}" && cargo install "$${0}" --quiet --force --root "$(PROJECT_DIR)/linters/cargo" --version "$${1}" --profile dev'

	cd './linters' && \
		composer install --quiet

	cd './linters/gitman-repos/go-checkmake/gitman/checkmake' && \
		BUILDER_NAME=nobody BUILDER_EMAIL=nobody@example.com make && \
		cp './checkmake' "$(PROJECT_DIR)/linters/bin/"

	cd './linters/gitman-repos/go-editorconfig-checker/gitman/editorconfig-checker' && \
		make build && \
		cp './bin/editorconfig-checker' "$(PROJECT_DIR)/linters/bin/"

	printf '%s\n%s\n%s\n%s\n' mvdan.cc/sh/v3/cmd/shfmt@latest github.com/freshautomations/stoml@latest github.com/pelletier/go-toml/cmd/tomljson@latest github.com/rhysd/actionlint/cmd/actionlint@latest | \
		GOPATH="$(PROJECT_DIR)/linters/go" GO111MODULE=on xargs -P0 -n1 go install -modcacherw

	cd './linters/gitman-repos/circleci-cli/gitman/circleci-cli' && \
		mkdir -p './install' && \
		DESTDIR="$${PWD}/install/" bash './install.sh'; \
		cp './install/circleci' "$(PROJECT_DIR)/linters/bin/"

	if command -v brew >'/dev/null' 2>&1; then \
		HOMEBREW_NO_ANALYTICS=1 \
		HOMEBREW_NO_AUTO_UPDATE=1 \
			brew bundle --help --quiet >'/dev/null'; \
	fi

.PHONY: build
build:
	$(define_log_function); log INFO 'Building CLI'
	npm --prefix './cli' run build

.PHONY: test
test:
	$(define_log_function); log INFO 'Testing CLI'
	npm --prefix './cli' test

.PHONY: run
run:
	$(define_log_function); log INFO 'Running azlint'
	npm --prefix './cli' run azlint:lint

.PHONY: docker-build
docker-build:
	$(define_log_function); log INFO 'Building Docker image'
	time docker build "$(PROJECT_DIR)" --tag "$(DOCKER_IMAGE)"

.PHONY: docker-build-multiarch
docker-build-multiarch:
	$(define_log_function); \
	printf '%s\n' $(DOCKER_ARCHS) | \
		while read -r arch; do \
			log INFO "Building Docker image for linux/$${arch}" && \
			time docker build "$(PROJECT_DIR)" --tag "$(DOCKER_IMAGE)-$$(printf '%s' "$${arch}" | tr '/' '-')" --platform "linux/$${arch}" && \
		true; done

.PHONY: docker-run
docker-run:
	$(define_log_function); log INFO 'Running azlint in Docker'
	time docker run --interactive --tty --rm --tmpfs '/tmp:rw,exec,nodev,noatime,nodiratime,uid=1000,gid=1000' --volume "$(PROJECT_DIR):/project:ro" "$(DOCKER_IMAGE)" lint

.PHONY: docker-run-multiarch
docker-run-multiarch:
	$(define_log_function); \
	printf '%s\n' $(DOCKER_ARCHS) | \
		while read -r arch; do \
			log INFO "Running azlint in Docker on linux/$${arch}" && \
			time docker run --interactive --tty --rm --tmpfs '/tmp:rw,exec,nodev,noatime,nodiratime,uid=1000,gid=1000' --volume "$(PROJECT_DIR):/project:ro" --platform "linux/$${arch}" "$(DOCKER_IMAGE)-$$(printf '%s' "$${arch}" | tr '/' '-')" lint \
		true; done

.PHONY: clean
clean:
	# Check if there is an active virtualenv and abort
	$(define_log_function); \
	if [ -n "$${VIRTUAL_ENV+x}" ]; then \
		log ERROR 'There is an active python virtualenv. Run "deactivate" and try again.'; \
		exit 1; \
	fi

	if [ -e "$(PROJECT_DIR)/linters/go" ]; then \
		chown -R "$$(whoami)" "$(PROJECT_DIR)/linters/go" && \
		find "$(PROJECT_DIR)/linters/go" -type f -exec chmod 0644 {} \; && \
		find "$(PROJECT_DIR)/linters/go" -type d -exec chmod 0755 {} \; && \
	true; fi

	find "$(PROJECT_DIR)" -type d \( \
		-name '.bundle' -or \
		-name '.mypy_cache' -or \
		-name 'build' -or \
		-name 'dist' -or \
		-name 'gitman-repositories' -or \
		-name 'node_modules' -or \
		-name 'python-vendor' -or \
		-name 'target' -or \
		-name 'test-report' -or \
		-name 'vendor' -or \
		-name 'venv' \
	\) -prune -exec rm -rf {} \;

	find './linters/gitman-repos' -name gitman -type d -prune -exec rm -rf {} \;
	rm -rf "$(PROJECT_DIR)/docs/demo/gitman" \
		"$(PROJECT_DIR)/linters/bin" \
		"$(PROJECT_DIR)/linters/bundle" \
		"$(PROJECT_DIR)/linters/cargo" \
		"$(PROJECT_DIR)/linters/go"

.PHONY: demo
demo:
	$(MAKE) -C './docs/demo' bootstrap record
