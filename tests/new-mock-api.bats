#!/usr/bin/env bats
load helpers

setup() {
  setup_sandbox
  REPO="$BATS_TEST_DIRNAME/.."
  SCRIPT="$REPO/bin/new-mock-api"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

@test "rejects invalid names" {
  local name
  for name in "MyApp" "a/b"; do
    run bash "$SCRIPT" "$name"
    [ "$status" -eq 1 ]
  done
  [ -z "$(ls -A "$WORK")" ]
}

@test "rejects existing directory" {
  mkdir demo
  run bash "$SCRIPT" demo
  [ "$status" -eq 1 ]
  [[ "$output" == *"existe déjà"* ]]
}

@test "scaffolds a working mock server" {
  [ "${RUN_SLOW:-}" = "1" ] || skip "test lent : définir RUN_SLOW=1"
  # Lancé via un lien symbolique, comme après install.sh.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  ln -s "$SCRIPT" "$BATS_TEST_TMPDIR/bin/new-mock-api"
  run "$BATS_TEST_TMPDIR/bin/new-mock-api" demo
  [ "$status" -eq 0 ]
  cd demo
  run npm test
  [ "$status" -eq 0 ]
  run npm run build
  [ "$status" -eq 0 ]
  [ -f dist/index.js ]
  [ ! -e dist/routes/users.test.js ]
  [ "$(git log --oneline | wc -l | tr -d ' ')" = "1" ]
  run node -e "const p=require('./package.json');process.exit(Object.keys(p.dependencies).length===2&&p.name==='demo'?0:1)"
  [ "$status" -eq 0 ]
}
