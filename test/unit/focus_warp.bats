#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    export PATH="$PROJECT_ROOT/test/helpers/fakes:$PATH"
}
teardown() { teardown_tmpdir; }

@test "focus_warp.sh runs and exits 0 when osascript succeeds" {
    FAKE_OSASCRIPT_OUT="ok" run "$PROJECT_ROOT/lib/focus_warp.sh" "/some/path"
    [ "$status" -eq 0 ]
}

@test "focus_warp.sh exits 0 even when osascript fails (degraded mode)" {
    FAKE_OSASCRIPT_FAIL=1 run "$PROJECT_ROOT/lib/focus_warp.sh" "/some/path"
    [ "$status" -eq 0 ]
}

@test "focus_warp.sh exits 0 when given no argument" {
    run "$PROJECT_ROOT/lib/focus_warp.sh"
    [ "$status" -eq 0 ]
}

@test "focus_warp.sh sources cleanly (provides focus_warp_tab function)" {
    source "$PROJECT_ROOT/lib/focus_warp.sh"
    type focus_warp_tab >/dev/null
}

@test "focus_warp uses exact-or-subpath match (no bare 'starts with' on cwd)" {
    # Like focus_check, the matcher must require either equality OR a trailing slash
    # after the cwd. We grep the rendered script.
    source "$PROJECT_ROOT/lib/focus_warp.sh"
    type render_focus_warp_script >/dev/null
    rendered=$(render_focus_warp_script "/Users/x/proj")
    # Must contain exact-equality and slash-suffixed prefix checks against /Users/x/proj.
    echo "$rendered" | grep -E '(= "/Users/x/proj"|wd = "/Users/x/proj")' >/dev/null
    echo "$rendered" | grep -E '(starts with "/Users/x/proj/"|"/Users/x/proj" &[[:space:]]*"/")' >/dev/null
    # Must NOT contain a bare `starts with "/Users/x/proj" then` (no trailing slash).
    ! echo "$rendered" | grep -E 'starts with "/Users/x/proj"[[:space:]]+then' >/dev/null
}
