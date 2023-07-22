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
  - Publish container to ghcr

- Add config option to add additional CLI variable for individual linters
- Add config option to add files for individual linters
- Add config option to ignore certain files for individual linters

- Useful links for LinuxBrew:
  - <https://github.com/orgs/Homebrew/discussions/3612>

- Watch this issue <https://github.com/CircleCI-Public/circleci-cli/issues/959> and remove rosetta hack when possible

- Optimize docker image:
  - minify `*.{js,mjc,cjs}` files in `/app/linters/node_modules`
  - minify `*.py` files in `/app/linters/python`
  - minify `*.rb` files in `/app/linters/bundle`
  - minify `*.php` files in `/app/linters/vendor`
  - minify `composer` executable
  - minify `*.{js,mjc,cjs}` files in `/app/cli/node_modules`
  - minify any other files (eg. `*.{json,yml}`) in all dependencies `/app/**/*`
  - minify main-CLI files at `/app/cli/*.js`
  - Enable LTO for _rust_ executables
  - Optimize _go_ executables (`ldflags`) for checkmake and editorconfig-checker
  - Reduce size after in final stage:
    - Too big `/usr/share/`
    - <https://askubuntu.com/a/541061>
    - Maybe try installing aptitude packages in previous stage and copy only binaries to final stage?
