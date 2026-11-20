---
description: Crée un serveur de mock Node + TypeScript (Hono) avec routes GET/POST/DELETE
argument-hint: <nom-du-projet>
---

Lance `new-mock-api $ARGUMENTS` dans le dossier courant (Bash). Si la commande est introuvable (`~/.local/bin` absent du PATH), relance avec `~/.local/bin/new-mock-api $ARGUMENTS`.

Une fois terminé, résume en quelques lignes la structure créée (Hono + Node, route `/users` avec GET/POST/DELETE en mémoire, helpers `fail`/`delay`/`?delay=`, tests Vitest) et rappelle les commandes :

- `npm run dev` : serveur de développement (http://localhost:3000/users)
- `npm test` : tests
- `npm run build` : build de production

Si le script échoue (nom invalide, dossier existant), affiche son message sans le contourner.
