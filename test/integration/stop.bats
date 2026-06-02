#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    export FAKE_OSASCRIPT_OUT="no"  # default: Warp not focused → notify

    fake_cwd="$TMPDIR_TEST/my-project"
    mkdir -p "$fake_cwd"
    export FAKE_CWD="$fake_cwd"
    payload="$TMPDIR_TEST/payload.json"
    sed -e "s|FIXTURE_TRANSCRIPT_PATH|$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl|" \
        -e "s|FIXTURE_CWD|$fake_cwd|" \
        "$PROJECT_ROOT/test/fixtures/payload-stop.json" > "$payload"
    export PAYLOAD_FILE="$payload"
}
teardown() { teardown_tmpdir; }

@test "cctap stop fires notification when Warp not focused" {
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    grep -q "my-project · 已完成" "$FAKE_NOTIFIER_LOG"
    grep -q "再加一个测试" "$FAKE_NOTIFIER_LOG"
    grep -q "Claude 已结束本轮" "$FAKE_NOTIFIER_LOG"
    grep -q "cctap:$FAKE_CWD" "$FAKE_NOTIFIER_LOG"
}

@test "cctap stop skips notification when Warp focused on cwd" {
    FAKE_OSASCRIPT_OUT="yes" run bash -c "$PROJECT_ROOT/bin/cctap stop < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_NOTIFIER_LOG" ] || ! grep -q "my-project" "$FAKE_NOTIFIER_LOG"
}

@test "cctap stop exits 0 even with empty stdin" {
    run bash -c "$PROJECT_ROOT/bin/cctap stop < /dev/null"
    [ "$status" -eq 0 ]
}

@test "cctap stop exits 0 with malformed JSON" {
    echo "not json" > "$TMPDIR_TEST/bad.json"
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $TMPDIR_TEST/bad.json"
    [ "$status" -eq 0 ]
}

@test "cctap stop writes nothing to stdout" {
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $PAYLOAD_FILE"
    [ -z "$output" ]
}
