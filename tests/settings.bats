#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  source "$BATS_TEST_DIRNAME/../lib/settings.sh"
  REPO="$BATS_TEST_DIRNAME/.."
  FIX="$BATS_TEST_DIRNAME/fixtures/settings-existing.json"
  render_hooks "$REPO/config/hooks-iterm.json" "/tmp/h" > "$BATS_TEST_TMPDIR/hooks.json"
}

@test "merge on empty existing yields repo settings" {
  run merge_settings "" "$REPO/config/settings.json" ""
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.model=="opus" and .theme=="dark" and .includeCoAuthoredBy==false
    and .enabledPlugins["superpowers@claude-plugins-official"]==true
    and .enabledPlugins["mattpocock-skills@claude-plugins-official"]==true
    and (has("hooks")|not)'
}

@test "repo scalars win, foreign keys kept" {
  run merge_settings "$FIX" "$REPO/config/settings.json" ""
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.model=="opus" and .permissions=={"allow":["Bash(ls)"]}
    and (.enabledPlugins|length)==3'
}

@test "iterm hooks added with absolute home" {
  run merge_settings "" "$REPO/config/settings.json" "$BATS_TEST_TMPDIR/hooks.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hooks.SessionStart[0].hooks[0].command=="/tmp/h/.config/iterm2/cc-status"
    and (.hooks|keys|length)==6'
}

@test "merge is idempotent" {
  merge_settings "$FIX" "$REPO/config/settings.json" "$BATS_TEST_TMPDIR/hooks.json" > "$BATS_TEST_TMPDIR/a.json"
  merge_settings "$BATS_TEST_TMPDIR/a.json" "$REPO/config/settings.json" "$BATS_TEST_TMPDIR/hooks.json" > "$BATS_TEST_TMPDIR/b.json"
  [ "$(jq -S . "$BATS_TEST_TMPDIR/a.json")" = "$(jq -S . "$BATS_TEST_TMPDIR/b.json")" ]
  run jq -e '[.hooks[] | map(select(.hooks[].command | endswith("cc-status"))) | length] | all(. == 1)' "$BATS_TEST_TMPDIR/b.json"
  [ "$status" -eq 0 ]
}

@test "unrelated hooks preserved" {
  run merge_settings "$FIX" "$REPO/config/settings.json" "$BATS_TEST_TMPDIR/hooks.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.hooks.PreToolUse[].hooks[].command] | contains(["other","/tmp/h/.config/iterm2/cc-status"])'
}

@test "merge fails on invalid json" {
  echo '{bad' > "$BATS_TEST_TMPDIR/bad.json"
  run merge_settings "$BATS_TEST_TMPDIR/bad.json" "$REPO/config/settings.json" ""
  [ "$status" -ne 0 ]
}

@test "empty or whitespace-only existing is treated as empty object" {
  : > "$BATS_TEST_TMPDIR/empty.json"
  printf ' \n\t\n' > "$BATS_TEST_TMPDIR/ws.json"
  for f in empty ws; do
    run merge_settings "$BATS_TEST_TMPDIR/$f.json" "$REPO/config/settings.json" "$BATS_TEST_TMPDIR/hooks.json"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.model=="opus" and (.hooks|keys|length)==6'
  done
}
