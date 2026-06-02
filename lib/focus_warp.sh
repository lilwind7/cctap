#!/usr/bin/env bash
# Bring the Warp tab matching <cwd> to the front. Falls back to just activating Warp.
# Can be sourced (provides focus_warp_tab function) or executed directly.
# Always exits 0.

# Render the AppleScript used by focus_warp_tab. Exposed for unit tests.
render_focus_warp_script() {
    local cwd="$1"
    cat <<APPLESCRIPT
try
    tell application "Warp" to activate
    tell application "Warp"
        repeat with w in windows
            repeat with t in tabs of w
                try
                    set wd to working directory of t
                    if wd = "$cwd" or wd starts with "$cwd" & "/" then
                        set index of w to 1
                        set selected of t to true
                        return "matched"
                    end if
                end try
            end repeat
        end repeat
    end tell
on error
    try
        tell application "Warp" to activate
    end try
end try
return "done"
APPLESCRIPT
}

focus_warp_tab() {
    local cwd="${1:-/}"
    local script
    script=$(render_focus_warp_script "$cwd")
    osascript -e "$script" >/dev/null 2>&1 || true
    return 0
}

# When executed (not sourced), call the function with $1.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    focus_warp_tab "${1:-}"
fi
