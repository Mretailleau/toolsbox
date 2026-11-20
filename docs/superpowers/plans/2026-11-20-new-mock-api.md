# new-mock-api — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** ajouter à toolsbox `new-mock-api <nom>`, qui génère un serveur de mock Hono + TypeScript, et la commande Claude `/new-mock-api`.

**Architecture :** les fonctions communes aux deux générateurs (validation du nom, commit initial) sont extraites dans `lib/scaffold.sh`. `bin/new-mock-api` copie un gabarit `templates/mock-api/` puis installe les dépendances en dernière version. `install.sh` crée les liens des deux générateurs.

**Tech Stack :** bash 3.2, bats-core. Projet généré : Node 22, TypeScript (ESM, NodeNext, strict), hono, @hono/node-server, tsx, vitest, @types/node.

**Spec :** `docs/superpowers/specs/2026-11-20-new-mock-api-design.md` (contexte : `docs/superpowers/specs/2026-11-20-claude-toolsbox-design.md`)

## Global Constraints

- Dépôt public : aucun chemin absolu personnel ni email.
- Bash 3.2 : pas de tableaux associatifs, pas de `sed -i` sans suffixe, pas de `readlink -f`.
- Messages utilisateur en français.
- Règle de nom : `^[a-z0-9][a-z0-9._-]*$`. Refus (exit 1) si le dossier cible existe.
- Projet généré : 2 dépendances d'exécution exactement, `hono` et `@hono/node-server`.
- Identité git de repli pour le commit initial, avec le nom du générateur comme `user.name` et `<générateur>@localhost` comme `user.email`, uniquement si `user.email` est vide. La config globale n'est jamais modifiée.
- `npm test` reste rapide et hors ligne. Les tests lents ne tournent qu'avec `RUN_SLOW=1`.

## Review Focus

1. **`new-react-app` après la refacto** : il se comporte exactement comme avant. Les tests rapides existants passent sans modification, et le test lent React repasse (Task 1).
2. **`POST /users` avec un corps qui n'est pas du JSON valide** : réponse 400 `{ "error": … }`, pas 500 (Task 2).
3. **`?delay=abc` ou une valeur négative** : la requête est ignorée sans délai, pas de crash ni d'attente infinie. Le délai est plafonné à 10 000 ms (Task 2).
4. **`GET /users/:id` avec un id non numérique** : 404 (Task 2).
5. **Port déjà pris** : le message d'erreur Node standard suffit. Aucun test, c'est noté ici pour mémoire.

---

### Task 1 : `lib/scaffold.sh` partagé et refacto de `new-react-app`

**Files :**
- Create : `lib/scaffold.sh`, `tests/scaffold.bats`
- Modify : `bin/new-react-app` (utiliser les fonctions partagées, comportement identique)

**Interfaces :**
- Produces (le fichier peut être sourcé sans effet de bord) :
  - `validate_project_name <name> <cmd_name>` : renvoie 0 si le nom est valide et le dossier `./<name>` absent. Sinon, message en français sur stderr (`Nom invalide : …` et `Usage : <cmd_name> <nom-du-projet>`, ou `Le dossier « <name> » existe déjà.`) et retour 1.
  - `initial_commit <message> <fallback_name>` : `git init -q && git add -A`, puis commit avec repli `-c user.name=<fallback_name> -c user.email=<fallback_name>@localhost` si `user.email` est vide.
- La boucle de résolution des liens (5 lignes) reste dans chaque script, car il faut connaître `ROOT` avant de pouvoir sourcer `lib/`. `bin/new-react-app` source ensuite `"$ROOT/lib/scaffold.sh"`.

- [ ] **Step 1 : tests qui échouent** dans `tests/scaffold.bats` :
  - `validate_project_name accepts valid name` : `demo-1.x` donne status 0.
  - `validate_project_name rejects invalid names` : pour `""`, `"../x"`, `"a/b"`, `"MyApp"`, `"my app"`, status 1 et une sortie qui contient `Usage : foo <nom-du-projet>` (cmd_name=`foo`).
  - `validate_project_name rejects existing dir` : après `mkdir demo`, status 1 et la sortie contient `existe déjà`.
  - `initial_commit uses fallback identity without git email` : avec `HOME` et `GIT_CONFIG_GLOBAL=/dev/null` dans le sandbox, un fichier puis `initial_commit "chore: x" "gen"`. Ensuite `git log --format='%an %ae'` vaut `gen gen@localhost` et il y a 1 commit.
- [ ] **Step 2 :** `npx bats tests/scaffold.bats` → FAIL.
- [ ] **Step 3 :** implémenter `lib/scaffold.sh` et l'utiliser dans `bin/new-react-app`.
- [ ] **Step 4 :** `npm test` → PASS (les tests `new-react-app` existants sont inchangés). `RUN_SLOW=1 npx bats tests/new-react-app.bats` → PASS.
- [ ] **Step 5 :** commit `refactor: share project name validation and initial commit`.

### Task 2 : `new-mock-api`, gabarit et commande Claude

**Files :**
- Create : `bin/new-mock-api` (exécutable), `commands/new-mock-api.md`, `templates/mock-api/` (`package.json`, `tsconfig.json`, `.gitignore`, `README.md`, `src/index.ts`, `src/app.ts`, `src/helpers.ts`, `src/routes/users.ts`, `src/routes/users.test.ts`)
- Test : `tests/new-mock-api.bats`

**Interfaces :**
- Consumes : `validate_project_name`, `initial_commit` (Task 1).
- Produces : `new-mock-api <name>`.

Script :
1. Résolution de `ROOT` (même boucle que `new-react-app`), `source "$ROOT/lib/scaffold.sh"`, `validate_project_name "$name" new-mock-api || exit 1`, puis vérification que `templates/mock-api` existe.
2. `mkdir "$name" && cp -R "$TEMPLATE/." "$name"`, `cd "$name"`, `npm pkg set name="$name"`.
3. `npm i hono @hono/node-server` puis `npm i -D typescript tsx vitest @types/node`.
4. `initial_commit "chore: scaffold $name" new-mock-api`.
5. Afficher `cd <name> && npm run dev`, ainsi que `http://localhost:3000/users`.

Gabarit (valeurs exactes) :
- `package.json` : `"type": "module"`, `"private": true`, et les scripts `dev: "tsx watch src/index.ts"`, `start: "node dist/index.js"`, `build: "tsc"`, `test: "vitest run"`. Pas de dépendances listées, l'étape 3 les ajoute.
- `tsconfig.json` : `target ES2022`, `module NodeNext`, `moduleResolution NodeNext`, `strict`, `outDir dist`, `rootDir src`, `skipLibCheck`, `types ["node"]`, et `exclude ["src/**/*.test.ts"]` pour que `dist/` ne contienne pas les tests. Les imports relatifs prennent l'extension `.js`.
- `.gitignore` : `node_modules/`, `dist/`.
- `src/app.ts` : exporte `app` (un `Hono`), avec `logger()`, `cors()`, `delayFromQuery` (voir helpers) et `app.route('/users', users)`. Un `GET /` renvoie `{ status: 'ok' }`.
- `src/index.ts` : `serve({ fetch: app.fetch, port: Number(process.env.PORT ?? 3000) })` et log de `Mock API sur http://localhost:<port>`.
- `src/helpers.ts` :
  - `delay(ms: number): Promise<void>` ;
  - `fail(c: Context, status: ContentfulStatusCode, message: string)` qui renvoie `c.json({ error: message }, status)` ;
  - `delayFromQuery: MiddlewareHandler` qui lit `?delay`. Il l'ignore si ce n'est pas un entier ≥ 0, et le plafonne à `MAX_DELAY_MS = 10_000`.
- `src/routes/users.ts` : `type User = { id: number; name: string }`, un tableau en mémoire de 2 utilisateurs (`Ada`, `Linus`) et un compteur d'id.
  - `GET /` → 200 avec la liste.
  - `GET /:id` → 200, ou 404 `Utilisateur introuvable` (un id non numérique donne aussi 404).
  - `POST /` → 400 `JSON invalide` si le corps ne se parse pas, 400 `Le champ name est requis` si `name` n'est pas une chaîne non vide, sinon 201 avec l'objet créé.
  - `DELETE /:id` → 204 sans corps, ou 404.
  - Exporte aussi `resetUsers()` pour isoler les tests.
- `src/routes/users.test.ts` (Vitest, via `app.request`, avec `resetUsers()` en `beforeEach`) :
  - `GET /users returns seed list` (200, longueur 2) ;
  - `GET /users/1 returns Ada` ;
  - `GET /users/999 returns 404 with error body` ;
  - `GET /users/abc returns 404` ;
  - `POST /users creates user` (201, `name` renvoyé, puis `GET` donne une longueur 3) ;
  - `POST /users without name returns 400` ;
  - `POST /users with invalid JSON returns 400` ;
  - `DELETE /users/1 returns 204 then 404 on second delete` ;
  - `delay query param waits` (`?delay=50`, au moins 45 ms écoulées) ;
  - `invalid delay is ignored` (`?delay=abc` donne 200).
- `README.md` du gabarit : comment ajouter une route, et comment utiliser `fail`, `delay` et `?delay=`.

`commands/new-mock-api.md` : frontmatter `description: Crée un serveur de mock Node + TypeScript (Hono) avec routes GET/POST/DELETE` et `argument-hint: <nom-du-projet>`. Le corps est construit comme `commands/new-react-app.md`, avec le même repli sur `~/.local/bin/new-mock-api`, et résume les commandes `dev`, `test` et `build`.

- [ ] **Step 1 : tests qui échouent (rapides)** dans `tests/new-mock-api.bats` :
  - `rejects invalid names` : `"MyApp"` et `"a/b"` donnent status 1, et aucun dossier n'est créé.
  - `rejects existing directory` : status 1 et `existe déjà`.
- [ ] **Step 2 : test lent** (`RUN_SLOW=1`) `scaffolds a working mock server`. On lance le script via un lien symbolique dans `$BATS_TEST_TMPDIR`. Ensuite, dans `demo` : `npm test` → 0, `npm run build` → 0, `dist/index.js` existe, `dist/routes/users.test.js` n'existe pas, `git log --oneline | wc -l` = 1, et `node -e "const p=require('./package.json');process.exit(Object.keys(p.dependencies).length===2&&p.name==='demo'?0:1)"` → 0.
- [ ] **Step 3 :** `npm test` → FAIL.
- [ ] **Step 4 :** implémenter le script, le gabarit et la commande.
- [ ] **Step 5 :** `npm test` → PASS. `RUN_SLOW=1 npx bats tests/new-mock-api.bats` → PASS.
- [ ] **Step 6 :** commit `feat: add new-mock-api scaffolder and /new-mock-api command`.

### Task 3 : liens dans `install.sh` et README

**Files :**
- Modify : `install.sh` (fonction et étape de liens), `README.md`
- Test : `tests/install.bats`

**Interfaces :**
- `install.sh` : remplacer `link_new_react_app` par `link_scaffolder <name>`, qui exécute `ln -sfn` pour `commands/<name>.md` et pour `bin/<name>`. L'appeler avec `run_step "commande <name>" link_scaffolder <name>` pour `new-react-app`, puis pour `new-mock-api`.

- [ ] **Step 1 : test qui échoue** dans `tests/install.bats` : `links new-mock-api` vérifie que `~/.local/bin/new-mock-api` est un lien qui se résout et que `~/.claude/commands/new-mock-api.md` existe. Les assertions existantes de `new-react-app` restent.
- [ ] **Step 2 :** `npx bats tests/install.bats` → FAIL.
- [ ] **Step 3 :** implémenter. Dans le README, ajouter une section `new-mock-api` (usage, routes d'exemple, `?delay=`, `fail`) et mentionner `new-mock-api` dans l'intro et dans la liste des actions d'`install.sh`. Mettre à jour le commentaire d'en-tête d'`install.sh`.
- [ ] **Step 4 :** `npm test` → PASS. Contrôle anti-fuite sur l'arbre : `git grep -nE "/Users/|@gmail|localhost:[0-9]+/Users"` → aucun résultat.
- [ ] **Step 5 :** commit `feat: install new-mock-api links and document it`.
