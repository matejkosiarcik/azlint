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
- Python
  - [yamllint](https://github.com/adrienverge/yamllint)
  - [bashate](https://github.com/openstack/bashate)
  - [requirements-validator](https://github.com/looking-for-a-job/requirements-validator.py)
  - [travislint](https://pypi.org/project/travislint/)
- Golang
  - [shfmt](https://github.com/mvdan/sh)
- Composer
  - [composer-validate](https://getcomposer.org/doc/03-cli.md#validate)
  - [composer-normalize](https://github.com/ergebnis/composer-normalize)
  - [jsonlint](https://github.com/Seldaek/jsonlint)
- System (Alpine/Debian)
  - sh, ash, dash, bash, yash, zsh, ksh (mksh, loksh)
  - xmllint
- Other
  - [brew-bundle](https://github.com/Homebrew/homebrew-bundle) via [linuxbrew/brew](https://hub.docker.com/r/linuxbrew/brew)
  - [shellcheck](https://github.com/koalaman/shellcheck)
  - [hadolint](https://github.com/hadolint/hadolint)

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

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
file for full license details.

## Alternatives

Similar project I found is [git-lint](https://github.com/sk-/git-lint), but
very python oriented.

## Future plans

- TODO: haskell component? (shellcheck, hadolint)
- TODO: rust component
- TODO: ruby component (mdlint, travis)
- TODO: proselint
- TODO: clangformat lint? (when config files present)
- TODO: sass-lint, scss-lint, css-lint? (only when config file available)
- TODO: htmlhint, htmllint? (when config file present)
- TODO: jshint, jslint, google-closure-linter? (when config files present)
