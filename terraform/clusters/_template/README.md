# Template de cluster

Dossier prêt à copier-coller pour créer un nouveau cluster RKE2. Ne pas
appliquer ce dossier tel quel — c'est un modèle, pas un cluster réel.

Un cluster est identifié par **`<org>-<env>`** (ex: `acme-prod`), avec
`env` ∈ `prod | staging | dev`. Cet identifiant est le nom du dossier, la clé
du registre IP, le chemin `devver-infra-deployment/<org>-<env>` et le préfixe
des VM. Le couple `<org>/<env>` donne aussi le chemin des secrets applicatifs
dans Vault : `kubernetes-cluster/<org>/<env>/` (voir
[terraform/vault/k8s-secrets.tf](../../vault/k8s-secrets.tf) et
[ansible/playbooks/05-vault-k8s.yml](../../../ansible/playbooks/05-vault-k8s.yml)).

## Étapes

1. Copier ce dossier :
   ```bash
   cp -r clusters/_template clusters/<org>-<env>
   cd clusters/<org>-<env>
   rm README.md   # ce fichier, une fois copié
   ```

2. Remplacer `REPLACE_ME_ORG` / `REPLACE_ME_ENV` dans :
   - `values.auto.tfvars` (`org`, `env`, `tags`)
   - `backend.hcl` (`key`)

3. Ajouter `<org>-<env>` à `org_subnet_index` dans `../../ip-plan.auto.tfvars`
   (prochain index libre — voir le [README racine](../../README.md#allocation-ip)).
   Le symlink `ip-plan.auto.tfvars` de ce dossier est préservé par `cp -r`.

4. Ajuster `node_count`, `tags`, ressources dans `values.auto.tfvars` selon le
   besoin réel de ce cluster.

5. Suivre les étapes 1/2/3 du [README racine](../../README.md#mise-en-place)
   (structure Vault → action manuelle → déploiement infra) pour ce cluster.

6. Après le job `configure`, compléter dans la console Vault les secrets
   restés à `CHANGEME` sous `kubernetes-cluster/<org>/<env>/` — procédure :
   `Devver-Inc/kubernetes` → `docs/vault-nouveau-cluster.md`.
