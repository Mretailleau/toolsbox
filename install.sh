#!/usr/bin/env bash
# Restaure un setup Claude Code : sources tierces, settings.json, CLAUDE.md, commande new-react-app.
set -u

REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# shellcheck source=lib/log.sh
. "$REPO_DIR/lib/log.sh"
# shellcheck source=lib/settings.sh
. "$REPO_DIR/lib/settings.sh"
# shellcheck source=lib/sources.sh
. "$REPO_DIR/lib/sources.sh"

for cmd in git node npx claude jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "prérequis manquant : $cmd"
done

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
ITERM_STATUS="$HOME/.config/iterm2/cc-status"
SOURCES="${TOOLSBOX_SOURCES:-$REPO_DIR/sources.txt}"

mkdir -p "$CLAUDE_DIR/commands" "$HOME/.local/bin"

# Sauvegardes horodatées avant toute modification.
stamp="$(date +%Y%m%d-%H%M%S)"
for f in "$SETTINGS" "$CLAUDE_MD"; do
  if [ -f "$f" ]; then
    cp -p "$f" "$f.bak.$stamp" || die "sauvegarde impossible : $f"
  fi
done

# État initial du PATH, avant que install_graphify ne le modifie.
local_bin_in_path=0
case ":$PATH:" in *":$HOME/.local/bin:"*) local_bin_in_path=1 ;; esac

install_sources "$SOURCES"

apply_settings() {
  local hooks="" tmp rc
  tmp="$(mktemp)" || return 1
  if [ -x "$ITERM_STATUS" ] && [ -f "$ITERM_STATUS" ]; then
    hooks="$(mktemp)" || { rm -f "$tmp"; return 1; }
    render_hooks "$REPO_DIR/config/hooks-iterm.json" "$HOME" > "$hooks" || { rm -f "$tmp" "$hooks"; return 1; }
  fi
  merge_settings "$SETTINGS" "$REPO_DIR/config/settings.json" "$hooks" > "$tmp"
  rc=$?
  [ -n "$hooks" ] && rm -f "$hooks"
  if [ "$rc" -eq 0 ]; then
    mv "$tmp" "$SETTINGS"
  else
    rm -f "$tmp"
    return 1
  fi
}
run_step "settings.json" apply_settings

copy_claude_md() {
  if [ ! -s "$CLAUDE_MD" ]; then
    cp "$REPO_DIR/config/CLAUDE.md" "$CLAUDE_MD"
  fi
}
run_step "CLAUDE.md" copy_claude_md

link_new_react_app() {
  ln -sfn "$REPO_DIR/commands/new-react-app.md" "$CLAUDE_DIR/commands/new-react-app.md" &&
    ln -sfn "$REPO_DIR/bin/new-react-app" "$HOME/.local/bin/new-react-app"
}
run_step "commande new-react-app" link_new_react_app

if [ "$local_bin_in_path" -eq 0 ]; then
  echo "Ajoutez cette ligne à ~/.zshrc :"
  echo 'export PATH="$HOME/.local/bin:$PATH"'
fi

print_summary
exit $?
