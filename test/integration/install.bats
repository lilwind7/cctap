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
