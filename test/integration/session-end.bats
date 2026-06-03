#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    export CCTAP_NO_DETACH=1

    fake_cwd="$TMPDIR_TEST/crashed-proj"
    mkdir -p "$fake_cwd"
    export FAKE_CWD="$fake_cwd"
}
teardown() { teardown_tmpdir; }

mk_payload() {
    local fixture="$1"
    local out="$TMPDIR_TEST/payload.json"
    sed -e "s|FIXTURE_TRANSCRIPT_PATH|$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl|" \
        -e "s|FIXTURE_CWD|$FAKE_CWD|" \
        "$PROJECT_ROOT/test/fixtures/$fixture" > "$out"
    echo "$out"
}

@test "session-end with reason=other fires notification" {
    payload=$(mk_payload payload-session-end-other.json)
    run bash -c "$PROJECT_ROOT/bin/cctap session-end < $payload"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    grep -q "crashed-proj · 异常退出" "$FAKE_NOTIFIER_LOG"
    grep -q "原因: other" "$FAKE_NOTIFIER_LOG"
}

@test "session-end with reason=clear does NOT notify" {
    payload=$(mk_payload payload-session-end-clear.json)
    run bash -c "$PROJECT_ROOT/bin/cctap session-end < $payload"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_NOTIFIER_LOG" ]
}

@test "session-end with reason=logout does NOT notify" {
    payload=$(mk_payload payload-session-end-other.json)
    jq '.reason = "logout"' "$payload" > "$payload.tmp" && mv "$payload.tmp" "$payload"
    run bash -c "$PROJECT_ROOT/bin/cctap session-end < $payload"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_NOTIFIER_LOG" ]
}

@test "session-end with reason=prompt_input_exit does NOT notify (user-initiated exit)" {
    payload=$(mk_payload payload-session-end-other.json)
    jq '.reason = "prompt_input_exit"' "$payload" > "$payload.tmp" && mv "$payload.tmp" "$payload"
    run bash -c "$PROJECT_ROOT/bin/cctap session-end < $payload"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_NOTIFIER_LOG" ]
}
