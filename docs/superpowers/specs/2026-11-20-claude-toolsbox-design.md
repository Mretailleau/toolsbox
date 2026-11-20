# Claude toolsbox — design

Date : 2026-11-20

## Intention

L'utilisateur change souvent d'ordinateur. Il veut un dépôt GitHub **public** (`toolsbox`) qui, cloné sur une nouvelle machine, recrée sa configuration Claude Code actuelle avec **une seule commande**, sans rien refaire à la main. Le dépôt fournit aussi une commande pour démarrer un projet React prêt à l'emploi.

Le succès se mesure ainsi : sur un Mac vierge (avec git, node et Claude Code installés), `git clone … && ./install.sh` donne une session Claude qui a les mêmes skills, plugins, agents, rules, commandes et réglages qu'aujourd'hui, plus `new-react-app` disponible dans le terminal et sous la forme `/new-react-app` dans Claude.

## Objectifs

1. `install.sh` restaure la config perso et installe toutes les sources tierces depuis leur dépôt d'origine, en version récente.
2. Les sources tierces sont déclarées dans un seul fichier lisible. Ajouter un skill doit tenir en une ligne.
3. `new-react-app <nom>` génère un projet React + TypeScript + Vitest + React Router + Tailwind qui compile, dont les tests passent, et qui est prêt à être commité.

## Non-objectifs

- Pas de synchronisation : le dépôt sert uniquement d'installeur. Les changements faits sur une machine ne remontent pas automatiquement.
- Pas de gestion des secrets, des MCP ni des tokens (il n'y en a aucun aujourd'hui).
- Pas de support Windows.

## Anti-objectifs (échec même si « ça marche »)

- Écraser sans sauvegarde un `~/.claude/settings.json` ou un fichier existant.
- Un script qui s'arrête au premier échec d'une source et laisse une installation à moitié faite sans le dire.
- Publier dans le dépôt public quoi que ce soit de personnel : email, chemins absolus personnels, historique, contenu de `projects/`, `sessions/`, `history.jsonl`.
- Copier dans le dépôt le contenu des sources tierces (ECC, etc.). Le dépôt ne contient que des références vers ces sources.

## Contraintes

- macOS en priorité. Le bash doit rester portable (pas de flags GNU-only) pour fonctionner aussi sous Linux.
- Prérequis supposés : git, node ou npm (via nvm), Claude Code CLI (`claude`). `gh` n'est pas requis puisque le dépôt est public. `uv` est requis pour Graphify : le script l'installe s'il manque, via l'installeur officiel d'astral.
- Le script doit être idempotent : on peut le relancer sans dégât.

## État actuel constaté (machine source)

| Élément | Origine | Comment le recréer |
|---|---|---|
| 71 agents, 97 commandes, rules `~/.claude/rules/ecc/`, ~50 skills, `AGENTS.md` | ECC v2.2.3, profil `minimal` (copie de fichiers dans `~/.claude`, pas en plugin) | Installeur ECC via `npx ecc-universal@latest …` avec le profil `minimal` |
| Superpowers | plugin `superpowers@claude-plugins-official` | `claude plugin install superpowers@claude-plugins-official` |
| `settings.json` | perso | Copie depuis `config/settings.json` |
| Hooks iTerm2 (`~/.config/iterm2/cc-status`, 6 événements) | binaire installé par l'intégration Claude d'iTerm2 | N'ajouter les hooks que si le binaire existe |
| `CLAUDE.md` | vide | Fourni vide (placeholder) dans `config/` |
| MCP | aucun | — |

Réglages perso actuels : `model: opus`, `theme: dark`, `includeCoAuthoredBy: false`, `enabledPlugins: superpowers`.

## Sources tierces à installer

| Nom | Dépôt | Méthode d'installation documentée en amont |
|---|---|---|
| ECC | `affaan-m/ECC` | `npx ecc-universal@latest` (installeur, profil `minimal`) |
| Superpowers | marketplace `anthropics/claude-plugins-official` | `claude plugin install` |
| Vercel React Best Practices | `vercel-labs/agent-skills` | `npx skills add vercel-labs/agent-skills` |
| Skills for Real Engineers | `mattpocock/skills` | `claude plugin install mattpocock-skills@claude-plugins-official` |
| react-expert | `Jeffallan/claude-skills`, fichier `skills/react-expert/SKILL.md` uniquement | Copie de ce seul dossier de skill dans `~/.claude/skills/react-expert/` (pas tout le plugin de 67 skills) |
| Graphify | `Graphify-Labs/graphify` | `uv tool install graphifyy` puis `graphify install` (plateforme Claude Code) |

## Approches envisagées

- **A. Copie complète de `~/.claude` dans le dépôt.** On restaure à l'identique, mais le dépôt est lourd, les versions restent figées, et on risque de publier du contenu personnel. Rejetée.
- **B. Fichiers perso + liste de sources récupérées depuis l'amont.** Retenue par l'utilisateur. Le dépôt reste léger, les versions sont toujours récentes, et ajouter une source tient en une ligne. Le prix à payer : une source qui change sa méthode d'installation casse son étape. C'est atténué par un rapport d'échec qui n'interrompt pas le reste.
- **C. B avec des versions figées.** Reproductible, mais demande une maintenance manuelle. Rejetée pour un usage perso.

## Design

### Arborescence

```
toolsbox/
├── README.md               # quickstart : clone + ./install.sh ; comment ajouter une source
├── install.sh              # point d'entrée unique
├── sources.txt             # 1 ligne = 1 source : <type> <nom> <argument(s)>
├── lib/                    # fonctions bash découpées par type de source
├── config/
│   ├── settings.json       # réglages perso, sans les hooks iTerm
│   ├── hooks-iterm.json    # bloc hooks iTerm, fusionné seulement si cc-status existe
│   └── CLAUDE.md
├── bin/new-react-app       # générateur de projet React
├── commands/new-react-app.md   # commande Claude /new-react-app qui appelle bin/new-react-app
├── templates/react-app/    # fichiers ajoutés ou remplacés par-dessus le scaffold Vite
└── tests/                  # tests du script (bats ou équivalent) et smoke test du générateur
```

### `install.sh`

1. Vérifie les prérequis (git, node/npx, claude). Installe `uv` s'il manque.
2. Sauvegarde `~/.claude/settings.json` et `~/.claude/CLAUDE.md` s'ils existent (`*.bak.<horodatage>`).
3. Installe chaque ligne de `sources.txt` selon son type (`plugin`, `npx-skills`, `ecc`, `skill-file`, `graphify`). Chaque étape est isolée : un échec est noté et le script continue.
4. Applique `config/settings.json` en le **fusionnant** avec l'existant (les installeurs tiers peuvent avoir écrit des clés, par exemple `enabledPlugins`) plutôt qu'en l'écrasant. Ajoute les hooks iTerm uniquement si `~/.config/iterm2/cc-status` existe.
5. Installe `commands/new-react-app.md` dans `~/.claude/commands/` et crée un lien de `bin/new-react-app` vers `~/.local/bin/` (en prévenant si ce dossier n'est pas dans le PATH).
6. Affiche un récapitulatif ✓ / ✗ par étape et renvoie un code ≠ 0 si au moins une étape a échoué.

Le dépôt est cloné dans un emplacement stable, par exemple `~/toolsbox` ou là où l'utilisateur le clone. Les liens pointent vers ce clone, si bien qu'un `git pull` met à jour le script React et la commande Claude.

### `new-react-app <nom>`

- Scaffold avec Vite (template `react-ts`), npm.
- React Router v7 en mode bibliothèque (`createBrowserRouter`) avec deux routes d'exemple et un layout.
- Tailwind CSS v4 via `@tailwindcss/vite`.
- Vitest + @testing-library/react + @testing-library/jest-dom + jsdom, avec un test d'exemple qui passe et les scripts `test` et `test:coverage`.
- Lance `git init` et fait un premier commit.
- Refuse de s'exécuter si le dossier cible existe déjà.
- La commande Claude `/new-react-app <nom>` appelle le script puis résume ce qui a été créé.

## Décisions prises suite à la relecture (choix de Claude, corrigeables)

- **Référence pour ECC** : on reproduit l'installation actuelle, c'est-à-dire le profil `minimal` d'ECC, avec les modules `rules-core`, `agents-core`, `commands-core`, `platform-configs`, `skill-unified-memory`, `workflow-quality` et `shared-script-utils`, en dernière version. Si le nombre d'agents, de commandes ou de skills change d'une version d'ECC à l'autre, l'écart est accepté. Pas d'inventaire comparé. ECC s'installe **avant** la fusion des settings, et la fusion respecte ce qu'ECC a pu écrire.
- **Périmètre** : `anthropic-skills:*`, easel, claude-in-chrome et `plugin-authoring` sont fournis par l'app ou le compte Claude, pas par `~/.claude`. Ils sont donc hors périmètre. Vercel, Matt Pocock, react-expert et Graphify **ne sont pas encore installés** sur la machine source : ce sont des ajouts. « Comme aujourd'hui » veut donc dire la config actuelle plus ces quatre sources.
- **Fusion de `settings.json`** : pour les valeurs simples (`model`, `theme`, `includeCoAuthoredBy`), le dépôt l'emporte. `enabledPlugins` combine les deux côtés. Les hooks iTerm sont remplacés à l'identique par ceux du dépôt, avec dédoublonnage par commande, pour qu'une relance ne crée pas de doublons. Les autres clés existantes sont conservées.
- **Relance** : une relance met à jour chaque source vers sa dernière version, avec la commande d'update de chaque installeur (ou une réinstallation), plutôt que de sauter ce qui est déjà présent.
- **Vercel** : seulement le skill `react-best-practices`, en installation globale pour Claude Code (pas dans le dossier courant).
- **Graphify** : `graphify install` en installation globale pour Claude Code. Rien n'est écrit dans un projet.
- **react-expert** : téléchargé depuis l'amont au moment de l'install (rien n'est copié dans le dépôt).

## Sources écartées

- **claude-code-best-practice** (`shanraisshan/claude-code-best-practice`) : retiré à la demande de l'utilisateur, car c'est surtout de la doc et des démos, pas un pack de skills.

## Laissé au builder

- Le format exact de `sources.txt` et le découpage de `lib/`.
- Les flags exacts de l'installeur ECC pour reproduire le profil `minimal` en mode non interactif.
- La méthode de fusion JSON (`jq` si présent, sinon `node -e`).
- Le contenu des pages d'exemple du template React.
- Le framework de test du script (bats-core recommandé).
