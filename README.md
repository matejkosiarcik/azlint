# AZLint

> Lint everything From A to Z

## About

This project aims to bundle as many linters as possible in a single package
(mostly as a docker container) ready to be pulled and run with single command.

Project is in early development stage, anything can break at any moment.
So... don't depend on it yet (or not solely 😉).

## Usage

Run locally (not recommended, this is unoptimized and takes way more time than
other ways):

```sh
docker run -v "${PWD}:/project" -v "/var/run/docker.sock:/var/run/docker.sock" matejkosiarcik/azlint:dev
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

## Included linters

More info coming soon.

## License

This project is licensed under the MIT License, see [LICENSE.txt](LICENSE.txt)
file for full license details.

## Future plans

- TODO: linuxbrew
- TODO: proselint
- TODO: rust
- TODO: ruby (mdlint)
- TODO: clangformat lint? (when config files present)
- TODO: sass-lint, scss-lint, css-lint? (only when config file available)
- TODO: htmlhint, htmllint? (when config file present)
- TODO: jshint, jslint, google-closure-linter? (when config files present)
