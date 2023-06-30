#!/usr/bin/env bats
# shellcheck disable=SC2086

function setup() {
    cd "$BATS_TEST_DIRNAME/../.." || exit 1 # project root
    # if [ -z "${COMMAND+x}" ]; then exit 1; fi
    tmpdir="$(mktemp -d)"
    export tmpdir
    . src/shell-dry-run.sh # source main script to verify functions
}

function shebang_test() {
    # given
    printf '%s\n' "$1" >"$tmpdir/file"

    # when
    run detect_shell "$tmpdir/file"

    # then
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s' "$1" | rev | cut -d '/' -f 1 | cut -d ' ' -f 1 | rev)" ]
}

@test 'Should detect direct shells' {
    shebang_test '#!/bin/ash'
    shebang_test '#!/bin/bash'
    shebang_test '#!/bin/dash'
    shebang_test '#!/bin/hush'
    shebang_test '#!/bin/ksh'
    shebang_test '#!/bin/loksh'
    shebang_test '#!/bin/mksh'
    shebang_test '#!/bin/pdksh'
    shebang_test '#!/bin/posh'
    shebang_test '#!/bin/sh'
    shebang_test '#!/bin/yash'
    shebang_test '#!/bin/zsh'
}

@test 'Should detect direct shells in non-standard locations' {
    shebang_test '#!/usr/bin/sh'
    shebang_test '#!/usr/local/bin/bash'
    shebang_test '#!/the/answer/is/42/zsh'
}

@test 'Should detect direct shells through env' {
    shebang_test '#!/usr/bin/env bash'
}
