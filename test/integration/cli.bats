#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    export CCTAP_NO_DETACH=1
}
teardown() { teardown_tmpdir; }

@test "test-notify fires a sample notification" {
    run "$PROJECT_ROOT/bin/cctap" test-notify
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    grep -q "cctap · 测试" "$FAKE_NOTIFIER_LOG"
}

@test "doctor exits 0 and prints check results to stdout" {
    run "$PROJECT_ROOT/bin/cctap" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"terminal-notifier"* ]]
    [[ "$output" == *"jq"* ]]
}

@test "doctor exits non-zero when terminal-notifier missing" {
    PATH="/usr/bin:/bin" run "$PROJECT_ROOT/bin/cctap" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]]
}
