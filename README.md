# toolsbox

Restaure en une commande un setup Claude Code sur une nouvelle machine : plugins, skills, réglages et hooks. Le dépôt fournit aussi deux générateurs de projet : `new-react-app` (React) et `new-mock-api` (serveur d'API factice Hono).

## Prérequis

`install.sh` s'arrête si l'un de ces outils manque :

- `git`
- `node` et `npx` : via [nvm](https://github.com/nvm-sh/nvm) ou `brew install node`
- `claude` (Claude Code) : `npm install -g @anthropic-ai/claude-code` ou l'installateur officiel
- `jq` : `brew install jq`

`uv` est installé automatiquement si nécessaire. macOS ou Linux, avec bash et un accès réseau.

## Démarrage rapide

```bash
git clone https://github.com/Mretailleau/toolsbox.git ~/toolsbox && ~/toolsbox/install.sh
```

Ajouter ensuite `~/.local/bin` au PATH (dans `~/.zshrc` ou `~/.bashrc`) :

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Ce que fait install.sh

- Sauvegarde chaque fichier existant avant de le modifier (`*.bak.<horodatage>`).
- Installe les sources listées dans `sources.txt`.
- Fusionne les réglages dans `settings.json`.
- Installe les hooks iTerm uniquement si `~/.config/iterm2/cc-status` existe : si vous installez l'intégration iTerm plus tard, relancez `install.sh`.
- Crée les liens (commandes, `new-react-app` et `new-mock-api` dans `~/.local/bin`).

Relancer `install.sh` met à jour toutes les sources.

## new-react-app

Crée un projet Vite (react-ts) avec React Router, Tailwind v4 et Vitest, puis un premier commit git :

```bash
new-react-app <nom>
```

Depuis Claude Code : `/new-react-app <nom>`.

## new-mock-api

Crée un serveur d'API factice Hono + TypeScript, prêt à lancer (port 3000, ou `PORT`), avec CORS activé :

```bash
new-mock-api <nom>
```

Depuis Claude Code : `/new-mock-api <nom>`.

Routes d'exemple (`/users`) :

| Route | Réponse |
|-------|---------|
| `GET /users` | liste des utilisateurs |
| `GET /users/:id` | l'utilisateur, ou 404 |
| `POST /users` | 201 ; 400 si `name` manque ou si le JSON est invalide |
| `DELETE /users/:id` | 204, ou 404 |

- `?delay=<ms>` : sur n'importe quelle URL, retarde la réponse (entier ≥ 0, plafonné à 10 000 ms).
- `fail(c, status, message)` : helper qui renvoie `{ "error": message }` avec le statut donné.
- `delay(ms)` : pause asynchrone pour simuler un traitement lent.

## sources.txt

Une source par ligne, `<type> <arguments>` :

| Type | Format | Effet |
|------|--------|-------|
| `ecc` | `ecc <profil>` | installe ECC avec le profil donné |
| `plugin` | `plugin <id@marketplace>` | installe un plugin Claude Code |
| `skills` | `skills <repo> <skill>` | installe un skill depuis un dépôt |
| `graphify` | `graphify <paquet>` | installe le paquet via `uv tool` |

Pour ajouter une source, ajouter une ligne, par exemple `plugin superpowers@claude-plugins-official`, puis relancer `install.sh`.

## Tests

```bash
npm install && npm test
RUN_SLOW=1 npx bats tests/new-react-app.bats   # test lent, réseau requis (~70 s)
```
