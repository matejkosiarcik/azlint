# Todo

- Add and improve linters:
  - checkov
  - textlint
  - brew bundle list --file="#file#"
  - Check more shells in dry_runner: oksh, hush
  - Remove exitzero from jscpd
  - sql-lint and sqlfluff
  - GitHub-actions linter: actionlint
  - Install hadolint and shellcheck with cabal
    - Do not use published official images (too few architectures)
    - Do not use debian shellcheck in CI pipelines
  - Research how to put .shellcheckrc into subdirectory

- Useful links for LinuxBrew:
  - <https://unix.stackexchange.com/questions/115272/download-package-via-apt-for-another-architecture>
  - <https://github.com/orgs/Homebrew/discussions/3612>

- Watch this issue https://github.com/CircleCI-Public/circleci-cli/issues/959 and remove rosetta hack when possible
