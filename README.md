# AZLint

> Lint everything From A to Z

<!-- toc -->

- [About](#about)
  - [Included linters](#included-linters)
- [Usage](#usage)
  - [gitlab-ci](#gitlab-ci)
  - [circle-ci](#circle-ci)
  - [Local usage](#local-usage)
- [Development](#development)
- [License](#license)
- [Alternatives](#alternatives)

<!-- tocstop -->

## About

This project works as a complement to github's
[super-linter](https://github.com/github/super-linter) and similar project
[mega-linter](https://github.com/nvuillam/mega-linter).

While these tools are awesome, and I recommend using them.
But they don't contain every linter in existence.
This is probably an impossible job.

So this tool bundles linters that are important to me, that are missing from
*super-linter* and *mega-linter*.

### Included linters

- NodeJS
  - [jsonlint](https://github.com/prantlf/jsonlint)
    - because this accepts json5, which is not standard
  - [bats-core](https://github.com/bats-core/bats-core)
    - dry run bats files, checks only syntax, does not run the tests
  - [package-json-validator](https://github.com/gorillamania/package.json-validator)
    - check recommended fields are included for non-private packages
  - [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate)
    - validates `.gitlab-ci.yml`
  - [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)
    - validates `.gitlab-ci.yml`
  - [htmllint](https://github.com/htmllint/htmllint)
    - both super-linter and mega-linter only have
      [HtmlHint](https://github.com/HTMLHint/HTMLHint)
- Python
  - [bashate](https://github.com/openstack/bashate)
    - validate shell files for bash and posix/bourne shell
- Composer
  - [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)
    - builtin composer validator
  - [composer-normalize](https://github.com/ergebnis/composer-normalize)
    - 3rd party `composer.json` normalizer
- Ruby
  - [markdownlint](https://github.com/markdownlint/markdownlint)
    - both super-linter and mega-linter only have this other
      [markdownlint](https://github.com/DavidAnson/markdownlint) which is
      NodeJS based markdown linter, while the functionalities are overlapping
      to great extent, I think it is useful to have this tool as well
  - [travis-lint](https://github.com/travis-ci/travis.rb#lint)
    - validate `.travis.yml`
- Golang
  - [stoml](https://github.com/freshautomations/stoml)
    - validate `.toml` files
  - [tomljson](https://github.com/pelletier/go-toml)
    - validate `.toml` files

## Usage

> Go to [hub.docker.com](https://hub.docker.com/r/matejkosiarcik/azlint) to see
> all available tags beside `:latest`.

### gitlab-ci

```yaml
job-azlint:
  image: matejkosiarcik/azlint
  script:
    - azlint
```

### circle-ci

```yaml
job-azlint:
  docker:
    - image: matejkosiarcik/azlint
  steps:
    - checkout
    - run: azlint
```

### Local usage

Note: not recommended, currently this takes way longer than previous methods

```sh
docker run -itv "${PWD}:/project" matejkosiarcik/azlint
```

## Configuration

You can turn of linters using environment variables. Example:
`docker run -itv "${PWD}:/project" -e VALIDATE_FOO=false matejkosiarcik/azlint`.

Where VALIDATE_FOO is one of following:

- `VALIDATE_BASHATE`
- `VALIDATE_BATS`
- `VALIDATE_CIRCLE_VALIDATE`
- `VALIDATE_COMPOSER_NORMALIZE`
- `VALIDATE_COMPOSER_VALIDATE`
- `VALIDATE_GITLAB_LINT`
- `VALIDATE_GITLAB_VALIDATE`
- `VALIDATE_HTMLLINT`
- `VALIDATE_JSONLINT`
- `VALIDATE_MDL`
- `VALIDATE_PACKAGE_JSON`
- `VALIDATE_STOML`
- `VALIDATE_SVGLINT`
- `VALIDATE_TOMLJSON`
- `VALIDATE_TRAVIS_LINT`

## Development

Typical workflow is as follows:

```sh
make build # build docker image
make run # lint current project
```

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
for full license details.

## Alternatives

This project does not have any competitor per se.
It is just a collection of linters I like.

For repetition, I recommend checking out
[super-linter](https://github.com/github/super-linter) and
[mega-linter](https://github.com/nvuillam/mega-linter) beforehand.
