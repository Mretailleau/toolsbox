#!/usr/bin/env bats
load helpers

setup() {
  setup_sandbox
  REPO="$BATS_TEST_DIRNAME/.."
  export TOOLSBOX_SOURCES="$BATS_TEST_TMPDIR/sources.txt"
  echo "plugin x@y" > "$TOOLSBOX_SOURCES"
  make_stub npx
  make_stub claude
}

@test "fresh machine without ~/.claude" {
  run bash "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r .model "$HOME/.claude/settings.json")" = "opus" ]
  run bash -c 'ls "$HOME"/.claude/*.bak.* 2>/dev/null'
  [ -z "$output" ]
}

@test "existing settings backed up" {
  mkdir -p "$HOME/.claude"
  echo '{"theme":"dark"}' > "$HOME/.claude/settings.json"
  run bash "$REPO/install.sh"
  [ "$status" -eq 0 ]
  baks=("$HOME"/.claude/settings.json.bak.*)
  [ "${#baks[@]}" -eq 1 ]
  [ "$(cat "${baks[0]}")" = '{"theme":"dark"}' ]
}

@test "rerun is idempotent" {
  bash "$REPO/install.sh"
  jq -S . "$HOME/.claude/settings.json" > "$BATS_TEST_TMPDIR/a.json"
  bash "$REPO/install.sh"
  jq -S . "$HOME/.claude/settings.json" > "$BATS_TEST_TMPDIR/b.json"
  diff "$BATS_TEST_TMPDIR/a.json" "$BATS_TEST_TMPDIR/b.json"
}

@test "iterm hooks only when cc-status exists" {
  bash "$REPO/install.sh"
  [ "$(jq 'has("hooks")' "$HOME/.claude/settings.json")" = "false" ]
  mkdir -p "$HOME/.config/iterm2"
  printf '#!/bin/sh\n' > "$HOME/.config/iterm2/cc-status"
  chmod +x "$HOME/.config/iterm2/cc-status"
  bash "$REPO/install.sh"
  [ "$(jq '.hooks | keys | length' "$HOME/.claude/settings.json")" -eq 6 ]
}

@test "missing prerequisite aborts before writing" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for c in git node jq; do ln -s "$(command -v $c)" "$BATS_TEST_TMPDIR/bin/$c"; done
  ln -s "$STUBS/npx" "$BATS_TEST_TMPDIR/bin/npx"
  PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  run /bin/bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"prérequis manquant : claude"* ]]
  [ ! -e "$HOME/.claude" ]
}

@test "repo path with spaces" {
  mkdir -p "$BATS_TEST_TMPDIR/my repo"
  cp -R "$REPO/config" "$REPO/lib" "$REPO/bin" "$REPO/commands" "$REPO/install.sh" "$BATS_TEST_TMPDIR/my repo/"
  run bash "$BATS_TEST_TMPDIR/my repo/install.sh"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.local/bin/new-react-app" ]
  [ -e "$HOME/.local/bin/new-react-app" ]
  [ -e "$HOME/.claude/commands/new-react-app.md" ]
}

@test "failed source gives exit 1 but settings still applied" {
  make_stub claude 1
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [ -f "$HOME/.claude/settings.json" ]
}

@test "PATH hint printed even when graphify source adjusts PATH" {
  make_stub uv
  make_stub graphify
  echo "graphify graphifyy" > "$TOOLSBOX_SOURCES"
  run bash "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'export PATH="$HOME/.local/bin:$PATH"'* ]]
}
