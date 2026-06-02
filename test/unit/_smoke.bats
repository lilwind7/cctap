#!/usr/bin/env bats

load ../helpers/load
load ../helpers/setup

@test "bats can run" {
    run echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "PROJECT_ROOT is set" {
    [ -d "$PROJECT_ROOT" ]
}
