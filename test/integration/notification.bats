#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    export CCTAP_NO_DETACH=1
    # Isolate the dedup timestamp files in tmpdir so tests don't pollute
    # the real ~/.cache/cctap.
    export HOME="$TMPDIR_TEST"

    fake_cwd="$TMPDIR_TEST/needs-input"
    mkdir -p "$fake_cwd"
    payload="$TMPDIR_TEST/payload.json"
    sed -e "s|FIXTURE_CWD|$fake_cwd|" \
        "$PROJECT_ROOT/test/fixtures/payload-notification.json" > "$payload"
    export PAYLOAD_FILE="$payload"
    export FAKE_CWD="$fake_cwd"
}
teardown() { teardown_tmpdir; }

@test "cctap notification uses payload.message as subtitle" {
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
    grep -q "needs-input · 待确认" "$FAKE_NOTIFIER_LOG"
    grep -q "Claude needs your permission to use Bash" "$FAKE_NOTIFIER_LOG"
}

@test "cctap notification is suppressed within 5s of a stop for same cwd" {
    # Fire stop first.
    cat > "$TMPDIR_TEST/stop.json" <<EOF
{"session_id":"x","transcript_path":"$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl","cwd":"$FAKE_CWD"}
EOF
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $TMPDIR_TEST/stop.json"
    [ "$status" -eq 0 ]
    # The stop notification should have fired.
    grep -q "已完成" "$FAKE_NOTIFIER_LOG"
    # Clear the log so we can detect a second write.
    : > "$FAKE_NOTIFIER_LOG"
    # Notification immediately after for the same cwd should be suppressed.
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    ! grep -q "待确认" "$FAKE_NOTIFIER_LOG"
}

@test "cctap notification fires when no recent stop for that cwd" {
    # No prior stop. The notification should fire normally.
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    grep -q "待确认" "$FAKE_NOTIFIER_LOG"
}

@test "cctap notification fires when stop was for a different cwd" {
    other_cwd="$TMPDIR_TEST/other-project"
    mkdir -p "$other_cwd"
    cat > "$TMPDIR_TEST/stop.json" <<EOF
{"session_id":"x","transcript_path":"$PROJECT_ROOT/test/fixtures/transcript-basic.jsonl","cwd":"$other_cwd"}
EOF
    run bash -c "$PROJECT_ROOT/bin/cctap stop < $TMPDIR_TEST/stop.json"
    [ "$status" -eq 0 ]
    : > "$FAKE_NOTIFIER_LOG"
    # Notification for FAKE_CWD (different from stop's cwd) should still fire.
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    grep -q "待确认" "$FAKE_NOTIFIER_LOG"
}

@test "cctap notification handles multi-line message without truncation" {
    cat > "$TMPDIR_TEST/multiline.json" <<EOF
{"session_id":"x","cwd":"$FAKE_CWD","message":"line one\nline two"}
EOF
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $TMPDIR_TEST/multiline.json"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
}
