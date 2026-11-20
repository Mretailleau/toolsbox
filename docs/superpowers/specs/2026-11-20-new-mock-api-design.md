# new-mock-api — design (court)

Date : 2026-11-20

## Intention
Une commande `new-mock-api <nom>` qui génère en quelques secondes un serveur de mock Node + TypeScript, simple et léger. Les routes GET, POST et DELETE s'écrivent à la main, avec un contrôle précis des réponses : statut, corps, cas d'erreur, délais. Elle s'ajoute à côté de `new-react-app` dans toolsbox.

## Objectifs
- Le projet généré démarre (`npm run dev`), ses tests passent (`npm test`) et il compile (`npm run build`) dès sa création.
- Ajouter une route revient à écrire une ligne dans un fichier `src/routes/*.ts`.
- Les outils pour simuler une latence ou une erreur sont fournis.

## Non-objectifs
- Pas de base de données ni de persistance : les données vivent en mémoire et sont remises à zéro au redémarrage.
- Pas de génération automatique de routes à partir d'un fichier JSON.
- Pas d'authentification.

## Anti-objectifs
- Un projet lourd : plus de 2 dépendances d'exécution, ou une configuration à écrire avant de pouvoir s'en servir.

## Approches
- **A. Hono + @hono/node-server (retenue par l'utilisateur).** Natif TypeScript, minuscule, et testable sans serveur grâce à `app.request()`.
- B. Express : plus connu, mais typage ajouté après coup, plus de code autour, et supertest nécessaire pour les tests.
- C. Fastify : plus lourd à configurer que ce qu'un mock « léger » demande.

## Design
- Script `bin/new-mock-api <nom>` avec les mêmes règles que `new-react-app` : nom validé par `^[a-z0-9][a-z0-9._-]*$`, refus si le dossier existe, résolution du vrai chemin même via un lien, git init plus premier commit avec l'identité de repli, messages en français.
- Le script copie `templates/mock-api/`, remplace le nom dans `package.json`, puis installe en dernière version :
  - `hono` et `@hono/node-server` ;
  - en dev : `typescript`, `tsx`, `vitest`, `@types/node`.
- Projet généré :
  - `src/index.ts` : écoute sur `PORT` (3000 par défaut) et affiche l'URL ;
  - `src/app.ts` : crée l'app Hono, avec le middleware `logger()` et `cors()` (choix de Claude : un front React sur un autre port doit pouvoir l'appeler), et monte les routes ;
  - `src/helpers.ts` : `delay(ms)` ; une fonction qui renvoie une erreur avec un statut et un message, au format `{ "error": message }` ; un middleware qui ajoute un délai si la requête contient `?delay=<ms>` (choix de Claude : simuler la latence sans toucher au code) ;
  - `src/routes/users.ts` : un exemple avec un tableau en mémoire. `GET /users`, `GET /users/:id` (404 si absent), `POST /users` (400 si `name` manque, sinon 201 avec l'objet créé), `DELETE /users/:id` (204, ou 404) ;
  - `src/routes/users.test.ts` : des tests Vitest qui couvrent chaque cas via `app.request()` ;
  - les scripts `dev` (`tsx watch src/index.ts`), `start` (`node dist/index.js`), `build` (`tsc`), `test` (`vitest run`), un `tsconfig.json` en ESM/NodeNext strict, un `.gitignore` et un README court.
- Commande Claude `/new-mock-api <nom>`, construite comme `/new-react-app`, avec le même repli sur `~/.local/bin`.
- `install.sh` crée le lien `bin/new-mock-api` vers `~/.local/bin` et `commands/new-mock-api.md` vers `~/.claude/commands`.
- Tests bats : refus d'un nom invalide, refus d'un dossier existant (rapides). Un test lent (`RUN_SLOW=1`) génère un projet et vérifie que `npm test` et `npm run build` passent et qu'il y a 1 commit. Le test d'install vérifie la présence des nouveaux liens.
- Le README de toolsbox est mis à jour.

## Laissé au builder
- Le contenu exact des messages et du README généré.
- Si les règles de validation sont partagées avec `new-react-app` (un `lib/scaffold.sh` commun est bienvenu s'il évite de dupliquer le code).
