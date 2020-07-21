# AZLint

> Lint everything From A to Z

<!-- toc -->

- [About](#about)
  - [Included linters](#included-linters)
- [Usage](#usage)
  - [gitlab-ci](#gitlab-ci)
  - [circle-ci](#circle-ci)
  - [Local install](#local-install)
  - [Local docker](#local-docker)
- [Development](#development)
- [License](#license)
- [Alternatives](#alternatives)
- [Future plans](#future-plans)

<!-- tocstop -->

## About

This project's goal is to bundle as many linters as possible in a docker container.
This makes it really easy to adopt for your project on a CI/CD server
(or even locally during development).

Project is in early development stage, though versioned releases are already available.

### Included linters

- NodeJS
  - [eclint](https://github.com/jedmao/eclint)
  - [jsonlint](https://github.com/prantlf/jsonlint)
  - [bats-core](https://github.com/bats-core/bats-core)
  - [markdownlint](https://github.com/igorshubovych/markdownlint-cli)
  - [package-json-validator](https://github.com/gorillamania/package.json-validator)
  - [gitlab-ci-validate](https://github.com/pradel/gitlab-ci-validate)
  - [gitlab-ci-lint](https://github.com/BuBuaBu/gitlab-ci-lint)
  - [dockerfilelint](https://github.com/replicatedhq/dockerfilelint)
- Python
  - [yamllint](https://github.com/adrienverge/yamllint)
  - [bashate](https://github.com/openstack/bashate)
  - [travislint](https://pypi.org/project/travislint/)
- Composer
  - [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)
  - [composer-normalize](https://github.com/ergebnis/composer-normalize)
  - [jsonlint](https://github.com/Seldaek/jsonlint)
- Ruby
  - [markdownlint](https://github.com/markdownlint/markdownlint)
- Rust
  - [jsonprima](https://github.com/jsonprima/jsonprima)
- Golang
  - [shfmt](https://github.com/mvdan/sh)
  - [stoml](https://github.com/freshautomations/stoml)
- Swift
  - [swiftlint](https://github.com/realm/SwiftLint)
- Haskell
  - [shellcheck](https://github.com/koalaman/shellcheck)
  - [hadolint](https://github.com/hadolint/hadolint)
- System (Alpine & Debian)
  - sh, ash, dash, bash, yash, ksh (mksh, loksh), zsh
  - xmllint
- Other
  - [brew-bundle](https://github.com/Homebrew/homebrew-bundle) via [linuxbrew/brew](https://hub.docker.com/r/linuxbrew/brew)
  - bash
  - zsh

## Usage

> Go to [hub.docker.com](https://hub.docker.com/r/matejkosiarcik/azlint) to see
all available tags beside `:latest`.

### gitlab-ci

Note: must support docker-in-docker, more at [docs.gitlab.com](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker-workflow-with-docker-executor).

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
    - setup_remote_docker
    - run: azlint
```

### Local install

Note: Depends on NodeJS (subject to change)

```sh
git clone git@github.com:matejkosiarcik/azlint.git # or https://github.com/matejkosiarcik/azlint.git
cd azlint
DESTDIR=<directory in your $PATH> make install
azlint # runs azlint in current directory
```

### Local docker

Note: not recommended, currently this takes way longer than previous methods

```sh
docker run -v "${PWD}:/project" -v "/var/run/docker.sock:/var/run/docker.sock" matejkosiarcik/azlint
```

## Development

Typical workflow is as follows:

```sh
make bootstrap # install dependencies
## change source here ##
make build # build runner and components
make run # lint current project
```

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
file for full license details.

## Alternatives

Obvious alternative is
[github super-linter](https://github.com/github/super-linter).
However it is tied to github and you can't use it locally.

Smaller project I found is [git-lint](https://github.com/sk-/git-lint).
It is very python oriented.

## Future plans

- TODO: rewrite runner in rust
- TODO: rust component
- TODO: ruby component (mdlint, travis)
- TODO: proselint
- TODO: clangformat lint? (when config files present)
- TODO: sass-lint, scss-lint, css-lint? (only when config file available)
- TODO: htmlhint, htmllint? (when config file present)
- TODO: jshint, jslint, google-closure-linter? (when config files present)
- TODO: dotenv linter
- TODO: use go dep or go.mod files (+ apply dependabot)
