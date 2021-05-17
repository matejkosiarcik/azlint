# AZLint

> Lint everything From A to Z

<!-- toc -->

- [About](#about)
  - [Included linters](#included-linters)
- [Usage](#usage)
  - [Locally](#locally)
  - [gitlab-ci](#gitlab-ci)
  - [circle-ci](#circle-ci)
  - [Full usage](#full-usage)
- [Configuration](#configuration)
- [Development](#development)
- [License](#license)
- [Alternatives](#alternatives)

<!-- tocstop -->

## About

The main purpose of this tool is to bundle as many linters \(I use\) as
possible into a single docker image.

I see it as a complement to
[super-linter](https://github.com/github/super-linter) and
[MegaLinter](https://github.com/nvuillam/mega-linter).
These tools are awesome, but are missing some linters that are bundled into
_azlint_.

Also _azlint_ has an optional **formatting** mode 🤯, that applies suggested
fixes \(from supported linters\) to your files.

### Included linters

- From nodeJS
  - [jsonlint](https://github.com/prantlf/jsonlint)
    - validates _json_ and _json5_ files
  - [bats-core](https://github.com/bats-core/bats-core)
    - validates _bats_ files in dry-run mode
  - [package-json-validator](https://github.com/gorillamania/package.json-validator)
    - checks recommended fields in `package.json` files
  - [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate)
    - validates `.gitlab-ci.yml`
  - [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)
    - validates `.gitlab-ci.yml`
  - [htmllint](https://github.com/htmllint/htmllint)
    - validates _html_ files
  - [htmlhint](https://github.com/HTMLHint/HTMLHint)
    - validates _html_ files
  - [prettier](https://github.com/prettier/prettier)
    - validates "support" files (_json_, _yaml_, _markdown_, _css_, _html_)
  - [markdownlint](https://github.com/DavidAnson/markdownlint)
    - validates _markdown_ files
  - [markdown-link-check](https://github.com/tcort/markdown-link-check)
    - validates links and URLs inside of _markdown_ files
  - [dockerfilelint](https://github.com/replicatedhq/dockerfilelint)
    - validates `Dockerfile`s
  - [svglint](https://github.com/birjolaxew/svglint)
    - validates _svg_ images
- From python
  - [bashate](https://github.com/openstack/bashate)
    - validates _shell_ files
  - [isort](https://github.com/PyCQA/isort)
    - sorts _python_ imports
  - [black](https://github.com/psf/black)
    - validates _python_ files
  - [flake8](https://github.com/PyCQA/flake8)
    - validates _python_ files
  - [autopep8](https://github.com/hhatto/autopep8)
    - validates _python_ files
  - [pylint](https://github.com/PyCQA/pylint/)
    - validates _python_ files
  - [pycodestyle](https://github.com/PyCQA/pycodestyle)
    - validates _python_ files
  - [yamllint](https://github.com/adrienverge/yamllint)
    - validates _yaml_ files
- From composer
  - [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)
    - builtin composer validator
  - [composer-normalize](https://github.com/ergebnis/composer-normalize)
    - 3rd-party `composer.json` normalizer
- From ruby
  - [markdownlint](https://github.com/markdownlint/markdownlint)
    - both super-linter and mega-linter only have this other
      [markdownlint](https://github.com/DavidAnson/markdownlint) which is
      NodeJS based markdown linter, while the functionalities are overlapping
      to great extent, I think it is useful to have this tool as well
  - [travis-lint](https://github.com/travis-ci/travis.rb#lint)
    - validates `.travis.yml`
- From golang
  - [stoml](https://github.com/freshautomations/stoml)
    - validates _toml_ files
  - [tomljson](https://github.com/pelletier/go-toml)
    - validates _toml_ files
  - [shfmt](https://github.com/mvdan/sh)
    - validates _shell_ files
  - [checkmake](https://github.com/mrtazz/checkmake)
    - validates `Makefile`s
  - [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker)
    - validates _all_ files
- From haskell
  - [shellcheck](https://github.com/koalaman/shellcheck)
    - validates _shell_ files
  - [hadolint](https://github.com/hadolint/hadolint)
    - validates `Dockerfile`s
- From rust
  - [shellharden](https://github.com/anordal/shellharden)
    - validates _shell_ files
  - [dotenv-linter](https://github.com/dotenv-linter/dotenv-linter)
    - validates `.env` files
- Others
  - [circle-ci lint](https://circleci.com/docs/2.0/local-cli)
    - validates `.circleci/config.yml`
  - [gmake](https://www.gnu.org/software/make/) and [bmake](https://man.netbsd.org/make.1)
    - validates `Makefile`s in dry-run mode
  - [xmllint](http://www.xmlsoft.org)
    - validate _xml_ files

## Usage

> Go to dockerhub's [tags](https://hub.docker.com/r/matejkosiarcik/azlint/tags?page=1&ordering=last_updated) to see all available tags
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

### gitlab-ci

```yaml
azlint:
  image: matejkosiarcik/azlint
  script:
    - azlint
```

### circle-ci

```yaml
azlint:
  docker:
    - image: matejkosiarcik/azlint
  steps:
    - checkout
    - run: azlint
```

### Full usage

```sh
$ docker run -itv "$PWD:/project:ro" matejkosiarcik/azlint --help
azlint [options]... command

Options
-h, --help    print help message

Command:
lint          lint files with available linters (default)
fmt           format files with available formatters
```

## Configuration

AZLint expects to have config files in the root directory you are calling from.
Eg. repository root.
AZLint relies on bundled linters to pick their own config file automatically.

You can turn of linters/formatters using environment variables. Example:
`docker run -itv "$PWD:/project:ro" -e VALIDATE_FOO=false matejkosiarcik/azlint`.
Where `VALIDATE_FOO` is one of following:

- `VALIDATE_AUTOPEP8`
- `VALIDATE_BASHATE`
- `VALIDATE_BATS`
- `VALIDATE_BLACK`
- `VALIDATE_BMAKE`
- `VALIDATE_CHECKMAKE`
- `VALIDATE_CIRCLE_VALIDATE`
- `VALIDATE_COMPOSER_NORMALIZE`
- `VALIDATE_COMPOSER_VALIDATE`
- `VALIDATE_DOCKERFILELINT`
- `VALIDATE_DOTENV`
- `VALIDATE_EDITORCONFIG`
- `VALIDATE_FLAKE8`
- `VALIDATE_GITLAB_LINT`
- `VALIDATE_GITLAB_VALIDATE`
- `VALIDATE_GMAKE`
- `VALIDATE_HADOLINT`
- `VALIDATE_HTMLHINT`
- `VALIDATE_HTMLLINT`
- `VALIDATE_ISORT`
- `VALIDATE_JSONLINT`
- `VALIDATE_MARKDOWNLINT`
- `VALIDATE_MARKDOWN_LINK_CHECK`
- `VALIDATE_MDL`
- `VALIDATE_PACKAGE_JSON`
- `VALIDATE_PRETTIER`
- `VALIDATE_PYCODESTYLE`
- `VALIDATE_PYLINT`
- `VALIDATE_SHELLCHECK`
- `VALIDATE_SHELLHARDEN`
- `VALIDATE_SHFMT`
- `VALIDATE_STOML`
- `VALIDATE_SVGLINT`
- `VALIDATE_TOMLJSON`
- `VALIDATE_TRAVIS_LINT`
- `VALIDATE_XMLLINT`
- `VALIDATE_YAMLLINT`

## Development

Typical workflow is as follows:

```sh
# ... make some changes ...
$ make build
$ make run-fmt run-lint
```

## License

This project is licensed under the LGPLv3 License, see
[LICENSE.txt](LICENSE.txt) for full license details.

## Alternatives

This project is just my personal collection of linters I like.
That said, there are similar and much more mature projects such as:

- [super-linter](https://github.com/github/super-linter)
- [mega-linter](https://github.com/nvuillam/mega-linter)
- [git-lint](https://github.com/sk-/git-lint) (deprecated)

<!-- Personal TODO:
yapf
yamlfmt
-->
