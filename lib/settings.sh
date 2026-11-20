# Fusion de settings.json. Sourcer sans effet de bord.

# render_hooks <template_path> <home> : stdout, remplace __HOME__ par <home>.
render_hooks() {
  local template="$1" home="$2"
  [ -f "$template" ] || { echo "template introuvable : $template" >&2; return 1; }
  # Échappe \ & et le délimiteur | pour sed.
  local esc
  esc=$(printf '%s' "$home" | sed -e 's/[\\&|]/\\&/g') || return 1
  sed "s|__HOME__|$esc|g" "$template"
}

# merge_settings <existing_or_empty> <repo_settings> <hooks_or_empty> : JSON fusionné sur stdout.
merge_settings() {
  local existing="$1" repo="$2" hooks="$3"
  local base hooks_in
  base=$(mktemp) || return 1
  hooks_in=$(mktemp) || { rm -f "$base"; return 1; }
  if [ -n "$existing" ] && [ -f "$existing" ] && grep -q "[^[:space:]]" "$existing"; then cat "$existing" > "$base"; else echo '{}' > "$base"; fi
  if [ -n "$hooks" ] && [ -f "$hooks" ]; then cat "$hooks" > "$hooks_in"; else echo '{}' > "$hooks_in"; fi
  jq -s '
    def cmds: [.hooks[]?.command];
    .[0] as $ex | .[1] as $repo | (.[2].hooks // {}) as $h
    | ($ex + ($repo | del(.enabledPlugins, .hooks)))
    | .enabledPlugins = (($ex.enabledPlugins // {}) * ($repo.enabledPlugins // {}))
    | reduce ($h | keys[]) as $ev (.;
        ($h[$ev] | map(cmds) | add // []) as $mine
        | .hooks[$ev] = ((.hooks[$ev] // [] | map(select((cmds | map(IN($mine[])) | any) | not))) + $h[$ev]))
  ' "$base" "$repo" "$hooks_in"
  local rc=$?
  rm -f "$base" "$hooks_in"
  return $rc
}
