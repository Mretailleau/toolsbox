---
description: Crée un projet React + TS + Vitest + React Router + Tailwind
argument-hint: <nom-du-projet>
---

Lance `new-react-app $ARGUMENTS` dans le dossier courant (Bash). Si la commande est introuvable (`~/.local/bin` absent du PATH), relance avec `~/.local/bin/new-react-app $ARGUMENTS`.

Une fois terminé, résume en quelques lignes la structure créée (Vite, React Router avec Layout/Home/About, Tailwind, Vitest + Testing Library) et rappelle les commandes :

- `npm run dev` : serveur de développement
- `npm test` : tests (`npm run test:coverage` pour la couverture)
- `npm run build` : build de production

Si le script échoue (nom invalide, dossier existant), affiche son message sans le contourner.
