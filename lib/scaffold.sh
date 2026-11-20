# Fonctions partagées par les scripts de création de projet (bin/new-*).
# À sourcer : ne produit aucun effet de bord.

# validate_project_name <nom> <nom-de-la-commande>
validate_project_name() {
  local name="$1" cmd_name="$2"
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
    echo "Nom invalide : « $name ». Attendu : minuscules, chiffres, « . », « _ » ou « - », sans espace ni « / »." >&2
    echo "Usage : $cmd_name <nom-du-projet>" >&2
    return 1
  fi
  if [ -e "$name" ]; then
    echo "Le dossier « $name » existe déjà." >&2
    return 1
  fi
  return 0
}

# initial_commit <message> <nom-de-repli>
# Identité de repli uniquement si user.email est vide ; config globale intacte.
initial_commit() {
  local message="$1" fallback_name="$2"
  git init -q
  git add -A
  if [ -n "$(git config user.email || true)" ]; then
    git commit -qm "$message"
  else
    git -c user.name="$fallback_name" -c user.email="$fallback_name@localhost" \
      commit -qm "$message"
  fi
}
