#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    # Tests need synchronous behavior for deterministic assertions on the fake notifier log.
    export CCTAP_NO_DETACH=1

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

@test "cctap stop fires notification" {
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    grep -q "my-project · 已完成" "$FAKE_NOTIFIER_LOG"
    grep -q "再加一个测试" "$FAKE_NOTIFIER_LOG"
    grep -q "Claude 已结束本轮" "$FAKE_NOTIFIER_LOG"
    grep -q "cctap:$FAKE_CWD" "$FAKE_NOTIFIER_LOG"
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

@test "cctap stop handles cwd containing pipe character without truncation" {
    weird_cwd="$TMPDIR_TEST/has|pipe-in-name"
    mkdir -p "$weird_cwd"
    cat > "$TMPDIR_TEST/payload.json" <<EOF
{"session_id":"abc","transcript_path":"$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl","cwd":"$weird_cwd"}
EOF
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $TMPDIR_TEST/payload.json"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    # The notifier should have received the full cwd as the group name.
    grep -q "cctap:$weird_cwd" "$FAKE_NOTIFIER_LOG"
}

@test "cctap stop handles multi-line message field gracefully" {
    # CC stop hook doesn't normally include a message, but if it did with
    # embedded newlines, the script must still exit 0 and not corrupt other fields.
    cat > "$TMPDIR_TEST/payload.json" <<'EOF'
{"session_id":"abc","transcript_path":"","cwd":"FIXTURE_CWD","message":"line one\nline two"}
EOF
    sed -i.bak "s|FIXTURE_CWD|$FAKE_CWD|" "$TMPDIR_TEST/payload.json"
    rm "$TMPDIR_TEST/payload.json.bak"
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $TMPDIR_TEST/payload.json"
    [ "$status" -eq 0 ]
    # Notification should have been sent (cwd is valid).
    [ -f "$FAKE_NOTIFIER_LOG" ]
}
