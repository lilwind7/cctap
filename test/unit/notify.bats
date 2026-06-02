#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    FAKE_NOTIFIER_LOG="$TMPDIR_TEST/notifier.log"
    export FAKE_NOTIFIER_LOG
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
}
teardown() { teardown_tmpdir; }

source_lib() {
    source "$PROJECT_ROOT/lib/notify.sh"
}

@test "send_notification calls terminal-notifier with -title -subtitle -message" {
    source_lib
    send_notification "项目 · 已完成" "帮我看看 X" "Claude 已结束本轮" "cctap:/p" "/p"
    grep -q -- "-title" "$FAKE_NOTIFIER_LOG"
    grep -q "项目 · 已完成" "$FAKE_NOTIFIER_LOG"
    grep -q -- "-subtitle" "$FAKE_NOTIFIER_LOG"
    grep -q "帮我看看 X" "$FAKE_NOTIFIER_LOG"
    grep -q -- "-message" "$FAKE_NOTIFIER_LOG"
    grep -q "Claude 已结束本轮" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification passes -group for replacement" {
    source_lib
    send_notification "T" "S" "M" "cctap:/foo" "/foo"
    grep -q -- "-group" "$FAKE_NOTIFIER_LOG"
    grep -q "cctap:/foo" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification passes -execute pointing at focus_warp.sh" {
    source_lib
    send_notification "T" "S" "M" "cctap:/foo" "/foo"
    grep -q -- "-execute" "$FAKE_NOTIFIER_LOG"
    grep -q "focus_warp.sh" "$FAKE_NOTIFIER_LOG"
    grep -q "/foo" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification passes -sender com.warp.Warp" {
    source_lib
    send_notification "T" "S" "M" "g" "/p"
    grep -q -- "-sender" "$FAKE_NOTIFIER_LOG"
    grep -q "com.warp.Warp" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification exits 0 even if terminal-notifier missing" {
    PATH="/usr/bin:/bin" run bash -c "source $PROJECT_ROOT/lib/notify.sh; send_notification T S M g /p"
    [ "$status" -eq 0 ]
}
