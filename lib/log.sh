# Journal des étapes : exécute, isole les échecs, résume. Sourcer sans effet de bord.

STEP_RESULTS=""

# run_step <label> <cmd...> : renvoie toujours 0 pour isoler l'échec.
run_step() {
  local label="$1"
  shift
  echo "→ $label"
  if "$@"; then
    STEP_RESULTS="${STEP_RESULTS}✓ ${label}"$'\n'
  else
    STEP_RESULTS="${STEP_RESULTS}✗ ${label}"$'\n'
  fi
  return 0
}

# print_summary : affiche les résultats, renvoie 1 si au moins un échec.
print_summary() {
  printf '%s' "$STEP_RESULTS"
  case "$STEP_RESULTS" in
    *"✗ "*) return 1 ;;
  esac
  return 0
}

# die <message>
die() {
  echo "Erreur : $*" >&2
  exit 1
}
