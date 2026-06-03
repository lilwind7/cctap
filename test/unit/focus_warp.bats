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

@test "rendered AppleScript just activates Warp (no broken tab iteration)" {
    # Warp's AppleScript dict doesn't support tab-level operations; any attempt
    # at `repeat with t in tabs of w` was a compile-time syntax error that
    # silently aborted the whole script — including the activate call.
    # The current implementation just activates Warp, nothing more.
    source "$PROJECT_ROOT/lib/focus_warp.sh"
    rendered=$(render_focus_warp_script "/Users/x/proj")
    echo "$rendered" | grep -q 'tell application "Warp" to activate'
    ! echo "$rendered" | grep -q "repeat with"
    ! echo "$rendered" | grep -q "tabs of"
}

@test "rendered AppleScript actually compiles on real osascript" {
    # Regression guard for the bug where the script had compile-time syntax
    # errors (Warp's empty AppleScript dict made `tabs of w` invalid). If
    # we ever reintroduce tab iteration, this test catches it before users do.
    [ "$(command -v osascript)" = "/usr/bin/osascript" ] || skip "needs real osascript"
    source "$PROJECT_ROOT/lib/focus_warp.sh"
    rendered=$(render_focus_warp_script "/Users/x/proj")
    # Compile-check only: use `osacompile`, or run osascript with the script
    # but redirect to /dev/null. A compile error returns non-zero.
    printf '%s' "$rendered" | /usr/bin/osascript -e 'on run' -e 'end run' >/dev/null 2>&1 || true
    # The real check: run the script. If it compiles, exit code is 0 (Warp
    # may not even be running — `activate` will launch it). If it doesn't
    # compile, exit is non-zero.
    printf '%s' "$rendered" > "$TMPDIR_TEST/script.scpt"
    /usr/bin/osascript "$TMPDIR_TEST/script.scpt" >/dev/null 2>"$TMPDIR_TEST/err"
    status=$?
    if [ "$status" -ne 0 ]; then
        echo "osascript stderr:" >&2
        cat "$TMPDIR_TEST/err" >&2
    fi
    [ "$status" -eq 0 ]
}
