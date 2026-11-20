#!/usr/bin/env bats
load helpers

setup() {
  setup_sandbox
  source "$BATS_TEST_DIRNAME/../lib/log.sh"
  source "$BATS_TEST_DIRNAME/../lib/sources.sh"
  SRC="$BATS_TEST_TMPDIR/sources.txt"
}

write_src() { printf '%s\n' "$@" > "$SRC"; }

@test "ecc invoked with minimal profile" {
  make_stub npx
  write_src "ecc minimal"
  install_sources "$SRC"
  grep -qx "npx -y ecc-universal@latest install --target claude --profile minimal --no-hooks" "$BATS_TEST_TMPDIR/calls.log"
}

@test "plugin installs then updates" {
  make_stub claude
  write_src "plugin superpowers@claude-plugins-official"
  install_sources "$SRC"
  i=$(grep -n "^claude plugin install superpowers@claude-plugins-official$" "$BATS_TEST_TMPDIR/calls.log" | cut -d: -f1)
  u=$(grep -n "^claude plugin update superpowers@claude-plugins-official$" "$BATS_TEST_TMPDIR/calls.log" | cut -d: -f1)
  [ -n "$i" ] && [ -n "$u" ] && [ "$i" -lt "$u" ]
}

@test "skills passes repo and skill globally" {
  make_stub npx
  write_src "skills Jeffallan/claude-skills react-expert"
  install_sources "$SRC"
  grep -qx "npx -y skills@latest add Jeffallan/claude-skills -g -a claude-code -s react-expert -y" "$BATS_TEST_TMPDIR/calls.log"
}

@test "graphify installs uv when missing" {
  PATH="$STUBS:/usr/bin:/bin"
  make_stub graphify
  cat > "$STUBS/curl" <<'STUB'
#!/bin/bash
echo "curl $*" >> "$BATS_TEST_TMPDIR/calls.log"
printf '#!/bin/bash\necho "uv $*" >> "$BATS_TEST_TMPDIR/calls.log"\n' > "$STUBS/uv"
chmod +x "$STUBS/uv"
echo 'true'
STUB
  chmod +x "$STUBS/curl"
  write_src "graphify graphifyy"
  install_sources "$SRC"
  run cat "$BATS_TEST_TMPDIR/calls.log"
  [[ "${lines[0]}" == curl* ]]
  [ "${lines[1]}" = "uv tool install --upgrade graphifyy" ]
  [ "${lines[2]}" = "graphify install" ]
}

@test "one failing source does not stop others" {
  make_stub npx 1
  make_stub claude
  write_src "ecc minimal" "plugin superpowers@claude-plugins-official"
  install_sources "$SRC"
  run print_summary
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ ecc minimal"* ]]
  [[ "$output" == *"✓ plugin superpowers@claude-plugins-official"* ]]
}

@test "comments, blank lines and unknown types" {
  write_src "# x" "" "foo bar"
  install_sources "$SRC"
  run print_summary
  [ "$status" -eq 1 ]
  [ "$output" = "✗ type inconnu : foo" ]
}

@test "plugin update still runs when install fails (already installed)" {
  cat > "$STUBS/claude" <<'STUB'
#!/bin/bash
echo "claude $*" >> "$BATS_TEST_TMPDIR/calls.log"
[ "$2" = "install" ] && exit 1
exit 0
STUB
  chmod +x "$STUBS/claude"
  write_src "plugin x@y"
  install_sources "$SRC"
  grep -qx "claude plugin update x@y" "$BATS_TEST_TMPDIR/calls.log"
  run print_summary
  [ "$status" -eq 0 ]
}

@test "graphify finds uv tool binaries in ~/.local/bin when uv already present" {
  PATH="$STUBS:/usr/bin:/bin"
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/bash\necho "uv $*" >> "$BATS_TEST_TMPDIR/calls.log"\nprintf "#!/bin/bash\\necho graphify \\$*>>\\"\\$BATS_TEST_TMPDIR/calls.log\\"\\n" > "$HOME/.local/bin/graphify"; chmod +x "$HOME/.local/bin/graphify"\n' > "$STUBS/uv"
  chmod +x "$STUBS/uv"
  write_src "graphify graphifyy"
  install_sources "$SRC"
  run print_summary
  [ "$status" -eq 0 ]
}
