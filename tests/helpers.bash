# Aides partagées par les tests bats.

setup_sandbox() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$HOME" "$STUBS"
  export PATH="$STUBS:$PATH"
}

# make_stub <name> [exit_code]
make_stub() {
  local name="$1" code="${2:-0}"
  cat > "$STUBS/$name" <<STUB
#!/bin/bash
echo "$name \$*" >> "\$BATS_TEST_TMPDIR/calls.log"
exit $code
STUB
  chmod +x "$STUBS/$name"
}
