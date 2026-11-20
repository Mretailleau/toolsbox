# Claude toolsbox — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** dépôt public `toolsbox` dont `./install.sh` recrée la config Claude Code de l'utilisateur sur une nouvelle machine, et qui fournit `new-react-app`.

**Architecture :** scripts bash. `install.sh` orchestre des fonctions découpées dans `lib/` : journal des étapes, fusion des settings, installation des sources. Les sources tierces sont listées dans `sources.txt`. La fusion JSON passe par `jq`. Tests en bats-core (devDependency npm), avec de faux `npx`, `claude`, `uv`, `curl` placés dans le PATH, et un `HOME` temporaire.

**Tech Stack :** bash 3.2 compatible (bash par défaut sur macOS), jq, bats-core, Node/npm. Pour le template : Vite `react-ts`, React Router v7, Tailwind v4 (`@tailwindcss/vite`), Vitest, Testing Library, jsdom.

**Spec :** `docs/superpowers/specs/2026-11-20-claude-toolsbox-design.md`

## Global Constraints

- Dépôt **public** : aucun chemin absolu personnel, aucune adresse email, ni contenu de `projects/`, `sessions/`, `history.jsonl`.
- Aucun contenu tiers copié dans le dépôt, seulement des références.
- Bash portable macOS et Linux : pas de `sed -i` sans suffixe, pas de `readlink -f`, pas de tableaux associatifs (bash 3.2).
- Prérequis bloquants : `git`, `node`, `npx`, `claude`, `jq`. Si l'un manque, le script s'arrête avec un message clair **avant** de toucher quoi que ce soit. `uv` est installé automatiquement s'il manque.
- Sauvegarde `<fichier>.bak.<YYYYmmdd-HHMMSS>` de `~/.claude/settings.json` et `~/.claude/CLAUDE.md` existants avant modification.
- Un échec de source est journalisé, le script continue, le code de sortie final est 1. Sinon il est 0.
- Idempotent : deux exécutions consécutives donnent le même `settings.json`.
- Réglages : `model: "opus"`, `theme: "dark"`, `includeCoAuthoredBy: false`, `enabledPlugins` qui contient `superpowers@claude-plugins-official` et `mattpocock-skills@claude-plugins-official` à `true`.
- Hooks iTerm sur les événements `Notification`, `PermissionRequest`, `PostToolUse`, `PreToolUse`, `SessionEnd`, `SessionStart`, avec la commande `$HOME/.config/iterm2/cc-status` (chemin absolu calculé à l'installation). Ils ne sont ajoutés que si ce fichier existe et est exécutable.
- Messages utilisateur en français.

## Review Focus

1. **Relance d'`install.sh`** : le `settings.json` est identique, sans hooks dupliqués (testé en Task 2 et Task 4).
2. **Machine vierge sans `~/.claude`** : le dossier est créé, sans erreur ni sauvegarde fantôme (Task 4).
3. **Prérequis manquant** (par exemple `claude` absent) : arrêt immédiat, rien n'est écrit dans `HOME` (Task 4).
4. **Dépôt cloné dans un chemin avec espaces** : les liens `~/.local/bin/new-react-app` et `~/.claude/commands/new-react-app.md` fonctionnent (Task 4).
5. **`new-react-app` avec un nom invalide** (vide, `../x`, `a/b`, majuscules, espaces) ou un dossier existant : refus avec un code ≠ 0, rien n'est créé (Task 5).

---

### Task 1 : Squelette du dépôt et journal des étapes

**Files :**
- Create : `package.json` (privé, devDependency `bats`, scripts `"test": "bats tests"`), `.gitignore` (`node_modules/`, `*.bak.*`, `.DS_Store`), `README.md`, `lib/log.sh`
- Test : `tests/log.bats`, `tests/helpers.bash`

**Interfaces :**
- Produces :
  - `run_step <label> <cmd...>` : exécute la commande, affiche `→ <label>`, enregistre `✓ <label>` ou `✗ <label>`, et renvoie toujours 0 (pour isoler l'échec).
  - `print_summary` : affiche toutes les lignes enregistrées puis renvoie 1 si au moins un `✗`, sinon 0.
  - `die <message>` : écrit `Erreur : <message>` sur stderr puis `exit 1`.
  - `tests/helpers.bash` : `setup_sandbox` crée `HOME=$BATS_TEST_TMPDIR/home` et `STUBS=$BATS_TEST_TMPDIR/stubs`, puis place `STUBS` en tête du PATH. `make_stub <name> [exit_code]` crée un exécutable qui ajoute `<name> $*` à `$BATS_TEST_TMPDIR/calls.log` puis sort avec `exit_code`.

- [ ] **Step 1 :** `git init`, créer `package.json`, `npm install`.
- [ ] **Step 2 : tests qui échouent** dans `tests/log.bats` :
  - `run_step records success` : `run_step "ok" true`, puis `print_summary` affiche `✓ ok` et renvoie 0.
  - `run_step isolates failure and continues` : `run_step "ko" false; run_step "ok" true`, puis `print_summary` affiche `✗ ko` et `✓ ok` et renvoie 1.
  - `die exits 1 with message` : `run die "boom"` → status 1, la sortie contient `Erreur : boom`.
- [ ] **Step 3 :** `npm test` → FAIL (`lib/log.sh` absent).
- [ ] **Step 4 :** implémenter `lib/log.sh`, avec les résultats gardés dans une variable globale chaîne séparée par des retours à la ligne (pas de tableau associatif). Écrire `tests/helpers.bash`.
- [ ] **Step 5 :** `npm test` → PASS.
- [ ] **Step 6 :** README minimal (quickstart `git clone https://github.com/<owner>/toolsbox.git ~/toolsbox && ~/toolsbox/install.sh`, prérequis, « ajouter une source = une ligne dans sources.txt »). Puis commit `chore: bootstrap toolsbox repo with step logger`.

### Task 2 : Fusion de `settings.json`

**Files :**
- Create : `config/settings.json`, `config/hooks-iterm.json`, `config/CLAUDE.md` (vide), `lib/settings.sh`
- Test : `tests/settings.bats`, `tests/fixtures/settings-existing.json`

**Interfaces :**
- Produces :
  - `merge_settings <existing_path_or_empty> <repo_settings_path> <hooks_path_or_empty>` : écrit le JSON fusionné sur stdout. Si `existing` est vide ou absent, on part de `{}`.
  - `render_hooks <template_path> <home>` : stdout, remplace le jeton `__HOME__` par `<home>`.
- `config/hooks-iterm.json` : `{"hooks": {"<Event>": [{"hooks": [{"type":"command","command":"__HOME__/.config/iterm2/cc-status"}]}]}}` pour les 6 événements des Global Constraints.

Règles de fusion (algorithme non déterminé par la signature) :
1. On part de `existing`. Les clés scalaires du dépôt écrasent les leurs (`model`, `theme`, `includeCoAuthoredBy`).
2. `enabledPlugins` = `existing.enabledPlugins * repo.enabledPlugins` (union d'objets, le dépôt l'emporte).
3. Pour chaque événement de `hooks_path`, on retire de `existing.hooks[event]` les groupes dont une commande est égale à une commande des groupes du dépôt pour cet événement, puis on ajoute les groupes du dépôt. Les autres événements et hooks restent intacts.
4. Les autres clés de `existing` sont conservées telles quelles.

- [ ] **Step 1 : tests qui échouent** :
  - `merge on empty existing yields repo settings` : `.model=="opus"`, `.theme=="dark"`, `.includeCoAuthoredBy==false`, les deux plugins à `true`, pas de clé `hooks`.
  - `repo scalars win, foreign keys kept` : la fixture a `model:"sonnet"`, `permissions:{allow:["Bash(ls)"]}` et `enabledPlugins:{"ecc@ecc":true}`. Résultat : `model=="opus"`, `permissions` inchangé, 3 plugins.
  - `iterm hooks added with absolute home` : `render_hooks` avec `/tmp/h`, puis `merge`. `.hooks.SessionStart[0].hooks[0].command=="/tmp/h/.config/iterm2/cc-status"` et 6 événements présents.
  - `merge is idempotent` : `merge(merge(x))` est égal à `merge(x)` à l'octet près (comparer `jq -S`). Chaque événement a exactement 1 groupe cc-status.
  - `unrelated hooks preserved` : la fixture a `PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:"other"}]}]`. Le résultat contient `other` **et** cc-status.
- [ ] **Step 2 :** `npm test` → FAIL.
- [ ] **Step 3 :** implémenter `lib/settings.sh` avec `jq -s`, et écrire les fichiers `config/`.
- [ ] **Step 4 :** `npm test` → PASS.
- [ ] **Step 5 :** commit `feat: merge personal settings and iTerm hooks idempotently`.

### Task 3 : Installation des sources

**Files :**
- Create : `sources.txt`, `lib/sources.sh`
- Test : `tests/sources.bats`

**Interfaces :**
- Consumes : `run_step` (Task 1), `make_stub` (Task 1).
- Produces : `install_sources <sources_file>` lit chaque ligne non vide et hors `#`, découpée en `<type> <arg1> [arg2]`, et appelle `run_step "<type> <arg1> [arg2]" install_<type> <args>`. Un type inconnu donne un `✗` avec le libellé `type inconnu : <type>`.

`sources.txt` exact :
```
# type      argument(s)
ecc         minimal
plugin      superpowers@claude-plugins-official
plugin      mattpocock-skills@claude-plugins-official
skills      vercel-labs/agent-skills vercel-react-best-practices
skills      Jeffallan/claude-skills react-expert
graphify    graphifyy
```

Commandes de chaque installeur (valeurs exactes) :
- `install_ecc <profile>` : `npx -y ecc-universal@latest install --target claude --profile <profile> --no-hooks`
- `install_plugin <id>` : `claude plugin marketplace add anthropics/claude-plugins-official` (son échec est ignoré si la marketplace existe déjà), puis `claude plugin install <id>`, puis `claude plugin update <id>`.
- `install_skills <repo> <skill>` : `npx -y skills@latest add <repo> -g -a claude-code -s <skill> -y`. **À vérifier au Step 1** : l'identifiant d'agent Claude Code attendu par `skills` (avec `npx -y skills@latest add vercel-labs/agent-skills --help` ou sa doc). S'il diffère de `claude-code`, utiliser le bon et le noter dans le commit.
- `install_graphify <pkg>` : si `uv` est absent, `curl -LsSf https://astral.sh/uv/install.sh | sh` puis ajouter `$HOME/.local/bin` au PATH du processus. Ensuite `uv tool install --upgrade <pkg>` puis `graphify install`.

- [ ] **Step 1 :** vérifier l'identifiant d'agent de `skills` (voir ci-dessus).
- [ ] **Step 2 : tests qui échouent** (stubs `npx`, `claude`, `uv`, `graphify`, `curl`) :
  - `ecc invoked with minimal profile` : `calls.log` contient `npx -y ecc-universal@latest install --target claude --profile minimal --no-hooks`.
  - `plugin installs then updates` : pour `superpowers@claude-plugins-official`, on retrouve `claude plugin install …` puis `claude plugin update …`, dans cet ordre.
  - `skills passes repo and skill globally` : contient `npx -y skills@latest add Jeffallan/claude-skills -g -a claude-code -s react-expert -y`.
  - `graphify installs uv when missing` : sans stub `uv` au départ, le stub `curl` est appelé (il crée lui-même un stub `uv`), puis `uv tool install --upgrade graphifyy` puis `graphify install`.
  - `one failing source does not stop others` : stub `npx` en exit 1. Le résumé contient `✗ ecc minimal` et `✓ plugin superpowers@claude-plugins-official`, et `print_summary` renvoie 1.
  - `comments, blank lines and unknown types` : un fichier temporaire avec `# x`, une ligne vide et `foo bar`. Une seule ligne de résumé, `✗ type inconnu : foo`.
- [ ] **Step 3 :** `npm test` → FAIL.
- [ ] **Step 4 :** implémenter `lib/sources.sh` et écrire `sources.txt`.
- [ ] **Step 5 :** `npm test` → PASS.
- [ ] **Step 6 :** commit `feat: install third-party sources from sources.txt`.

### Task 4 : `install.sh`

**Files :**
- Create : `install.sh` (exécutable)
- Test : `tests/install.bats`

**Interfaces :**
- Consumes : `die`, `run_step`, `print_summary` (Task 1), `merge_settings`, `render_hooks` (Task 2), `install_sources` (Task 3).
- Produces : `install.sh`, sans argument. La variable d'env `TOOLSBOX_SOURCES` remplace le chemin de `sources.txt` (utilisé par les tests).

Ordre exact :
1. `REPO_DIR` = dossier réel du script (`cd "$(dirname "$0")" && pwd -P`). Chemins entre guillemets partout.
2. Vérifier les prérequis (`git node npx claude jq`), sinon `die "prérequis manquant : <cmd>"`.
3. `mkdir -p "$HOME/.claude/commands" "$HOME/.local/bin"`.
4. Sauvegarder `settings.json` et `CLAUDE.md` s'ils existent.
5. `install_sources`.
6. `merge_settings` vers un fichier temporaire, puis `mv` vers `~/.claude/settings.json`. Les hooks ne sont inclus que si `$HOME/.config/iterm2/cc-status` est exécutable.
7. Copier `config/CLAUDE.md` seulement si `~/.claude/CLAUDE.md` est absent ou vide.
8. `ln -sfn "$REPO_DIR/commands/new-react-app.md" ~/.claude/commands/new-react-app.md` et `ln -sfn "$REPO_DIR/bin/new-react-app" ~/.local/bin/new-react-app`. Si `~/.local/bin` n'est pas dans le PATH, afficher la ligne `export PATH="$HOME/.local/bin:$PATH"` à ajouter à `~/.zshrc`.
9. `print_summary` ; son code devient celui du script.

- [ ] **Step 1 : tests qui échouent** (sandbox et stubs, `TOOLSBOX_SOURCES` pointe vers un fichier qui contient `plugin x@y`) :
  - `fresh machine without ~/.claude` : status 0, `settings.json` contient `model=="opus"`, aucun fichier `*.bak.*`.
  - `existing settings backed up` : un `settings.json` préexistant laisse exactement un `settings.json.bak.*` avec le contenu d'origine.
  - `rerun is idempotent` : deux exécutions donnent un `settings.json` identique (`jq -S`).
  - `iterm hooks only when cc-status exists` : sans le fichier, pas de `.hooks`. Avec un `cc-status` exécutable, 6 événements.
  - `missing prerequisite aborts before writing` : PATH sans `claude` (stubs uniquement pour le reste, plus `/usr/bin:/bin`). Status 1, sortie `prérequis manquant : claude`, `$HOME/.claude` n'existe pas.
  - `repo path with spaces` : copier le dépôt dans `$BATS_TEST_TMPDIR/my repo` et l'exécuter. `~/.local/bin/new-react-app` est un lien qui se résout vers un fichier existant.
  - `failed source gives exit 1 but settings still applied` : stub `claude` en exit 1. Status 1, `settings.json` présent.
- [ ] **Step 2 :** `npm test` → FAIL.
- [ ] **Step 3 :** implémenter `install.sh`. Créer `bin/new-react-app` et `commands/new-react-app.md` comme placeholders s'ils n'existent pas encore (la Task 5 les remplit).
- [ ] **Step 4 :** `npm test` → PASS.
- [ ] **Step 5 :** commit `feat: add install.sh orchestrating restore and sources`.

### Task 5 : `new-react-app`

**Files :**
- Create : `bin/new-react-app` (exécutable), `commands/new-react-app.md`, `templates/react-app/` (`vite.config.ts`, `src/main.tsx`, `src/router.tsx`, `src/routes/Layout.tsx`, `src/routes/Home.tsx`, `src/routes/About.tsx`, `src/index.css`, `src/test/setup.ts`, `src/routes/Home.test.tsx`)
- Test : `tests/new-react-app.bats`

**Interfaces :**
- Produces : `new-react-app <name>`, avec un nom qui doit correspondre à `^[a-z0-9][a-z0-9._-]*$` et un dossier `./<name>` inexistant. Sinon, message en français et exit 1.

Étapes du script (valeurs exactes) :
1. `npm create vite@latest <name> -- --template react-ts --no-interactive` (si ce flag n'existe pas dans la version courante, utiliser l'équivalent non interactif ; vérifier avec `npm create vite@latest -- --help`).
2. `npm i react-router` puis `npm i -D tailwindcss @tailwindcss/vite vitest @vitest/coverage-v8 jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event`.
3. Copier `templates/react-app/` par-dessus, en écrasant. `vite.config.ts` utilise `react()` + `tailwindcss()` et `test: { environment: 'jsdom', setupFiles: './src/test/setup.ts', globals: true }` (avec `/// <reference types="vitest/config" />`). `index.css` = `@import "tailwindcss";`. `router.tsx` = `createBrowserRouter` avec Layout, `/` → Home et `/about` → About. `main.tsx` = `RouterProvider`. Supprimer `src/App.tsx`, `src/App.css` et l'asset `react.svg` s'il n'est plus importé.
4. Ajouter à `package.json` les scripts `"test": "vitest"` et `"test:coverage": "vitest run --coverage"` (via `npm pkg set`). Ajouter `"types": ["vitest/globals", "@testing-library/jest-dom"]` dans `tsconfig.app.json`.
5. `git init -q && git add -A && git commit -qm "chore: scaffold <name>"`.
6. Afficher `cd <name> && npm run dev`.

`Home.test.tsx` : rend Home dans un `MemoryRouter` et vérifie qu'un `heading` contenant `<name>`, ou un texte d'accueil fixe, est présent.

`commands/new-react-app.md` : frontmatter `description: Crée un projet React + TS + Vitest + React Router + Tailwind` et `argument-hint: <nom-du-projet>`. Le corps demande de lancer `new-react-app $ARGUMENTS` dans le dossier courant, puis de résumer la structure créée et les commandes `dev`, `test` et `build`.

- [ ] **Step 1 : tests qui échouent (rapides, sans réseau)** :
  - `rejects invalid names` : pour `""`, `"../x"`, `"a/b"`, `"MyApp"`, `"my app"`, on a status 1 et aucun dossier créé.
  - `rejects existing directory` : `mkdir demo; run new-react-app demo` → status 1, message `existe déjà`.
- [ ] **Step 2 : test lent** (ignoré sauf si `RUN_SLOW=1`) `scaffolds a working project` : `new-react-app demo`, puis dans `demo` : `npx vitest run` → 0, `npm run build` → 0, `git log --oneline | wc -l` = 1, `node_modules/react-router` existe.
- [ ] **Step 3 :** `npm test` → FAIL.
- [ ] **Step 4 :** implémenter le script, le template et la commande.
- [ ] **Step 5 :** `npm test` → PASS. `RUN_SLOW=1 npx bats tests/new-react-app.bats` → PASS.
- [ ] **Step 6 :** commit `feat: add new-react-app scaffolder and /new-react-app command`.

### Task 6 : Publication et vérification réelle

**Files :**
- Modify : `README.md` (URL réelle du dépôt)

- [ ] **Step 1 : contrôle anti-fuite.** Chercher (`git grep -nE`) le préfixe des chemins absolus utilisateur, le nom d'utilisateur, le domaine email et `history\.jsonl` : aucun résultat attendu, `docs/` compris (remplacer tout chemin personnel par `~`). Vérifier aussi l'historique avec `git log --all -p` et `git log --all --format='%ae %ce'` (aucun email personnel).
- [ ] **Step 2 :** `npm test` → PASS.
- [ ] **Step 3 :** demander à l'utilisateur la confirmation de publier, puis `gh repo create toolsbox --public --source . --push --description "One-command Claude Code setup"`.
- [ ] **Step 4 : essai réel sur cette machine** (avec l'accord de l'utilisateur, puisque ça modifie `~/.claude`) : `./install.sh`. Le résumé est entièrement en ✓, ou les ✗ sont expliqués. `claude plugin list` montre les deux plugins. `~/.claude/skills` ou `~/.agents/skills` contient `vercel-react-best-practices` et `react-expert`. `graphify --version` fonctionne.
- [ ] **Step 5 :** commit `docs: finalize README with repo URL` et push.
