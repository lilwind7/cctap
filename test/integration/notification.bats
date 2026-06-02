#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
    export FAKE_OSASCRIPT_OUT="no"

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

@test "cctap notification skips when Warp focused" {
    FAKE_OSASCRIPT_OUT="yes" run bash -c "$PROJECT_ROOT/bin/cctap notification < $PAYLOAD_FILE"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_NOTIFIER_LOG" ]
}

@test "cctap notification handles multi-line message without truncation" {
    cat > "$TMPDIR_TEST/multiline.json" <<EOF
{"session_id":"x","cwd":"$FAKE_CWD","message":"line one\nline two"}
EOF
    run bash -c "$PROJECT_ROOT/bin/cctap notification < $TMPDIR_TEST/multiline.json"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_NOTIFIER_LOG" ]
}
