# AZLint

> Lint everything From A to Z

Project links:

- GitHub: <https://github.com/matejkosiarcik/azlint>
- DockerHub: <https://hub.docker.com/r/matejkosiarcik/azlint>

| Platform  | Latest version                    |
|-----------|-----------------------------------|
| GitHub    | ![github release] <br> ![git tag] |
| DockerHub | ![dockerhub tag]                  |

[github release]: https://img.shields.io/github/v/release/matejkosiarcik/azlint?sort=semver&style=flat-square&logo=github&logoColor=white&label=release
[git tag]: https://img.shields.io/github/v/tag/matejkosiarcik/azlint?sort=semver&style=flat-square&logo=git&logoColor=white&label=git%20tag
[dockerhub tag]: https://img.shields.io/docker/v/matejkosiarcik/azlint?sort=semver&style=flat-square&logo=docker&logoColor=white&label=image%20tag

<details>
<summary>Table of contents</summary>

<!-- markdown-link-check-disable -->
<!-- toc -->

- [About](#about)
  - [Features](#features)
- [Usage](#usage)
  - [Local - Linux & macOS](#local---linux--macos)
  - [Local - Windows](#local---windows)
  - [GitLabCI](#gitlabci)
  - [CircleCI](#circleci)
  - [GitHub Actions](#github-actions)
- [Configuration](#configuration)
- [Included linters](#included-linters)
  - [All files](#all-files)
  - [General configs](#general-configs)
  - [Package manager files](#package-manager-files)
    - [Dry runners](#dry-runners)
    - [Validators](#validators)
  - [CI/CD services](#cicd-services)
  - [Makefiles](#makefiles)
  - [Dockerfiles](#dockerfiles)
  - [XML, HTML, SVG](#xml-html-svg)
  - [Documentation (Markdown, Plain Text)](#documentation-markdown-plain-text)
  - [Shell script files](#shell-script-files)
  - [Python](#python)
- [Development](#development)
  - [Prepare you system](#prepare-you-system)
  - [Build & Run](#build--run)
- [License](#license)
- [Alternatives](#alternatives)

<!-- tocstop -->
<!-- markdown-link-check-enable -->

</details>

## About

The main purpose of _AZLint_ is to bundle as many linters as possible into a single docker image
and provide convenient CLI interface for calling them in bulk.

I see it as a complement to
[SuperLinter](https://github.com/github/super-linter) and
[MegaLinter](https://github.com/nvuillam/mega-linter).
These meta-linters are awesome, but are missing some features of _AZLint_.

All that said, AZLint is mostly for my personal usage.
However feel free to use it and report any found issues 😉.

### Features

- 📦 Includes 48 linters
- 🛠️ Supports **autofix** mode (only for 9 linters though)
- 🐳 Distributed as a docker image (both `x64`/`arm64` available)
- 💯 Reports all found problems
- 🏎️ Runs linters in parallel
- 🌈 Clear, colored output

## Usage

![azlint demo](./docs/demo.gif)

**NOTE:** In this chapter, we will use `:latest` tag.
It is recommended to replace `:latest` with a specific `version` when you use it.

Go to dockerhub's [tags](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated)
to see all available tags or go to github's [releases](https://github.com/matejkosiarcik/azlint/releases)
for all project versions.

### Local - Linux & macOS

To **lint** files in current directory:

```sh
docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint:latest lint
```

To **format** files in current directory:

```sh
docker run -itv "$PWD:/project" matejkosiarcik/azlint:latest fmt
```

When in doubt, print help:

```sh
$ docker run matejkosiarcik/azlint:latest --help
Usage: azlint <command> [options…] [dir]

Commands:
  azlint lint  Lint project (default)
  azlint fmt   Format project (autofix)

Positionals:
  dir  Path to project directory  [string] [default: "."]

Options:
  -h, --help          Show usage  [boolean]
  -V, --version       Show version  [boolean]
  -v, --verbose       Verbose logging (stackable, max: -vvv)  [count]
  -q, --quiet         Less logging  [boolean]
      --only-changed  Analyze only changed files (requires project to be a git directory)  [boolean]
  -n, --dry-run       Dry run  [boolean]
      --color         Colored output  [string] [choices: "auto", "never", "always"] [default: "auto"]
```

### Local - Windows

Refer to _Linux & macOS_ examples above, just swap `$PWD` to `%cd%`, for example:

```bat
docker run -itv "%cd%:/project:ro" matejkosiarcik/azlint:latest lint
```

### GitLabCI

```yaml
azlint:
  image: matejkosiarcik/azlint:latest
  script:
    - lint
```

### CircleCI

```yaml
version: 2.1

workflows:
  version: 2
  workflow:
    jobs:
      - azlint

jobs:
  azlint:
    docker:
      - image: matejkosiarcik/azlint:latest
    steps:
      - checkout
      - run: lint
```

### GitHub Actions

```yaml
name: AZLint

permissions: read-all

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  azlint:
    name: AZLint
    runs-on: ubuntu-latest
    container:
      image: matejkosiarcik/azlint:latest
      options: --user root
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0 # Full git history is needed to get a proper list of changed files

      - name: Run AZLint
        run: lint
```

## Configuration

AZLint is configured by environment variables with `AZLINT_` prefix.
<!-- TODO: Add configuration via config-file -->

AZLint looks for config files in following places by default: `[git-root]/` and `[git-root]/.config/`.
You can specify a custom config directory with: `AZLINT_CONFIG_DIR=some/config/directory`
(note: _path_ value is relative to `[git-root]`).

AZLint will find config files and pass them to linters automatically.
If you want to specify a custom config file for a specific linter, set `AZLINT_FOO_CONFIG_FILE=some/path/file.json`
(note 1: replace `FOO` with specific linter's name;
note 2: file path is relative to specified config directory).

You can turn of linters/formatters by specifying environment variable `AZLINT_FOO=false`
(note: replace `FOO` with specific linter's name).

A note about linter names, if a linter is named `foo-bar`,
then you need to specify environment variable named `FOO_BAR`
(so capitalized and underscores instead of dashes).

## Included linters

<!-- TODO: Remove this override -->
<!-- markdown-link-check-disable -->

### All files

| tool                        | links                                                                                                                      | disable                         | files | `fmt` support |
|-----------------------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------------|-------|---------------|
| editorconfig-checker        | [GitHub](https://github.com/editorconfig-checker/editorconfig-checker) <br> [docs](https://editorconfig-checker.github.io) | `VALIDATE_EDITORCONFIG_CHECKER` | `*`   | ❌             |
| eclint                      | [GitHub](https://github.com/jednano/eclint)                                                                                | `VALIDATE_ECLINT`               | `*`   | ❌             |
| Git check-ignore \[custom\] | -                                                                                                                          | `VALIDATE_GITIGNORE`            | `*`   | ✅             |
| jscpd                       | [GitHub](https://github.com/kucherenko/jscpd)                                                                              | `VALIDATE_JSCPD`                | `*`   | ❌             |

### General configs

| tool               | links                                                                                                    | disable             | files                   | `fmt` support |
|--------------------|----------------------------------------------------------------------------------------------------------|---------------------|-------------------------|---------------|
| dotenv-linter      | [GitHub](https://github.com/dotenv-linter/dotenv-linter) <br> [docs](https://dotenv-linter.github.io)    | `VALIDATE_DOTENV`   | `*.env`                 | ❌             |
| jsonlint           | [GitHub](https://github.com/prantlf/jsonlint) <br> [try-online](https://prantlf.github.io/jsonlint)      | `VALIDATE_JSONLINT` | `*.json`                | ❌*            |
| prettier           | [GitHub](https://github.com/prettier/prettier) <br> [docs](https://prettier.io)                          | `VALIDATE_PRETTIER` | `*.{json,yml,css,html}` | ✅             |
| stoml              | [GitHub](https://github.com/freshautomations/stoml)                                                      | `VALIDATE_STOML`    | `*.{cfg,ini,toml}`      | ❌             |
| tomljson (go-toml) | [GitHub](https://github.com/pelletier/go-toml)                                                           | `VALIDATE_TOMLJSON` | `*.toml`                | ❌             |
| yamllint           | [GitHub](https://github.com/adrienverge/yamllint) <br> [docs](https://yamllint.readthedocs.io/en/stable) | `VALIDATE_YAMLLINT` | `*.{yml,yaml}`          | ❌             |

_Jsonlint*_ - Formatting conflicts with prettier, so it is turned off.

### Package manager files

#### Dry runners

These tools are not real "linters".
These tools are vanilla package managers, which we invoke with a `dry-run` flag to only _attempt_ to install dependencies without actually installing them.
This verifies the given config files are actually working in that respective package manager.

| tool             | links                                                                                                                | disable                     | files                                | `fmt` support |
|------------------|----------------------------------------------------------------------------------------------------------------------|-----------------------------|--------------------------------------|---------------|
| brew-bundle      | [GitHub](https://github.com/Homebrew/homebrew-bundle) <br> [manpage](https://docs.brew.sh/Manpage#bundle-subcommand) | `VALIDATE_BREW_BUNDLE`      | `Brewfile`                           | ❌             |
| composer-install | [docs](https://getcomposer.org)                                                                                      | `VALIDATE_COMPOSER_INSTALL` | `composer.json`                      | ❌             |
| pip-install      | [docs](https://pip.pypa.io/en/stable/cli/pip_install)                                                                | `VALIDATE_PIP_INSTALL`      | `requirements.txt`                   | ❌             |
| npm-install      | [docs](https://docs.npmjs.com/cli/v9/commands/npm-install)                                                           | `VALIDATE_NPM_INSTALL`      | `package.json`                       | ❌             |
| npm-ci           | [docs](https://docs.npmjs.com/cli/v9/commands/npm-ci)                                                                | `VALIDATE_NPM_CI`           | `package.json` & `package-lock.json` | ❌             |

#### Validators

Extra validators for package-manager files.
These check additional rules, which are recommended, but not required for the config files to be valid.

| tool                   | links                                                                                                                                          | disable                       | files           | `fmt` support |
|------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------|-----------------|---------------|
| composer-normalize     | [GitHub](https://github.com/ergebnis/composer-normalize) <br> [blogpost](https://localheinz.com/articles/2018/01/15/normalizing-composer.json) | `VALIDATE_COMPOSER_NORMALIZE` | `composer.json` | ✅             |
| composer-validate      | [docs](https://getcomposer.org/doc/03-cli.md#validate)                                                                                         | `VALIDATE_COMPOSER_VALIDATE`  | `composer.json` | ❌             |
| package-json-validator | [GitHub](https://github.com/gorillamania/package.json-validator)                                                                               | `VALIDATE_PACKAGE_JSON`       | `package.json`  | ❌             |

### CI/CD services

| tool               | links                                                                                                          | disable                      | files                  | `fmt` support |
|--------------------|----------------------------------------------------------------------------------------------------------------|------------------------------|------------------------|---------------|
| CircleCI CLI lint  | [docs](https://circleci.com/docs/2.0/local-cli) <br> [GitHub](https://github.com/CircleCI-Public/circleci-cli) | `VALIDATE_CIRCLECI_VALIDATE` | `.circleci/config.yml` | ❌             |
| gitlab-ci-lint     | [GitHub](https://github.com/BuBuaBu/gitlab-ci-lint)                                                            | `VALIDATE_GITLABCI_LINT`     | `.gitlab-ci.yml`       | ❌             |
| gitlab-ci-validate | [GitHub](https://github.com/pradel/gitlab-ci-validate)                                                         | `VALIDATE_GITLABCI_VALIDATE` | `.gitlab-ci.yml`       | ❌             |

### Makefiles

| tool      | links                                                                                              | disable              | files           | `fmt` support |
|-----------|----------------------------------------------------------------------------------------------------|----------------------|-----------------|---------------|
| checkmake | [GitHub](https://github.com/mrtazz/checkmake)                                                      | `VALIDATE_CHECKMAKE` | `Makefile` etc. | ❌             |
| BSD Make  | [manpage](https://man.netbsd.org/make.1)                                                           | `VALIDATE_BMAKE`     | `Makefile` etc. | ❌             |
| GNU Make  | [docs](https://www.gnu.org/software/make) <br> [manpage](https://www.gnu.org/software/make/manual) | `VALIDATE_GMAKE`     | `Makefile` etc. | ❌             |

### Dockerfiles

| tool           | links                                                                                                 | disable                   | files             | `fmt` support |
|----------------|-------------------------------------------------------------------------------------------------------|---------------------------|-------------------|---------------|
| dockerfilelint | [GitHub](https://github.com/replicatedhq/dockerfilelint) <br> [try-online](https://www.fromlatest.io) | `VALIDATE_DOCKERFILELINT` | `Dockerfile` etc. | ❌             |
| hadolint       | [GitHub](https://github.com/hadolint/hadolint)                                                        | `VALIDATE_HADOLINT`       | `Dockerfile` etc. | ❌             |

### XML, HTML, SVG

| tool     | links                                                                                                                                                          | disable             | files          | `fmt` support |
|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------|----------------|---------------|
| HTMLHint | [GitHub](https://github.com/HTMLHint/HTMLHint)                                                                                                                 | `VALIDATE_HTMLHINT` | `*.{html,htm}` | ❌             |
| htmllint | [GitHub](https://github.com/htmllint/htmllint)                                                                                                                 | `VALIDATE_HTMLLINT` | `*.{html,htm}` | ❌             |
| SVGLint  | [GitHub](https://github.com/birjolaxew/svglint)                                                                                                                | `VALIDATE_SVGLINT`  | `*.svg`        | ❌             |
| xmllint  | [gitlab](https://gitlab.gnome.org/GNOME/libxml2) <br> [docs](http://www.xmlsoft.org) <br> [manpage](https://gnome.pages.gitlab.gnome.org/libxml2/xmllint.html) | `VALIDATE_XMLLINT`  | `*.xml`        | ✅             |

### Documentation (Markdown, Plain Text)

| tool                | links                                                  | disable                        | files        | `fmt` support |
|---------------------|--------------------------------------------------------|--------------------------------|--------------|---------------|
| markdown-link-check | [GitHub](https://github.com/tcort/markdown-link-check) | `VALIDATE_MARKDOWN_LINK_CHECK` | `*.md`       | ❌             |
| markdownlint        | [GitHub](https://github.com/DavidAnson/markdownlint)   | `VALIDATE_MARKDOWNLINT`        | `*.md`       | ✅             |
| markdownlint (mdl)  | [GitHub](https://github.com/markdownlint/markdownlint) | `VALIDATE_MDL`                 | `*.md`       | ❌             |
| proselint           | [GitHub](https://github.com/amperser/proselint)        | `VALIDATE_PROSELINT`           | `*.{md,txt}` | ❌             |

### Shell script files

| tool              | links                                                                                                                                                      | disable                  | files       | `fmt` support |
|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------|-------------|---------------|
| bashate           | [GitHub](https://github.com/openstack/bashate) <br> [opendev](https://opendev.org/openstack/bashate) <br>[docs](https://docs.openstack.org/bashate/latest) | `VALIDATE_BASHATE`       | `*.sh` etc. | ❌             |
| bats-core         | [GitHub](https://github.com/bats-core/bats-core) <br> [docs](https://bats-core.readthedocs.io/en/stable)                                                   | `VALIDATE_BATS`          | `*.bats`    | ❌             |
| shellcheck        | [GitHub](https://github.com/koalaman/shellcheck) <br> [wiki](https://github.com/koalaman/shellcheck/wiki) <br> [try-online](https://www.shellcheck.net)    | `VALIDATE_SHELLCHECK`    | `*.sh` etc. | ❌             |
| shellharden       | [GitHub](https://github.com/anordal/shellharden)                                                                                                           | `VALIDATE_SHELLHARDEN`   | `*.sh` etc. | ✅             |
| shfmt             | [GitHub](https://github.com/mvdan/sh) <br> [go pkg](https://pkg.go.dev/mvdan.cc/sh/v3)                                                                     | `VALIDATE_SHFMT`         | `*.sh` etc. | ✅             |
| hush              | [GitHub](https://github.com/hush-shell/hush) <br> [docs](https://hush-shell.github.io)                                                                     | `VALIDATE_HUSH`          | `*.hush`    | ❌             |
| Custom dry runner | -                                                                                                                                                          | `VALIDATE_SHELL_DRY_RUN` | `*.sh` etc. | ❌             |

The following shells are checked in custom dry runner:

| tool                                | links                                    | linter ID         | files        | `fmt` support |
|-------------------------------------|------------------------------------------|-------------------|--------------|---------------|
| Linux port of OpenBSD's ksh (loksh) | [GitHub](https://github.com/dimkr/loksh) | `LOKSH` - `loksh` | `*.{sh,ksh}` | ❌             |
| Portable OpenBSD ksh (oksh)         | [GitHub](https://github.com/ibara/oksh)  | `OKSH` - `oksh`   | `*.{sh,ksh}` | ❌             |

### Python

| tool        | links                                                                                                                                                 | disable                | files  | `fmt` support |
|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------|--------|---------------|
| autopep8    | [GitHub](https://github.com/hhatto/autopep8) <br> [pypi](https://pypi.org/project/autopep8)                                                           | `VALIDATE_AUTOPEP8`    | `*.py` | ❌*            |
| black       | [GitHub](https://github.com/psf/black) <br> [docs](https://black.readthedocs.io/en/stable) <br> [pypi](https://pypi.org/project/black)                | `VALIDATE_BLACK`       | `*.py` | ✅             |
| flake8      | [GitHub](https://github.com/PyCQA/flake8) <br> [docs](https://flake8.pycqa.org/en/latest) <br> [pypi](https://pypi.org/project/flake8)                | `VALIDATE_FLAKE8`      | `*.py` | ❌             |
| isort       | [GitHub](https://github.com/PyCQA/isort) <br> [docs](https://pycqa.github.io/isort) <br> [pypi](https://pypi.org/project/isort)                       | `VALIDATE_ISORT`       | `*.py` | ✅             |
| pycodestyle | [GitHub](https://github.com/PyCQA/pycodestyle) <br> [docs](https://pycodestyle.pycqa.org/en/latest) <br> [pypi](https://pypi.org/project/pycodestyle) | `VALIDATE_PYCODESTYLE` | `*.py` | ❌             |
| pylint      | [GitHub](https://github.com/PyCQA/pylint) <br> [docs](https://pylint.readthedocs.io/en/latest) <br> [pypi](https://pypi.org/project/pylint)           | `VALIDATE_PYLINT`      | `*.py` | ❌             |
| mypy        | [GitHub](https://github.com/python/mypy) <br> [docs](https://www.mypy-lang.org) <br> [pypi](https://pypi.org/project/mypy)                            | `VALIDATE_MYPY`        | `*.py` | ❌             |

_Autopep8*_ - Formatting conflicts with black, so it is turned off.

<!-- TODO: Remove this override -->
<!-- markdown-link-check-enable -->

## Development

### Prepare you system

In order to develop on this project, first install required system packages.

- If you are on macOS and have [Homebrew](https://brew.sh) available,
  just run `brew bundle install` in project's root directory.
  This will install all packages from `Brewfile` (learn more about [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle)).
- If you are on Debian/Ubuntu Linux, check out `.circleci/config.yml` -> job _native-build_ for `apt-get` instructions.
- If you are on Windows, you need to find and install packages yourself - check out [Chocolatey](https://chocolatey.org).

Note: Also make sure you have Docker installed.

Now run `make bootstrap` to install local project dependencies.

### Build & Run

To run project locally:

```sh
npm run azlint:fmt && npm run azlint:lint
```

To build and run project in docker:

```sh
make build run
```

## License

This project is licensed under the MIT License,
see [LICENSE.txt](LICENSE.txt) for full license details.

## Alternatives

- [super-linter](https://github.com/github/super-linter)
- [mega-linter](https://github.com/nvuillam/mega-linter)
- [git-lint](https://github.com/sk-/git-lint) (deprecated)
