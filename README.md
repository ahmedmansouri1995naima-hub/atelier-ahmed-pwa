# Atelier Ahmed — application de gestion d’atelier

Application web progressive (PWA) en français pour gérer les clients, rendez-vous et projets de tapisserie.

## Configuration
L’application utilise le projet Supabase dédié à Atelier Ahmed et sa clé publique (publishable key). Une clé publique peut être utilisée dans le navigateur avec les règles RLS correctement activées. Ne placez jamais de clé secrète ou service_role dans le code client.

## Base de données
Dans un projet Supabase neuf et vide, exécutez une seule fois `supabase/SETUP-CLEAN.sql` dans SQL Editor. Créez ensuite l’utilisateur propriétaire dans Authentication > Users, puis appliquez la requête de promotion admin commentée à la fin du script.

Ne lancez pas le script sur une base contenant déjà des données. N’exécutez pas les anciennes migrations en plus du script d’installation propre.

## Publication GitHub Pages
Dans Settings → Pages → Build and deployment, sélectionnez Deploy from a branch, branche `main`, dossier `/(root)`, puis Save.
