#!/usr/bin/env bash
# Activate Warp when the user clicks a cctap notification.
# Can be sourced (provides focus_warp_tab function) or executed directly.
# Always exits 0.
#
# Why not switch to the matching tab? Warp's AppleScript dictionary doesn't
# expose tabs/windows. Earlier attempts at `repeat with t in tabs of w` failed
# with a compile-time syntax error, which silently aborted the entire script
# including the activate call — so clicking the banner did literally nothing.
# Keeping this dead-simple: just bring Warp forward. See spec §5.4.

# Render the AppleScript used by focus_warp_tab. Exposed for unit tests.
render_focus_warp_script() {
    local _cwd="$1"  # currently unused — kept for future tab-aware impl
    cat <<'APPLESCRIPT'
tell application "Warp" to activate
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
