#!/usr/bin/env bash
# Idempotently merge cctap's three hook entries into ~/.claude/settings.json.
# Args: <settings_path> <cctap_bin_path>
set -e

settings="$1"
cctap_bin="$2"

if [ -z "$settings" ] || [ -z "$cctap_bin" ]; then
    echo "usage: merge_hooks.sh <settings.json> <cctap_bin>" >&2
    exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
snippet="$script_dir/hooks-snippet.json"

if [ ! -f "$settings" ]; then
    echo "{}" > "$settings"
fi

# Render snippet with the real cctap path.
# Use bash parameter expansion (not sed) to avoid metacharacter pitfalls.
# sed would mis-handle & (back-reference) or | (its delimiter) in cctap_bin.
rendered=$(cat "$snippet")
rendered=${rendered//CCTAP_BIN/$cctap_bin}

# Merge per event:
# For each event key in the rendered snippet, append each new group to the
# existing event's array — but only if no existing entry has a hook with
# the same command string (idempotency).
merged=$(
    jq --argjson snippet "$rendered" '
        .hooks //= {} |
        reduce ($snippet | to_entries[]) as $kv (.;
            .hooks[$kv.key] //= [] |
            reduce ($kv.value[]) as $newGroup (.;
                ($newGroup.hooks | map(.command)) as $newCmds |
                if (.hooks[$kv.key] | map(.hooks[]?.command) | any(. as $c | $newCmds | index($c) != null))
                then .
                else .hooks[$kv.key] += [$newGroup]
                end
            )
        )
    ' "$settings"
)

printf '%s\n' "$merged" > "$settings"
