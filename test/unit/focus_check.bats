#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
}
teardown() { teardown_tmpdir; }

source_lib() {
    source "$PROJECT_ROOT/lib/focus_check.sh"
}

@test "returns 0 (focused) when osascript says yes" {
    FAKE_OSASCRIPT_OUT="yes" run bash -c "
        source $PROJECT_ROOT/lib/focus_check.sh
        is_warp_focused_on /Users/x/proj
    "
    [ "$status" -eq 0 ]
}

@test "returns 1 (not focused) when osascript says no" {
    FAKE_OSASCRIPT_OUT="no" run bash -c "
        source $PROJECT_ROOT/lib/focus_check.sh
        is_warp_focused_on /Users/x/proj
    "
    [ "$status" -eq 1 ]
}

@test "returns 1 (treat as not focused) when osascript fails" {
    FAKE_OSASCRIPT_FAIL=1 run bash -c "
        source $PROJECT_ROOT/lib/focus_check.sh
        is_warp_focused_on /Users/x/proj
    "
    [ "$status" -eq 1 ]
}
