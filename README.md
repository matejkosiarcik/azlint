# AZLint

> Lint everything From A to Z

## About

This project aims to bundle as many linters as possible in a single package
(mostly as a docker container) ready to be pulled and run with single command.

Project is in early development stage, anything can break at any moment.
So... don't depend on it yet (or not solely 😉).

### Included linters

- NodeJS
  - [eclint](https://github.com/jedmao/eclint)
  - [jsonlint](https://github.com/prantlf/jsonlint)
  - [bats-core](https://github.com/bats-core/bats-core)
  - [markdownlint](https://github.com/igorshubovych/markdownlint-cli)
  - [package-json-validator](https://github.com/gorillamania/package.json-validator)
  - [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate)
  - [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)
- Python
  - [yamllint](https://github.com/adrienverge/yamllint)
  - [bashate](https://github.com/openstack/bashate)
  - [requirements-validator](https://github.com/looking-for-a-job/requirements-validator.py)
  - [travislint](https://pypi.org/project/travislint/)
- Golang
  - [shfmt](https://github.com/mvdan/sh)
- Composer
  - [jsonlint](https://github.com/Seldaek/jsonlint)
  - [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)
- Other
  - [brew-bundle](https://github.com/Homebrew/homebrew-bundle) via [linuxbrew/brew](https://hub.docker.com/r/linuxbrew/brew)
  - [shellcheck](https://github.com/koalaman/shellcheck)
  - Shell dry run (in debian and alpine)
    - sh, ash, dash, bash, yash, zsh, ksh (mksh, loksh)
  - xmllint

## Usage

Run locally (not recommended, this is unoptimized and takes way more time than
other ways):

```sh
docker run -v "${PWD}:/project" -v "/var/run/docker.sock:/var/run/docker.sock" matejkosiarcik/azlint:latest
```

Run in gitlab-ci (must support docker-in-docker):

```yaml
job-azlint:
  image: matejkosiarcik/azlint:latest
  script:
    - azlint
```

Run in circle-ci:

```yaml
job-azlint:
  docker:
    - image: matejkosiarcik/azlint:latest
  steps:
    - checkout
    - setup_remote_docker
    - run: azlint
```

> Go to [hub.docker.com](https://hub.docker.com/r/matejkosiarcik/azlint) to see
all available tags beside `:latest`.

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
file for full license details.

## Future plans

- TODO: proselint
- TODO: rust
- TODO: ruby (mdlint, travis)
- TODO: clangformat lint? (when config files present)
- TODO: sass-lint, scss-lint, css-lint? (only when config file available)
- TODO: htmlhint, htmllint? (when config file present)
- TODO: jshint, jslint, google-closure-linter? (when config files present)
