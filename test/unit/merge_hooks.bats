#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "merge_hooks adds all three hooks to empty settings" {
    cp "$PROJECT_ROOT/test/fixtures/settings-empty.json" "$TMPDIR_TEST/settings.json"
    run "$PROJECT_ROOT/share/install/merge_hooks.sh" \
        "$TMPDIR_TEST/settings.json" "/Users/x/.local/bin/cctap"
    [ "$status" -eq 0 ]
    out=$(cat "$TMPDIR_TEST/settings.json")
    [[ "$out" == *"cctap stop"* ]]
    [[ "$out" == *"cctap notification"* ]]
    [[ "$out" == *"cctap session-end"* ]]
    [[ "$out" == *"opus"* ]]
}

@test "merge_hooks appends without removing existing hooks" {
    cp "$PROJECT_ROOT/test/fixtures/settings-existing.json" "$TMPDIR_TEST/settings.json"
    run "$PROJECT_ROOT/share/install/merge_hooks.sh" \
        "$TMPDIR_TEST/settings.json" "/Users/x/.local/bin/cctap"
    [ "$status" -eq 0 ]
    out=$(cat "$TMPDIR_TEST/settings.json")
    [[ "$out" == *"dcc hook post-tool-use"* ]]
    [[ "$out" == *"dcc hook session-end"* ]]
    [[ "$out" == *"cctap session-end"* ]]
}

@test "merge_hooks is idempotent" {
    cp "$PROJECT_ROOT/test/fixtures/settings-empty.json" "$TMPDIR_TEST/settings.json"
    "$PROJECT_ROOT/share/install/merge_hooks.sh" \
        "$TMPDIR_TEST/settings.json" "/Users/x/.local/bin/cctap"
    after_first=$(cat "$TMPDIR_TEST/settings.json")
    "$PROJECT_ROOT/share/install/merge_hooks.sh" \
        "$TMPDIR_TEST/settings.json" "/Users/x/.local/bin/cctap"
    after_second=$(cat "$TMPDIR_TEST/settings.json")
    [ "$after_first" = "$after_second" ]
}

@test "merge_hooks substitutes CCTAP_BIN placeholder" {
    cp "$PROJECT_ROOT/test/fixtures/settings-empty.json" "$TMPDIR_TEST/settings.json"
    "$PROJECT_ROOT/share/install/merge_hooks.sh" \
        "$TMPDIR_TEST/settings.json" "/Users/x/.local/bin/cctap"
    grep -q "/Users/x/.local/bin/cctap stop" "$TMPDIR_TEST/settings.json"
    ! grep -q "CCTAP_BIN" "$TMPDIR_TEST/settings.json"
}
