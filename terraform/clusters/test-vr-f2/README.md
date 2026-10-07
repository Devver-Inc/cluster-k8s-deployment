# Template de cluster

Dossier prêt à copier-coller pour créer un nouveau cluster RKE2. Ne pas
appliquer ce dossier tel quel — c'est un modèle, pas un cluster réel.

## Étapes

1. Copier ce dossier :
   ```bash
   cp -r clusters/_template clusters/<org>
   cd clusters/<org>
   rm README.md   # ce fichier, une fois copié
   ```

2. Remplacer `REPLACE_ME_ORG` par le vrai nom de l'org dans :
   - `values.auto.tfvars` (`org`, `tags`)
   - `backend.hcl` (`key`)
   - `variables.tf` (commentaire de description, cosmétique)

3. Ajouter l'org à `org_subnet_index` dans `../../ip-plan.auto.tfvars` (prochain
   index libre — voir le [README racine](../../README.md#allocation-ip)). Le
   symlink `ip-plan.auto.tfvars` de ce dossier est préservé par `cp -r`, rien à
   refaire ici.

4. Ajuster `node_count`, `tags`, ressources dans `values.auto.tfvars` selon le
   besoin réel de ce cluster.

5. Suivre les étapes 1/2/3 du [README racine](../../README.md#mise-en-place)
   (structure Vault → action manuelle → déploiement infra) pour cette org.
