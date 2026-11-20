# Installeurs de sources tierces. Sourcer sans effet de bord (requiert lib/log.sh).

install_ecc() {
  npx -y ecc-universal@latest install --target claude --profile "$1" --no-hooks
}

install_plugin() {
  # L'échec est ignoré si la marketplace existe déjà.
  claude plugin marketplace add anthropics/claude-plugins-official || true
  # install peut échouer si déjà installé : seul le résultat de update compte.
  claude plugin install "$1" || true
  claude plugin update "$1"
}

install_skills() {
  npx -y skills@latest add "$1" -g -a claude-code -s "$2" -y
}

install_graphify() {
  if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh || return 1
  fi
  # uv installe ses binaires (graphify) dans ~/.local/bin.
  PATH="$HOME/.local/bin:$PATH"
  export PATH
  uv tool install --upgrade "$1" && (cd "$HOME" && graphify install)
}

# install_sources <fichier> : une source par ligne "<type> <arg1> [arg2]".
install_sources() {
  local file="$1" line type args
  [ -f "$file" ] || die "fichier de sources introuvable : $file"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2086
    set -- $line
    [ "$#" -gt 0 ] || continue
    type="$1"
    shift
    args="$*"
    if [ "$(type -t "install_$type")" = "function" ]; then
      # shellcheck disable=SC2086
      run_step "$type $args" "install_$type" $args
    else
      run_step "type inconnu : $type" false
    fi
  done < "$file"
}
