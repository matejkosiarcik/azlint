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
  - [Prepare you system](#prepare-you-system)
  - [Build & Run](#build--run)
- [License](#license)
- [Alternatives](#alternatives)

<!-- tocstop -->

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

### All files

| tool | links |                                                                                                                                       | disable                         | files | autofix |
|-----|---------------------------------------------------------------------------------------------------------------------------------------|---------------------------------|-------|---------|
| editorconfig-checker | [github](https://github.com/editorconfig-checker/editorconfig-checker) [docs](https://editorconfig-checker.github.io) | `VALIDATE_EDITORCONFIG_CHECKER` | `*`   | ❌       |
| eclint  | [github](https://github.com/jednano/eclint)                                                                                         | `VALIDATE_ECLINT`               | `*`   | ❌       |
| git check-ignore \[custom\]  | -                                                                                                               | `VALIDATE_GITIGNORE`            | `*`   | ✅       |
| jscpd | [github](https://github.com/kucherenko/jscpd)                                                                                        | `VALIDATE_JSCPD`                | `*`   | ❌       |

### General configs

| tool               | links                                                                                               | disable             | files                   | autofix |
|--------------------|-----------------------------------------------------------------------------------------------------|---------------------|-------------------------|---------|
| dotenv-linter      | [github](https://github.com/dotenv-linter/dotenv-linter) [docs](https://dotenv-linter.github.io)    | `VALIDATE_DOTENV`   | `*.env`                 | ❌       |
| jsonlint           | [github](https://github.com/prantlf/jsonlint) [try-online](https://prantlf.github.io/jsonlint)      | `VALIDATE_JSONLINT` | `*.json`                | ❌*      |
| prettier           | [github](https://github.com/prettier/prettier) [docs](https://prettier.io)                          | `VALIDATE_PRETTIER` | `*.{json,yml,css,html}` | ✅       |
| stoml              | [github](https://github.com/freshautomations/stoml)                                                 | `VALIDATE_STOML`    | `*.{cfg,ini,toml}`      | ❌       |
| tomljson (go-toml) | [github](https://github.com/pelletier/go-toml)                                                      | `VALIDATE_TOMLJSON` | `*.toml`                | ❌       |
| yamllint           | [github](https://github.com/adrienverge/yamllint) [docs](https://yamllint.readthedocs.io/en/stable) | `VALIDATE_YAMLLINT` | `*.{yml,yaml}`          | ❌       |

_Jsonlint*_ - Formatting conflicts with prettier, so it is turned off.

### Package manager files

#### Dry runners

These tools are not real "linters".
These tools are vanilla package managers, which we invoke with a `dry-run` flag to only _attempt_ to install dependencies without actually installing them.
This verifies the given config files are actually working in that respective package manager.

| tool             | links                                                                                                           | disable                     | files                                | autofix |
|------------------|-----------------------------------------------------------------------------------------------------------------|-----------------------------|--------------------------------------|---------|
| brew-bundle      | [github](https://github.com/Homebrew/homebrew-bundle) [manpage](https://docs.brew.sh/Manpage#bundle-subcommand) | `VALIDATE_BREW_BUNDLE`      | `Brewfile`                           | ❌       |
| composer-install | [docs](https://getcomposer.org)                                                                                 | `VALIDATE_COMPOSER_INSTALL` | `composer.json`                      | ❌       |
| pip-install      | [docs](https://pip.pypa.io/en/stable/cli/pip_install)                                                           | `VALIDATE_PIP_INSTALL`      | `requirements.txt`                   | ❌       |
| npm-install      | [docs](https://docs.npmjs.com/cli/v9/commands/npm-install)                                                      | `VALIDATE_NPM_INSTALL`      | `package.json`                       | ❌       |
| npm-ci           | [docs](https://docs.npmjs.com/cli/v9/commands/npm-ci)                                                           | `VALIDATE_NPM_CI`           | `package.json` & `package-lock.json` | ❌       |

#### Validators

Extra validators for package-manager files.
These check additional rules, which are recommended, but not required for the config files to be valid.

| tool                   | links                                                                                                                                      | disable                       | files           | autofix |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------|-----------------|---------|
| composer-normalize     | [github](https://github.com/ergebnis/composer-normalize) [blogpost](https://localheinz.com/articles/2018/01/15/normalizing-composer.json/) | `VALIDATE_COMPOSER_NORMALIZE` | `composer.json` | ✅       |
| composer-validate      | [docs](https://getcomposer.org/doc/03-cli.md#validate)                                                                                     | `VALIDATE_COMPOSER_VALIDATE`  | `composer.json` | ❌       |
| package-json-validator | [github](https://github.com/gorillamania/package.json-validator)                                                                           | `VALIDATE_PACKAGE_JSON`       | `package.json`  | ❌       |

### CI/CD services

| tool               | links                                                                                                     | disable                      | files                  | autofix |
|--------------------|-----------------------------------------------------------------------------------------------------------|------------------------------|------------------------|---------|
| CircleCI CLI lint  | [docs](https://circleci.com/docs/2.0/local-cli) [github](https://github.com/CircleCI-Public/circleci-cli) | `VALIDATE_CIRCLECI_VALIDATE` | `.circleci/config.yml` | ❌       |
| gitlab-ci-lint     | [github](https://github.com/BuBuaBu/gitlab-ci-lint)                                                       | `VALIDATE_GITLABCI_LINT`     | `.gitlab-ci.yml`       | ❌       |
| gitlab-ci-validate | [github](https://github.com/pradel/gitlab-ci-validate)                                                    | `VALIDATE_GITLABCI_VALIDATE` | `.gitlab-ci.yml`       | ❌       |
| Travis CI CLI lint | [github](https://github.com/travis-ci/travis.rb#lint)                                                     | `VALIDATE_TRAVIS_LINT`       | `.travis.yml`          | ❌       |

### Makefiles

| tool      | links                                                                                         | disable              | files           | autofix |
|-----------|-----------------------------------------------------------------------------------------------|----------------------|-----------------|---------|
| checkmake | [github](https://github.com/mrtazz/checkmake)                                                 | `VALIDATE_CHECKMAKE` | `Makefile` etc. | ❌       |
| BSD Make  | [manpage](https://man.netbsd.org/make.1)                                                      | `VALIDATE_BMAKE`     | `Makefile` etc. | ❌       |
| GNU Make  | [docs](https://www.gnu.org/software/make) [manpage](https://www.gnu.org/software/make/manual) | `VALIDATE_GMAKE`     | `Makefile` etc. | ❌       |

### Dockerfiles

| tool           | links                                                                                            | disable                   | files             | autofix |
|----------------|--------------------------------------------------------------------------------------------------|---------------------------|-------------------|---------|
| dockerfilelint | [github](https://github.com/replicatedhq/dockerfilelint) [try-online](https://www.fromlatest.io) | `VALIDATE_DOCKERFILELINT` | `Dockerfile` etc. | ❌       |
| hadolint       | [github](https://github.com/hadolint/hadolint)                                                   | `VALIDATE_HADOLINT`       | `Dockerfile` etc. | ❌       |

### XML, HTML, SVG

| tool     | links                                                                                                                                                | disable             | files          | autofix |
|----------|------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------|----------------|---------|
| HTMLHint | [github](https://github.com/HTMLHint/HTMLHint)                                                                                                       | `VALIDATE_HTMLHINT` | `*.{html,htm}` | ❌       |
| htmllint | [github](https://github.com/htmllint/htmllint)                                                                                                       | `VALIDATE_HTMLLINT` | `*.{html,htm}` | ❌       |
| SVGLint  | [github](https://github.com/birjolaxew/svglint)                                                                                                      | `VALIDATE_SVGLINT`  | `*.svg`        | ❌       |
| xmllint  | [gitlab](https://gitlab.gnome.org/GNOME/libxml2) [docs](http://www.xmlsoft.org) [manpage](https://gnome.pages.gitlab.gnome.org/libxml2/xmllint.html) | `VALIDATE_XMLLINT`  | `*.xml`        | ✅       |

### Documentation (MarkDown, Plain Text)

| tool                | links                                                  | disable                        | files        | autofix |
|---------------------|--------------------------------------------------------|--------------------------------|--------------|---------|
| markdown-link-check | [github](https://github.com/tcort/markdown-link-check) | `VALIDATE_MARKDOWN_LINK_CHECK` | `*.md`       | ❌       |
| markdownlint        | [github](https://github.com/DavidAnson/markdownlint)   | `VALIDATE_MARKDOWNLINT`        | `*.md`       | ✅       |
| markdownlint (mdl)  | [github](https://github.com/markdownlint/markdownlint) | `VALIDATE_MDL`                 | `*.md`       | ❌       |
| proselint           | [github](https://github.com/amperser/proselint)        | `VALIDATE_PROSELINT`           | `*.{md,txt}` | ❌       |

### Shells

| tool                                                  | disable                  | files       | autofix |
|-------------------------------------------------------|--------------------------|-------------|---------|
| [bashate](https://github.com/openstack/bashate)       | `VALIDATE_BASHATE`       | `*.sh` etc. | ❌       |
| [bats-core](https://github.com/bats-core/bats-core)   | `VALIDATE_BATS`          | `*.bats`    | ❌       |
| [shellcheck](https://github.com/koalaman/shellcheck)  | `VALIDATE_SHELLCHECK`    | `*.sh` etc. | ❌       |
| [shellharden](https://github.com/anordal/shellharden) | `VALIDATE_SHELLHARDEN`   | `*.sh` etc. | ✅       |
| [shfmt](https://github.com/mvdan/sh)                  | `VALIDATE_SHFMT`         | `*.sh` etc. | ✅       |
| [hush](https://hush-shell.github.io)                  | `VALIDATE_HUSH`          | `*.hush`    | ❌       |
| Custom dry runner                                     | `VALIDATE_SHELL_DRY_RUN` | `*.sh` etc. | ❌       |

The following shells are checked in custom dry runner:

| tool                                | links                                    |
|-------------------------------------|------------------------------------------|
| Linux port of OpenBSD's ksh (loksh) | [github](https://github.com/dimkr/loksh) |
| Portable OpenBSD ksh (oksh)         | [github](https://github.com/ibara/oksh)  |

### Python

| tool        | links                                                                                                                                       | disable                | files  | autofix |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------|------------------------|--------|---------|
| autopep8    | [github](https://github.com/hhatto/autopep8) [pypi](https://pypi.org/project/autopep8)                                                      | `VALIDATE_AUTOPEP8`    | `*.py` | ❌*      |
| black       | [github](https://github.com/psf/black) [docs](https://black.readthedocs.io/en/stable) [pypi](https://pypi.org/project/black)                | `VALIDATE_BLACK`       | `*.py` | ✅       |
| flake8      | [github](https://github.com/PyCQA/flake8) [docs](https://flake8.pycqa.org/en/latest) [pypi](https://pypi.org/project/flake8)                | `VALIDATE_FLAKE8`      | `*.py` | ❌       |
| isort       | [github](https://github.com/PyCQA/isort) [docs](https://pycqa.github.io/isort) [pypi](https://pypi.org/project/isort)                       | `VALIDATE_ISORT`       | `*.py` | ✅       |
| pycodestyle | [github](https://github.com/PyCQA/pycodestyle) [docs](https://pycodestyle.pycqa.org/en/latest) [pypi](https://pypi.org/project/pycodestyle) | `VALIDATE_PYCODESTYLE` | `*.py` | ❌       |
| pylint      | [github](https://github.com/PyCQA/pylint) [docs](https://pylint.readthedocs.io/en/latest) [pypi](https://pypi.org/project/pylint)           | `VALIDATE_PYLINT`      | `*.py` | ❌       |
| mypy        | [github](https://github.com/python/mypy) [docs](https://www.mypy-lang.org) [pypi](https://pypi.org/project/mypy)                            | `VALIDATE_MYPY`        | `*.py` | ❌       |

_Autopep8*_ - Formatting conflicts with black, so it is turned off.

## Development

### Prepare you system

In order to develop on this project, first install required system packages.

- If you are on macOS and have [HomeBrew](https://brew.sh) available,
  just run `brew bundle install` in project's root directory.
  This will install all packages from `Brewfile` (learn more about [HomeBrew Bundle](https://github.com/Homebrew/homebrew-bundle)).
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

This project is licensed under the MIT License, see
[LICENSE.txt](LICENSE.txt) for full license details.

## Alternatives

- [super-linter](https://github.com/github/super-linter)
- [mega-linter](https://github.com/nvuillam/mega-linter)
- [git-lint](https://github.com/sk-/git-lint) (deprecated)
