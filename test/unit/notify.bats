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

@test "send_notification passes -sender with Warp's bundle id" {
    source_lib
    send_notification "T" "S" "M" "g" "/p"
    grep -q -- "-sender" "$FAKE_NOTIFIER_LOG"
    grep -q "dev.warp.Warp-Stable" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification exits 0 even if terminal-notifier missing" {
    PATH="/usr/bin:/bin" run bash -c "source $PROJECT_ROOT/lib/notify.sh; send_notification T S M g /p"
    [ "$status" -eq 0 ]
}

@test "send_notification passes -appIcon when icon exists in repo" {
    [ -f "$PROJECT_ROOT/share/icons/cctap.png" ] || skip "cctap.png not present"
    source_lib
    send_notification "T" "S" "M" "g" "/p"
    grep -q -- "-appIcon" "$FAKE_NOTIFIER_LOG"
    grep -q "share/icons/cctap.png" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification omits -appIcon when icon missing (graceful)" {
    # Stage a fake repo layout where lib/notify.sh exists but share/icons/cctap.png doesn't.
    fake_repo="$TMPDIR_TEST/fake-repo"
    mkdir -p "$fake_repo/lib"
    cp "$PROJECT_ROOT/lib/notify.sh" "$fake_repo/lib/notify.sh"
    source "$fake_repo/lib/notify.sh"
    send_notification "T" "S" "M" "g" "/p"
    ! grep -q -- "-appIcon" "$FAKE_NOTIFIER_LOG"
}

@test "send_notification escapes single quotes in focus_cwd for -execute" {
    source_lib
    send_notification "T" "S" "M" "g" "/Users/x/Bob's stuff"
    # The -execute arg should contain the apostrophe in a shell-safe form.
    # We verify by extracting the line after -execute and shell-evaluating it
    # to confirm it parses cleanly and the resulting argv has exactly one arg
    # equal to "/Users/x/Bob's stuff".
    execute_line=$(awk '/^-execute$/{getline; print; exit}' "$FAKE_NOTIFIER_LOG")
    [ -n "$execute_line" ]
    # Use bash to evaluate the execute string into argv, capture argv[1] (the cwd arg)
    extracted=$(bash -c "set -- $execute_line; printf '%s\n' \"\$#\" \"\$2\"")
    # First line is the argc; second line is argv[1] (focus_warp.sh) and... wait.
    # set -- expands the string; argv[0] will be the script path, argv[1] the cwd.
    # We want $# == 2 and $2 == "/Users/x/Bob's stuff".
    argc=$(printf '%s\n' "$extracted" | sed -n '1p')
    arg2=$(printf '%s\n' "$extracted" | sed -n '2p')
    [ "$argc" = "2" ]
    [ "$arg2" = "/Users/x/Bob's stuff" ]
}
