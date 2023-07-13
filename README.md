# AZLint

> Lint everything From A to Z

[![dockerhub version](https://img.shields.io/docker/v/matejkosiarcik/azlint?label=dockerhub&sort=semver)](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated)
[![github version](https://img.shields.io/github/v/release/matejkosiarcik/azlint?sort=semver)](https://github.com/matejkosiarcik/azlint/releases)

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
  - [Package managers](#package-managers)
  - [CI/CD services](#cicd-services)
  - [Makefile](#makefile)
  - [Dockerfile](#dockerfile)
  - [XML derivations](#xml-derivations)
  - [Documentation](#documentation)
  - [Shells](#shells)
  - [Python](#python)
- [Development](#development)
- [License](#license)
- [Alternatives](#alternatives)

<!-- tocstop -->

## About

The main purpose of _AZLint_ is to bundle as many linters as possible into a single docker image
and provide convenient CLI interface for calling them in bulk.

_AZLint_ has an optional **format** mode 🤯 \(also called **autofix**\),
which applies suggested fixes \(from supported linters\) to your files.

All that said, AZLint is mostly for my personal usage.
However feel free to use it and report any found issues 😉.

I see it as a complement to
[SuperLinter](https://github.com/github/super-linter) and
[MegaLinter](https://github.com/nvuillam/mega-linter).
These meta-linters are awesome, but are missing some linters that are bundled into
_AZLint_.

### Features

- 📦 Includes 39 linters
- 🛠️ Supports autofix mode (only for 11 linters)
- 🐳 Distributed as a docker image
- 💯 Reports all found problems, not just the first one
- 🏎️ Runs linters in parallel to speed up

## Usage

![azlint demo](./docs/demo.gif)

**NOTE:** In this chapter, we will use `:latest` tag.
It is recommended to replace `:latest` with a specific `version` when you use it.

Go to dockerhub's [tags](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated)
to see all available tags or go to github's [releases](https://github.com/matejkosiarcik/azlint/releases)
for all project versions.

### Local - Linux & macOS

To **lint** files in current folder:

```sh
docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint:latest lint
```

To **format** files in current folder:

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

AZLint expects to find config files in the root directory you are calling from.
Eg. repository root.
AZLint relies on bundled linters to pick their own config file automatically.

You can turn of linters/formatters using environment variables. Example:
`docker run -itv "$PWD:/project:ro" -e VALIDATE_FOO=false matejkosiarcik/azlint`.
Where `VALIDATE_FOO` can be found in the following section.

## Included linters

### All files

| tool                                                                                 | disable                         | files | autofix |
|--------------------------------------------------------------------------------------|---------------------------------|-------|---------|
| [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker) | `VALIDATE_EDITORCONFIG_CHECKER` | `*`   | ❌       |
| [eclint](https://github.com/jednano/eclint)                                          | `VALIDATE_ECLINT`               | `*`   | ❌       |
| git check-ignore                                                                     | `VALIDATE_GITIGNORE`            | `*`   | ✅       |
| [jscpd](https://github.com/kucherenko/jscpd)                                         | `VALIDATE_JSCPD`                | `*`   | ❌       |

### General configs

| tool                                                            | disable             | files                   | autofix |
|-----------------------------------------------------------------|---------------------|-------------------------|---------|
| [dotenv-linter](https://github.com/dotenv-linter/dotenv-linter) | `VALIDATE_DOTENV`   | `*.env`                 | ❌       |
| [jsonlint](https://github.com/prantlf/jsonlint)                 | `VALIDATE_JSONLINT` | `*.json`                | ❌*      |
| [prettier](https://github.com/prettier/prettier)                | `VALIDATE_PRETTIER` | `*.{json,yml,css,html}` | ✅       |
| [stoml](https://github.com/freshautomations/stoml)              | `VALIDATE_STOML`    | `*.{cfg,ini,toml}`      | ❌       |
| [tomljson](https://github.com/pelletier/go-toml)                | `VALIDATE_TOMLJSON` | `*.toml`                | ❌       |
| [yamllint](https://github.com/adrienverge/yamllint)             | `VALIDATE_YAMLLINT` | `*.{yml,yaml}`          | ❌       |

_Jsonlint*_ - Formatting conflicts with prettier, so it is turned off.

### Package managers

| tool                                                                             | disable                       | files              | autofix |
|----------------------------------------------------------------------------------|-------------------------------|--------------------|---------|
| [brew-bundle](https://github.com/Homebrew/homebrew-bundle)                       | `VALIDATE_BREW_BUNDLE`        | `Brewfile`         | ❌       |
| [composer-normalize](https://github.com/ergebnis/composer-normalize)             | `VALIDATE_COMPOSER_NORMALIZE` | `composer.json`    | ✅       |
| [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)              | `VALIDATE_COMPOSER_VALIDATE`  | `composer.json`    | ❌       |
| [composer-install](https://getcomposer.org)                                      | `VALIDATE_COMPOSER_INSTALL`   | `composer.json`    | ❌       |
| [package-json-validator](https://github.com/gorillamania/package.json-validator) | `VALIDATE_PACKAGE_JSON`       | `package.json`     | ❌       |
| [pip-install](https://pip.pypa.io/en/stable/cli/pip_install)                     | `VALIDATE_PIP_INSTALL`        | `requirements.txt` | ❌       |
| [npm-install](https://docs.npmjs.com/cli/v6/commands/npm-install)                | `VALIDATE_NPM_INSTALL`        | `package.json`     | ❌       |

### CI/CD services

| tool                                                               | disable                      | files                  | autofix |
|--------------------------------------------------------------------|------------------------------|------------------------|---------|
| [circle-ci lint](https://circleci.com/docs/2.0/local-cli)          | `VALIDATE_CIRCLECI_VALIDATE` | `.circleci/config.yml` | ❌       |
| [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)        | `VALIDATE_GITLABCI_LINT`     | `.gitlab-ci.yml`       | ❌       |
| [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate) | `VALIDATE_GITLABCI_VALIDATE` | `.gitlab-ci.yml`       | ❌       |
| [travis-lint](https://github.com/travis-ci/travis.rb#lint)         | `VALIDATE_TRAVIS_LINT`       | `.travis.yml`          | ❌       |

### Makefile

| tool                                             | disable              | files           | autofix |
|--------------------------------------------------|----------------------|-----------------|---------|
| [bmake](https://man.netbsd.org/make.1)           | `VALIDATE_BMAKE`     | `Makefile` etc. | ❌       |
| [checkmake](https://github.com/mrtazz/checkmake) | `VALIDATE_CHECKMAKE` | `Makefile` etc. | ❌       |
| [gmake](https://www.gnu.org/software/make)       | `VALIDATE_GMAKE`     | `Makefile` etc. | ❌       |

### Dockerfile

| tool                                                             | disable                   | files             | autofix |
|------------------------------------------------------------------|---------------------------|-------------------|---------|
| [dockerfilelint](https://github.com/replicatedhq/dockerfilelint) | `VALIDATE_DOCKERFILELINT` | `Dockerfile` etc. | ❌       |
| [hadolint](https://github.com/hadolint/hadolint)                 | `VALIDATE_HADOLINT`       | `Dockerfile` etc. | ❌       |

### XML derivations

| tool                                             | disable             | files          | autofix |
|--------------------------------------------------|---------------------|----------------|---------|
| [htmlhint](https://github.com/HTMLHint/HTMLHint) | `VALIDATE_HTMLHINT` | `*.{html,htm}` | ❌       |
| [htmllint](https://github.com/htmllint/htmllint) | `VALIDATE_HTMLLINT` | `*.{html,htm}` | ❌       |
| [svglint](https://github.com/birjolaxew/svglint) | `VALIDATE_SVGLINT`  | `*.svg`        | ❌       |
| [xmllint](http://www.xmlsoft.org)                | `VALIDATE_XMLLINT`  | `*.xml`        | ✅       |

### Documentation

| tool                                                                | disable                        | files        | autofix |
|---------------------------------------------------------------------|--------------------------------|--------------|---------|
| [markdown-link-check](https://github.com/tcort/markdown-link-check) | `VALIDATE_MARKDOWN_LINK_CHECK` | `*.md`       | ❌       |
| [markdownlint](https://github.com/DavidAnson/markdownlint)          | `VALIDATE_MARKDOWNLINT`        | `*.md`       | ✅       |
| [mdl](https://github.com/markdownlint/markdownlint)                 | `VALIDATE_MDL`                 | `*.md`       | ❌       |
| [proselint](https://github.com/amperser/proselint)                  | `VALIDATE_PROSELINT`           | `*.{md,txt}` | ❌       |

### Shells

| tool                                                  | disable                  | files       | autofix |
|-------------------------------------------------------|--------------------------|-------------|---------|
| [bashate](https://github.com/openstack/bashate)       | `VALIDATE_BASHATE`       | `*.sh` etc. | ❌       |
| [bats-core](https://github.com/bats-core/bats-core)   | `VALIDATE_BATS`          | `*.bats`    | ❌       |
| [shellcheck](https://github.com/koalaman/shellcheck)  | `VALIDATE_SHELLCHECK`    | `*.sh` etc. | ❌       |
| [shellharden](https://github.com/anordal/shellharden) | `VALIDATE_SHELLHARDEN`   | `*.sh` etc. | ✅       |
| [shfmt](https://github.com/mvdan/sh)                  | `VALIDATE_SHFMT`         | `*.sh` etc. | ✅       |
| Custom dry runner                                     | `VALIDATE_SHELL_DRY_RUN` | `*.sh` etc. | ❌       |

The following shells are checked in custom dry runner:

| tool                                    |
|-----------------------------------------|
| [loksh](https://github.com/dimkr/loksh) |

### Python

| tool                                                | disable                | files  | autofix |
|-----------------------------------------------------|------------------------|--------|---------|
| [autopep8](https://github.com/hhatto/autopep8)      | `VALIDATE_AUTOPEP8`    | `*.py` | ❌*      |
| [black](https://github.com/psf/black)               | `VALIDATE_BLACK`       | `*.py` | ✅       |
| [flake8](https://github.com/PyCQA/flake8)           | `VALIDATE_FLAKE8`      | `*.py` | ❌       |
| [isort](https://github.com/PyCQA/isort)             | `VALIDATE_ISORT`       | `*.py` | ✅       |
| [pycodestyle](https://github.com/PyCQA/pycodestyle) | `VALIDATE_PYCODESTYLE` | `*.py` | ❌       |
| [pylint](https://github.com/PyCQA/pylint)           | `VALIDATE_PYLINT`      | `*.py` | ❌       |
| [mypy](https://github.com/python/mypy)              | `VALIDATE_MYPY`        | `*.py` | ❌       |

_Autopep8*_ - Formatting conflicts with black, so it is turned off.

## Development

Typical workflow is as follows:

```sh
$ make bootstrap

# Make some changes…

# Run locally:
$ npm start -- lint

# Run in docker:
$ make build run
```

## License

This project is licensed under the MIT License, see
[LICENSE.txt](LICENSE.txt) for full license details.

## Alternatives

- [super-linter](https://github.com/github/super-linter)
- [mega-linter](https://github.com/nvuillam/mega-linter)
- [git-lint](https://github.com/sk-/git-lint) (deprecated)
