# AZLint

> Lint everything From A to Z

## About

This project aims to bundle as many linters as possible in a single package
(mostly as a docker container) ready to be pulled and run with single command.

Project is in early development stage, anything can break at any moment.
So... don't depend on it yet (or not solely 😉).

## Usage

Run in shell:

```sh
docker run -v "${PWD}":/mount matejkosiarcik/azlint:latest
```

Run in gitlab-ci:

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
    - run: azlint
```

> Currently only `:latest` is available, I plan to release version-tagged
versions (such as `:1.0.0`) as well.

### Alternative installation

AZLint can be alternatively installed right on your operating system (without
docker).
This mode is meant mostly for development, with further instructions coming
soon.

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
