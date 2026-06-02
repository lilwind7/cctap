#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

source_lib() {
    source "$PROJECT_ROOT/lib/transcript.sh"
}

@test "extracts last user message from transcript" {
    source_lib
    run extract_last_user_message "$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl"
    assert_success
    assert_output "再加一个测试"
}

@test "returns empty when transcript is empty" {
    source_lib
    run extract_last_user_message "$PROJECT_ROOT/test/fixtures/transcript-empty.jsonl"
    assert_success
    assert_output ""
}

@test "returns empty when transcript path does not exist" {
    source_lib
    run extract_last_user_message "$TMPDIR_TEST/missing.jsonl"
    assert_success
    assert_output ""
}

@test "skips malformed lines and returns last valid user message" {
    source_lib
    run extract_last_user_message "$PROJECT_ROOT/test/fixtures/transcript-malformed.jsonl"
    assert_success
    assert_output "第二条"
}

@test "truncates messages longer than 60 chars" {
    long_msg=$(printf '%.0sA' {1..100})
    cat > "$TMPDIR_TEST/long.jsonl" <<EOF
{"type":"user","message":{"content":"$long_msg"}}
EOF
    source_lib
    run extract_last_user_message "$TMPDIR_TEST/long.jsonl"
    assert_success
    [ "${#output}" -le 63 ]
}
