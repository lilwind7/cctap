# Send a macOS notification. Always exits 0.
# Args: <title> <subtitle> <message> <group> <focus_cwd>
send_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    local group="$4"
    local focus_cwd="$5"

    if ! command -v terminal-notifier >/dev/null 2>&1; then
        echo "cctap: terminal-notifier not found; skipping notification" >&2
        return 0
    fi

    local project_root
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # Escape any single quotes in focus_cwd so the -execute string parses cleanly.
    # The canonical '\'' pattern closes the single-quoted segment, emits an
    # escaped single quote, then re-opens it. Note: the assignment is intentionally
    # unquoted because inside "${var//PAT/REP}" the backslashes in REP are
    # preserved literally instead of being consumed by the shell.
    local quoted_cwd=${focus_cwd//\'/\'\\\'\'}

    local icon_path="$project_root/share/icons/cctap.png"
    local icon_args=()
    [ -f "$icon_path" ] && icon_args=(-appIcon "$icon_path")

    # We deliberately do NOT pass -sender. Routing through another app's
    # bundle id (e.g. dev.warp.Warp-Stable) requires that app to have macOS
    # notification permission, and silently drops the banner otherwise.
    # With -appIcon, the user still sees our cctap icon on the banner.
    #
    # -timeout 10: terminal-notifier auto-exits 10s after posting, so an
    # un-clicked notification doesn't leave the process hanging.
    #
    # Detach: terminal-notifier with -execute blocks until clicked or timed
    # out — that's up to 10s, far over our ≤1s hook contract. The ( ... & )
    # subshell backgrounds the process and returns immediately. Tests set
    # CCTAP_NO_DETACH=1 to run synchronously for deterministic assertions.
    local tn_args=(
        -title "$title"
        -subtitle "$subtitle"
        -message "$message"
        -group "$group"
        -timeout 10
        "${icon_args[@]}"
        -execute "$project_root/lib/focus_warp.sh '$quoted_cwd'"
    )

    if [ "${CCTAP_NO_DETACH:-0}" = "1" ]; then
        terminal-notifier "${tn_args[@]}" >/dev/null 2>&1 || true
    else
        ( terminal-notifier "${tn_args[@]}" >/dev/null 2>&1 & )
    fi

    return 0
}
