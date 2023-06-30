#!/usr/bin/env bats
# shellcheck disable=SC2086

function setup() {
    cd "$BATS_TEST_DIRNAME/../.." || exit 1 # project root
    # if [ -z "${COMMAND+x}" ]; then exit 1; fi
    tmpdir="$(mktemp -d)"
    export tmpdir
    . src/shell-dry-run.sh # source main script to verify functions
}

function extension_test() {
    # given
    touch "$tmpdir/file.$1"

    # when
    run detect_shell "$tmpdir/file.$1"

    # then
    [ "$status" -eq 0 ]
    [ "$output" = "$1" ]
}

@test 'Should detect extensions' {
    extension_test ash
    extension_test bash
    extension_test dash
    extension_test hush
    extension_test ksh
    extension_test loksh
    extension_test mksh
    extension_test oksh
    extension_test pdksh
    extension_test posh
    extension_test sh
    extension_test yash
    extension_test zsh
}
