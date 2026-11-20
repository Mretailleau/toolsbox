#!/usr/bin/env bats
load helpers

setup() {
  setup_sandbox
  export GIT_CONFIG_GLOBAL=/dev/null
  LIB="$BATS_TEST_DIRNAME/../lib/scaffold.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

@test "validate_project_name accepts valid name" {
  run bash -c 'source "$1"; validate_project_name demo-1.x foo' _ "$LIB"
  [ "$status" -eq 0 ]
}

@test "validate_project_name rejects invalid names" {
  local name
  for name in "" "../x" "a/b" "MyApp" "my app"; do
    run bash -c 'source "$1"; validate_project_name "$2" foo' _ "$LIB" "$name"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage : foo <nom-du-projet>"* ]]
  done
}

@test "validate_project_name rejects existing dir" {
  mkdir demo
  run bash -c 'source "$1"; validate_project_name demo foo' _ "$LIB"
  [ "$status" -eq 1 ]
  [[ "$output" == *"existe déjà"* ]]
}

@test "initial_commit uses fallback identity without git email" {
  echo hi > file.txt
  run bash -c 'set -euo pipefail; source "$1"; initial_commit "chore: x" "gen"' _ "$LIB"
  [ "$status" -eq 0 ]
  [ "$(git log --format='%an %ae')" = "gen gen@localhost" ]
  [ "$(git log --oneline | wc -l | tr -d ' ')" = "1" ]
}
