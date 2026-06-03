#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() {
    setup_tmpdir
    export HOME="$TMPDIR_TEST"
    mkdir -p "$HOME/.claude"
}
teardown() { teardown_tmpdir; }

@test "install creates settings.json with cctap hooks when none exists" {
    run "$PROJECT_ROOT/bin/cctap" install
    [ "$status" -eq 0 ]
    [ -f "$HOME/.claude/settings.json" ]
    grep -q "cctap stop" "$HOME/.claude/settings.json"
    grep -q "cctap notification" "$HOME/.claude/settings.json"
    grep -q "cctap session-end" "$HOME/.claude/settings.json"
}

@test "install backs up existing settings.json before modifying" {
    cp "$PROJECT_ROOT/test/fixtures/settings-existing.json" "$HOME/.claude/settings.json"
    run "$PROJECT_ROOT/bin/cctap" install
    [ "$status" -eq 0 ]
    ls "$HOME/.claude/backups/" | grep -q "settings."
}

@test "install preserves existing hook entries" {
    cp "$PROJECT_ROOT/test/fixtures/settings-existing.json" "$HOME/.claude/settings.json"
    run "$PROJECT_ROOT/bin/cctap" install
    [ "$status" -eq 0 ]
    grep -q "dcc hook post-tool-use" "$HOME/.claude/settings.json"
    grep -q "dcc hook session-end" "$HOME/.claude/settings.json"
    grep -q "cctap session-end" "$HOME/.claude/settings.json"
}

@test "install is idempotent" {
    "$PROJECT_ROOT/bin/cctap" install
    first=$(cat "$HOME/.claude/settings.json")
    "$PROJECT_ROOT/bin/cctap" install
    second=$(cat "$HOME/.claude/settings.json")
    [ "$first" = "$second" ]
}

@test "uninstall removes only cctap entries" {
    cp "$PROJECT_ROOT/test/fixtures/settings-existing.json" "$HOME/.claude/settings.json"
    "$PROJECT_ROOT/bin/cctap" install
    run "$PROJECT_ROOT/bin/cctap" uninstall
    [ "$status" -eq 0 ]
    ! grep -q "cctap" "$HOME/.claude/settings.json"
    grep -q "dcc hook post-tool-use" "$HOME/.claude/settings.json"
}

@test "install fails loudly when settings.json is malformed" {
    # Make the existing settings.json un-parseable.
    printf '{not valid json' > "$HOME/.claude/settings.json"
    run "$PROJECT_ROOT/bin/cctap" install
    [ "$status" -ne 0 ]
    # The backup should still have been created from the broken settings.
    ls "$HOME/.claude/backups/" | grep -q "settings."
    # And the user should see an error message.
    [[ "$output" == *"merge failed"* ]] || [[ "$output" == *"failed"* ]]
}

@test "uninstall does NOT remove non-cctap commands that contain the literal cctap" {
    cat > "$HOME/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "/Users/x/.local/bin/cctap stop" },
          { "type": "command", "command": "/Users/x/bin/my-cctap-wrapper" },
          { "type": "command", "command": "/usr/bin/foo --note cctap-thing" }
        ]
      }
    ]
  }
}
EOF
    run "$PROJECT_ROOT/bin/cctap" uninstall
    [ "$status" -eq 0 ]
    # cctap stop should be GONE.
    ! grep -q "cctap stop" "$HOME/.claude/settings.json"
    # Non-cctap commands containing the substring should REMAIN.
    grep -q "my-cctap-wrapper" "$HOME/.claude/settings.json"
    grep -q "cctap-thing" "$HOME/.claude/settings.json"
}
