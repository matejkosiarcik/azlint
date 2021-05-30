# AZLint

> Lint everything From A to Z

[![dockerhub automated status](https://img.shields.io/docker/cloud/automated/matejkosiarcik/azlint)](https://hub.docker.com/r/matejkosiarcik/azlint/builds)
[![dockerhub version](https://img.shields.io/docker/v/matejkosiarcik/azlint?label=dockerhub&sort=semver)](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated)


<!-- toc -->

- [About](#about)
- [Usage](#usage)
  - [Locally](#locally)
  - [gitlab-ci](#gitlab-ci)
  - [circle-ci](#circle-ci)
- [Configuration](#configuration)
- [Included linters](#included-linters)
  - [General](#general)
  - [Configs](#configs)
  - [CI](#ci)
  - [Make](#make)
  - [Docker](#docker)
  - [Markup](#markup)
  - [Documentation](#documentation)
  - [Shell](#shell)
  - [Python](#python)
- [Development](#development)
- [License](#license)
- [Alternatives and Drawbacks](#alternatives-and-drawbacks)

<!-- tocstop -->

## About

The main purpose of this tool is to bundle as many linters \(I use\) as
possible into a single docker image.

I see it as a complement to
[super-linter](https://github.com/github/super-linter) and
[MegaLinter](https://github.com/nvuillam/mega-linter).
These tools are awesome, but are missing some linters that are bundled into
_azlint_.

Also _azlint_ has an optional **formatting** mode 🤯, which applies suggested
fixes \(from supported linters\) to your files.

All that said, AZLint is mostly for my personal usage.
But feel free to use it and report any found issues 😉.

## Usage

![azlint demo](./doc/demo.gif)

> Go to dockerhub's [tags](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated) to see all available tags
>
> Or see github's [releases](https://github.com/matejkosiarcik/azlint/releases) for all project releases

### Locally

To **lint** files in current folder:

```sh
docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint
```

To **format** files in current folder:

```sh
docker run -itv "$PWD:/project" matejkosiarcik/azlint fmt
```

When in doubt, get help:

```sh
$ docker run matejkosiarcik/azlint --help
usage: azlint [-h] [-V] [-c] {lint,fmt} ...

positional arguments:
  {lint,fmt}
    lint              Lint files (default)
    fmt               Fix files

optional arguments:
  -h, --help          show this help message and exit
  -V, --version       show program's version number and exit
  -c, --only-changed  Analyze only changed files (on current git branch)
```

### gitlab-ci

```yaml
azlint:
  image: matejkosiarcik/azlint
  script:
    - lint
```

### circle-ci

```yaml
azlint:
  docker:
    - image: matejkosiarcik/azlint
  steps:
    - checkout
    - run: lint
```

## Configuration

AZLint expects to find config files in the root directory you are calling from.
Eg. repository root.
AZLint relies on bundled linters to pick their own config file automatically.

You can turn of linters/formatters using environment variables. Example:
`docker run -itv "$PWD:/project:ro" -e VALIDATE_FOO=false matejkosiarcik/azlint`.
Where `VALIDATE_FOO` can be found in the following section.

## Included linters

### General

| tool                                                                                 | disable                 | files |
| ------------------------------------------------------------------------------------ | ----------------------- | ----- |
| [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker) | `VALIDATE_EDITORCONFIG` | `*`   |

### Configs

| tool                                                                             | disable                       | files                      |
| -------------------------------------------------------------------------------- | ----------------------------- | -------------------------- |
| [composer-normalize](https://github.com/ergebnis/composer-normalize)             | `VALIDATE_COMPOSER_NORMALIZE` | `composer.json`            |
| [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)              | `VALIDATE_COMPOSER_VALIDATE`  | `composer.json`            |
| [dotenv-linter](https://github.com/dotenv-linter/dotenv-linter)                  | `VALIDATE_DOTENV`             | `*.env`                    |
| [jsonlint](https://github.com/prantlf/jsonlint)                                  | `VALIDATE_JSONLINT`           | `*.json` etc.              |
| [package-json-validator](https://github.com/gorillamania/package.json-validator) | `VALIDATE_PACKAGE_JSON`       | `package.json`             |
| [prettier](https://github.com/prettier/prettier)                                 | `VALIDATE_PRETTIER`           | `*.{json,yml,md,css,html}` |
| [tomljson](https://github.com/pelletier/go-toml)                                 | `VALIDATE_TOMLJSON`           | `*.toml`                   |
| [yamllint](https://github.com/adrienverge/yamllint)                              | `VALIDATE_YAMLLINT`           | `*.{yml,yaml}`             |

### CI

| tool                                                               | disable                    | files                  |
| ------------------------------------------------------------------ | -------------------------- | ---------------------- |
| [circle-ci lint](https://circleci.com/docs/2.0/local-cli)          | `VALIDATE_CIRCLE_VALIDATE` | `.circleci/config.yml` |
| [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)        | `VALIDATE_GITLAB_LINT`     | `.gitlab-ci.yml`       |
| [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate) | `VALIDATE_GITLAB_VALIDATE` | `.gitlab-ci.yml`       |
| [travis-lint](https://github.com/travis-ci/travis.rb#lint)         | `VALIDATE_TRAVIS_LINT`     | `.travis.yml`          |

### Make

| tool                                             | disable              | files           |
| ------------------------------------------------ | -------------------- | --------------- |
| [bmake](https://man.netbsd.org/make.1)           | `VALIDATE_BMAKE`     | `Makefile` etc. |
| [checkmake](https://github.com/mrtazz/checkmake) | `VALIDATE_CHECKMAKE` | `Makefile` etc. |
| [gmake](https://www.gnu.org/software/make/)      | `VALIDATE_GMAKE`     | `Makefile` etc. |

### Docker

| tool                                                             | disable                   | files             |
| ---------------------------------------------------------------- | ------------------------- | ----------------- |
| [dockerfilelint](https://github.com/replicatedhq/dockerfilelint) | `VALIDATE_DOCKERFILELINT` | `Dockerfile` etc. |
| [hadolint](https://github.com/hadolint/hadolint)                 | `VALIDATE_HADOLINT`       | `Dockerfile` etc. |

### Markup

| tool                                             | disable             | files          |
| ------------------------------------------------ | ------------------- | -------------- |
| [htmlhint](https://github.com/HTMLHint/HTMLHint) | `VALIDATE_HTMLHINT` | `*.{html,htm}` |
| [htmllint](https://github.com/htmllint/htmllint) | `VALIDATE_HTMLLINT` | `*.{html,htm}` |
| [svglint](https://github.com/birjolaxew/svglint) | `VALIDATE_SVGLINT`  | `*.svg`        |
| [xmllint](http://www.xmlsoft.org)                | `VALIDATE_XMLLINT`  | `*.xml`        |

### Documentation

| tool                                                                | disable                        | files  |
| ------------------------------------------------------------------- | ------------------------------ | ------ |
| [markdown-link-check](https://github.com/tcort/markdown-link-check) | `VALIDATE_MARKDOWN_LINK_CHECK` | `*.md` |
| [markdownlint](https://github.com/DavidAnson/markdownlint)          | `VALIDATE_MARKDOWNLINT`        | `*.md` |
| [mdl](https://github.com/markdownlint/markdownlint)                 | `VALIDATE_MDL`                 | `*.md` |

### Shell

| tool                                                  | disable                | files       |
| ----------------------------------------------------- | ---------------------- | ----------- |
| [bashate](https://github.com/openstack/bashate)       | `VALIDATE_BASHATE`     | `*.sh` etc. |
| [bats-core](https://github.com/bats-core/bats-core)   | `VALIDATE_BATS`        | `*.bats`    |
| [shellcheck](https://github.com/koalaman/shellcheck)  | `VALIDATE_SHELLCHECK`  | `*.sh` etc. |
| [shellharden](https://github.com/anordal/shellharden) | `VALIDATE_SHELLHARDEN` | `*.sh` etc. |
| [shfmt](https://github.com/mvdan/sh)                  | `VALIDATE_SHFMT`       | `*.sh` etc. |

### Python

| tool                                                | disable                | files  |
| --------------------------------------------------- | ---------------------- | ------ |
| [autopep8](https://github.com/hhatto/autopep8)      | `VALIDATE_AUTOPEP8`    | `*.py` |
| [black](https://github.com/psf/black)               | `VALIDATE_BLACK`       | `*.py` |
| [flake8](https://github.com/PyCQA/flake8)           | `VALIDATE_FLAKE8`      | `*.py` |
| [isort](https://github.com/PyCQA/isort)             | `VALIDATE_ISORT`       | `*.py` |
| [pycodestyle](https://github.com/PyCQA/pycodestyle) | `VALIDATE_PYCODESTYLE` | `*.py` |
| [pylint](https://github.com/PyCQA/pylint/)          | `VALIDATE_PYLINT`      | `*.py` |
| [mypy](https://github.com/python/mypy)              | `VALIDATE_MYPY`        | `*.py` |

<!-- List of unsuitable tools -->
<!-- [stoml](https://github.com/freshautomations/stoml) - Can't deal with "'" in toml section headings (sometimes used in Cargo.toml) -->

## Development

Typical workflow is as follows:

```sh
# ... make some changes ...
$ make build
$ make run
```

## License

This project is licensed under the LGPLv3 License, see
[LICENSE.txt](LICENSE.txt) for full license details.

## Alternatives and Drawbacks

AZLint currently exits on first error (in _lint_ mode).
This can be problematic if you expect to report all the errors which can be found by included linters.
There are much more mature projects, which do not share this drawback as:

- [super-linter](https://github.com/github/super-linter)
- [mega-linter](https://github.com/nvuillam/mega-linter)
- [git-lint](https://github.com/sk-/git-lint) (deprecated)
