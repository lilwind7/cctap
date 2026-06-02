#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
}
teardown() { teardown_tmpdir; }

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

@test "treats sibling-prefix paths as not focused (no false positive)" {
    # Regression: a bare `starts with "/Users/x/proj"` would wrongly match
    # wd=/Users/x/project-other. We can't drive that case end-to-end through the
    # fake osascript (it's a black box), so instead we render the script text
    # and assert its comparison logic: an exact equality branch AND any
    # `starts with` branch must append a trailing "/" so sibling prefixes
    # cannot match.
    source "$PROJECT_ROOT/lib/focus_check.sh"
    rendered=$(render_focus_check_script "/Users/x/proj")

    # Positive: must contain the exact-equality branch.
    echo "$rendered" | grep -E '= "/Users/x/proj"' >/dev/null

    # Positive: must contain a subtree check (with trailing slash, possibly via concat).
    echo "$rendered" | grep -E '("/Users/x/proj/"|"/Users/x/proj" &[[:space:]]*"/")' >/dev/null

    # Negative: must NOT contain a bare `starts with "/Users/x/proj"` immediately
    # followed by `then` (i.e., without a `& "/"` slash-append in between).
    ! echo "$rendered" | grep -E 'starts with "/Users/x/proj"[[:space:]]+then' >/dev/null
}
