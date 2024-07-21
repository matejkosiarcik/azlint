# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## \[0.6.12\] - 2023-10-31

- Fixed
  - Properly invoke `eclint` (add missing `check` subcommand)
- Maintenance
  - Update dependencies

## \[0.6.11\] - 2023-09-23

- Maintenance
  - Update dependencies

## \[0.6.10\] - 2023-08-25

- Fixed
  - Fix these mypy problems: `Failed to find builtin module [redacted], perhaps typeshed is broken?` (caused by removed `.pyi` files)
- Miscellaneous
  - Update internal packages

## \[0.6.9\] - 2023-08-09

- Miscellaneous
  - Maintenance release (Deploy during previous version failed to push to dockerhub)

## \[0.6.8\] - 2023-08-06

- Added
  - New linters:
    - `actionlint` for GitHub Action workflow files
- Miscellaneous
  - Optimize dependencies in published docker image (-> reduces total image size by ~90MB)
    - Remove unused files from linuxbrew and associated rbenv's ruby
    - Remove unecessary files from directories (`bundle`, `node_modules`, `python` and `vendor`)
    - Remove unecessary properties from `package.json`s

## \[0.6.7\] - 2023-07-23

- Fixed
  - Problem with `shellcheck`, `shellharden`, `oksh`, `loksh` on x64 caused by `upx --ultra-brute`

## \[0.6.6\] - 2023-07-22

- Added
  - New linters:
    - `npm ci --dry-run` for `package-lock.json` files
- Miscellaneous
  - Optimize `node_modules` in published docker image (total improvement ~340 MB-> 310 MB)

## \[0.6.5\] - 2023-07-18

- Added
  - New linters
    - `oksh` for shell files
    - `hush --check` for `*.hush` files
- Fixed
  - Formatting for _json_ files with prettier
- Changed
  - Remove jscpd

## \[0.6.4\] - 2023-07-14

- Added
  - New linters:
    - `brew bundle list` for `Brewfile`s

## \[0.6.3\] - 2023-07-09

- Added
  - New linters:
    - `loksh` for shell files

## \[0.6.2\] - 2023-07-02

- Added
  - Add new linters
    - `proselint` for `*.{md,txt}` files
    - `npm install --dry-run` for `package.json` files
  - Enable existing linters:
    - `markdown-link-checker`

## \[0.6.1\] - 2023-06-30

- Miscellaneous
  - Publish arm64 docker images (previously only amd64)

## \[0.6.0\] - 2023-06-30

- Added
  - Completely rework CLI
    - New CLI is written in TypeScript (previously Python)
    - Add dir positional argument to lint outside of `CWD`
    - Improve logging output
    - Add CLI option --color (auto,never,always), similar to grep's
  - Add new linters
    - `eclint` for all files
    - `stoml` for `*.{toml,svg,ini}` files
    - `markdown-table-formatter` for `*.md` files
    - `pip install --dry-run` for `requirements.txt` files
    - `composer install --dry-run` for `composer.json` files
  - Disable linters:
    - `markdown-link-checker` (network problems)
- Fixed
  - Reenable linters `jsonlint` and `markdownlint`
- Miscellaneous
  - Update dependencies
  - Add scripts for bootstraping dependencies natively/locally, outside of docker
  - Temporary disable `autopep8`

## \[0.5.5\] - 2023-06-21

- Fixed
  - Git permission issues for non-azlint users for all repositories inside the container

## \[0.5.4\] - 2023-06-21

- Fixed
  - Permission issues for non-azlint users inside the container

## \[0.5.3\] - 2023-06-21

- Miscellaneous
  - Rerelease

## \[0.5.2\] - 2023-06-21

- Miscellaneous
  - Rerelease

## \[0.5.1\] - 2023-06-21

- Miscellaneous
  - Rerelease

## \[0.5.0\] - 2023-06-20

- Changed
  - Disable `jsonlint` and `markdownlint`
- Miscellaneous
  - Update dependencies
  - Update runtime container from debian `11.6` to `11.7`
  - Publish `:edge` tag instead of `:dev` tag to symbolize latest "trunk" release

## \[0.4.5\] - 2021-06-20

- Added
  - Dry run shell scripts
- Changed
  - Upgrade runtime container to 10.9 (buster - stable) -> 11 (bullseye - testing)
  - Upgrade python 3.7 -> 3.9

## \[0.4.4\] - 2021-06-12

- Added
  - Report all found errors (not just the first one)
- Changed
  - Update dependencies

## \[0.4.3\] - 2021-06-06

- Fixed
  - Do not change cwd (fixes running on some CI services)

## \[0.4.2\] - 2021-06-05

- Added
  - `--only-changed` option
  - Colored file output
  - New components:
    - mypy
    - Git check-ignore
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
    - Bash
    - Hadolint
    - Swift
    - Zsh
- Changed
  - Optimize existing components
    - multi stage docker builds (resulting image should be smaller)
    - compile executables in production mode
    - strip executables from debug symbols
    - pack executables with upx
    - prune non-production npm dependencies
    - speed up Git operations

## \[0.1.1\] - 2020-06-04

- Fixed
  - bats checking

## \[0.1.0\] - 2020-06-03

Initial release
