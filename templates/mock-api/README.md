# Mock API

Serveur de mock Node + TypeScript avec [Hono](https://hono.dev).

## Commandes

- `npm run dev` : serveur avec rechargement (http://localhost:3000, `PORT` pour changer)
- `npm test` : tests Vitest
- `npm run build` puis `npm start` : build et exécution

## Ajouter une route

1. Crée `src/routes/produits.ts` :

   ```ts
   import { Hono } from 'hono'

   export const produits = new Hono()
   produits.get('/', (c) => c.json([{ id: 1, nom: 'Stylo' }]))
   ```

2. Branche-la dans `src/app.ts`, en ajoutant l'import en haut du fichier puis la route :

   ```ts
   import { produits } from './routes/produits.js'

   app.route('/produits', produits)
   ```

Les imports relatifs prennent l'extension `.js` (ESM NodeNext).

## Routes d'exemple

- `GET /` : `{ "status": "ok" }`
- `GET /users` : liste des utilisateurs
- `GET /users/:id` : un utilisateur (404 si introuvable)
- `POST /users` : crée un utilisateur, corps `{ "name": "..." }` (201, ou 400 si invalide)
- `DELETE /users/:id` : supprime un utilisateur (204, ou 404 si introuvable)

## Helpers (`src/helpers.ts`)

- `fail(c, status, message)` : réponse d'erreur `{ error: message }`, par ex. `return fail(c, 404, 'Introuvable')`.
- `delay(ms)` : pause asynchrone, par ex. `await delay(300)` pour simuler un traitement lent.
- `?delay=<ms>` : sur n'importe quelle URL, retarde la réponse (ex. `/users?delay=500`). Valeur ignorée si ce n'est pas un entier ≥ 0, plafonnée à 10 000 ms.
