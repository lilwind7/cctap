# Extract the last user message from a CC transcript JSONL file.
# Echoes the message text (truncated to 60 chars + ellipsis) or empty string.
# Exit code is always 0.
extract_last_user_message() {
    local path="$1"
    [ -r "$path" ] || { echo ""; return 0; }

    local msg
    msg=$(awk '{ lines[NR] = $0 } END { for (i = NR; i > 0; i--) print lines[i] }' "$path" \
        | while IFS= read -r line; do
            text=$(printf '%s' "$line" | jq -r 'select(.type == "user") | .message.content // empty' 2>/dev/null)
            if [ -n "$text" ] && [ "$text" != "null" ]; then
                printf '%s' "$text"
                break
            fi
        done)

    if [ ${#msg} -gt 60 ]; then
        msg="${msg:0:60}..."
    fi
    printf '%s' "$msg"
}
