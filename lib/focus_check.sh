# Check whether the frontmost Warp tab's working directory matches the given path.
# Returns 0 if yes, 1 otherwise. On any failure, returns 1 (treat as "not focused").
is_warp_focused_on() {
    local cwd="$1"
    local script
    script=$(cat <<APPLESCRIPT
try
    tell application "System Events"
        if not (exists process "Warp") then return "no"
        if not (frontmost of process "Warp") then return "no"
    end tell
    tell application "Warp"
        set wd to working directory of selected tab of front window
        if wd starts with "$cwd" then
            return "yes"
        else
            return "no"
        end if
    end tell
on error
    return "no"
end try
APPLESCRIPT
)

    local result
    result=$(osascript -e "$script" 2>/dev/null) || return 1

    [ "$result" = "yes" ]
}
