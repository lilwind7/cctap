# Create a tmpdir per test, exported as $TMPDIR_TEST.
setup_tmpdir() {
    TMPDIR_TEST="$(mktemp -d)"
    export TMPDIR_TEST
}

teardown_tmpdir() {
    [ -n "$TMPDIR_TEST" ] && rm -rf "$TMPDIR_TEST"
}
