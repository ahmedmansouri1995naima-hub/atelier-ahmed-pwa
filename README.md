# Atelier Ahmed — application de gestion d’atelier

Application web progressive (PWA) en français pour gérer les clients, rendez-vous et projets de tapisserie.

## Déploiement
Dans GitHub : Settings → Pages → Build and deployment → Deploy from a branch → main → /(root) → Save.

## Configuration Supabase
L’application est déjà configurée avec l’URL du projet et sa clé publique (publishable key). N’utilisez jamais de clé secrète ou service_role dans le navigateur.

Pour initialiser une base Supabase **neuve et vide**, exécutez une seule fois le script `supabase/SETUP-CLEAN.sql` dans le SQL Editor du projet. Créez ensuite l’utilisateur administrateur et appliquez la requête de promotion décrite à la fin du script.

Ne lancez pas ce script sur une base qui contient déjà des données.
