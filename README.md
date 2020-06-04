# AZLint

> Lint everything From A to Z

## About

This project aims to bundle as many linters as possible in a single package
(mostly as a docker container) ready to be pulled and run with single command.

Project is in early development stage, anything can break at any moment.
So... don't depend on it yet (or not solely 😉).

### Included linters

## Usage

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

Note: not recommended, this takes way longer than previous methods

```sh
docker run -v "${PWD}:/project" -v "/var/run/docker.sock:/var/run/docker.sock" matejkosiarcik/azlint
```

> Go to [hub.docker.com](https://hub.docker.com/r/matejkosiarcik/azlint) to see
all available tags beside `:latest`.

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
file for full license details.

## Future plans

- TODO: rust component
- TODO: ruby component (mdlint, travis)
- TODO: proselint
- TODO: clangformat lint? (when config files present)
- TODO: sass-lint, scss-lint, css-lint? (only when config file available)
- TODO: htmlhint, htmllint? (when config file present)
- TODO: jshint, jslint, google-closure-linter? (when config files present)
