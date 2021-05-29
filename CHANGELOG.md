# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## \[Unreleased\]

- Added
  - `--only-changes` option
  - Colored file output
  - New mypy component
- Changed
  - new python wrapper
  - Optimize reading list of files
  - Change lint order based on file types

## \[0.4.1\] - 2021-05-24

- Fixed
  - Print shellharden diff on error
  - Skip circleci update check (can potentially hang the process)
- Changed
  - Update dependencies
- Removed
  - stoml linter

## \[0.4.0\] - 2021-05-18

- Added
  - Formatting mode for supported linters
  - New linters:
    - autopep8
    - black
    - checkmake
    - dockerfilelint
    - dotenv-linter
    - editorconfig-checker
    - flake8
    - hadolint
    - htmlhint
    - isort
    - markdown-link-check
    - markdownlint (npm)
    - pycodestyle
    - pylint
    - shellharden
    - shfmt
    - xmllint
    - yamllint
- Changed
  - Update dependencies

## \[0.3.1\] - 2021-04-06

- Fixed
  - Change runtime CWD into `/project`

## \[0.3.0\] - 2021-04-06

- Changed
  - Change deployment strategy to only deploy a single docker image with everything included
  - Keep only linters:
    - bashate
    - bats-core
    - bmake
    - circle-ci lint
    - composer-normalize
    - composer-validate
    - gitlab-ci-lint
    - gitlab-ci-validate
    - gmake
    - htmllint
    - jsonlint
    - markdownlint (ruby)
    - package-json-validator
    - stoml
    - svglint
    - tomljson
    - travis-lint

## \[0.2.6\] - 2020-08-25

- Changed
  - Optimize swift
  - Update dependencies

## \[0.2.6\] - 2020-08-13

- Added
  - Add htmlhint, htmllint to npm component
- Changed
  - Update dependencies

## \[0.2.5\] - 2020-08-10

- Changed
  - Remove pycodestyle and pyflakes (and keep only flake8)
  - Disable standalone pycodestyle and pyflakes

## \[0.2.4\] - 2020-08-08

- Fixed
  - Fix docker autobuild

## \[0.2.3\] - 2020-08-07

- Added
  - New python linters

## \[0.2.2\] - 2020-08-03

- Changed
  - Remove jsonlint from composer component

## \[0.2.1\] - 2020-07-25

- Changed
  - Remove jsonprima from rust component

## \[0.2.0\] - 2020-07-23

- Added
  - New components
    - haskell
    - ruby
    - rust
  - New dependency dockerfileint for npm component
- Changed
  - Move previous components hadolint and shellcheck into haskell components
  - Remove travislint
  - Update dependencies
  - Rework dockerhub builds to use hash-based internal images

## \[0.1.2\] - 2020-06-20

- Added
  - Add new components
    - bash
    - hadolint
    - swift
    - zsh
- Changed
  - Optimize existing components
    - multi stage docker builds (resulting image should be smaller)
    - compile executables in production mode
    - strip executables from debug symbols
    - pack executables with upx
    - prune non-production npm dependencies
    - speed up git operations

## \[0.1.1\] - 2020-06-04

- Fixed
  - bats checking

## \[0.1.0\] - 2020-06-03

Initial release
