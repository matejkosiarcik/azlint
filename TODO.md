# Todo

- Add and improve linters:
  - checkov
  - textlint
  - Remove exitzero from jscpd
  - sql-lint and sqlfluff
  - GitHub Actions linter: actionlint
  - Install hadolint and shellcheck with cabal
    - Do not use published official images (too few architectures)
    - Do not use debian shellcheck in CI pipelines
    - Enable hadolint in CI pipelines
  - Research how to put .shellcheckrc into subdirectory
  - Test azlint in GitHub Actions with azlint user

- Add config option to add additional CLI variable for individual linters
- Add config option to add files for individual linters
- Add config option to ignore certain files for individual linters

- Useful links for LinuxBrew:
  - <https://github.com/orgs/Homebrew/discussions/3612>

- Watch this issue <https://github.com/CircleCI-Public/circleci-cli/issues/959> and remove rosetta hack when possible
