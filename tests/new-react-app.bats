#!/usr/bin/env bats
load helpers

setup() {
  setup_sandbox
  REPO="$BATS_TEST_DIRNAME/.."
  SCRIPT="$REPO/bin/new-react-app"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

@test "rejects invalid names" {
  local name
  for name in "" "../x" "a/b" "MyApp" "my app"; do
    run bash "$SCRIPT" "$name"
    [ "$status" -eq 1 ]
  done
  [ -z "$(ls -A "$WORK")" ]
  [ ! -e "$BATS_TEST_TMPDIR/x" ]
}

@test "rejects existing directory" {
  mkdir demo
  run bash "$SCRIPT" demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"existe déjà"* ]]
}

@test "scaffolds a working project" {
  [ "${RUN_SLOW:-}" = "1" ] || skip "test lent : définir RUN_SLOW=1"
  # Lancé via un lien symbolique, comme après install.sh.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  ln -s "$SCRIPT" "$BATS_TEST_TMPDIR/bin/new-react-app"
  run "$BATS_TEST_TMPDIR/bin/new-react-app" demo
  [ "$status" -eq 0 ]
  cd demo
  [ -d node_modules/react-router ]
  [ ! -e src/App.tsx ]
  run npx vitest run
  [ "$status" -eq 0 ]
  run npm run build
  [ "$status" -eq 0 ]
  [ "$(git log --oneline | wc -l | tr -d ' ')" = "1" ]
}
