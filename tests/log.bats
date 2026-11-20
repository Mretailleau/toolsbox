#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  source "$BATS_TEST_DIRNAME/../lib/log.sh"
}

@test "run_step records success" {
  run_step "ok" true
  run print_summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ ok"* ]]
}

@test "run_step isolates failure and continues" {
  run_step "ko" false
  run_step "ok" true
  run print_summary
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ ko"* ]]
  [[ "$output" == *"✓ ok"* ]]
}

@test "die exits 1 with message" {
  run die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Erreur : boom"* ]]
}
