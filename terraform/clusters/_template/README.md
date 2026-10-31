# Template de cluster

Dossier prêt à copier-coller pour créer un nouveau cluster RKE2. Ne pas
appliquer ce dossier tel quel — c'est un modèle, pas un cluster réel.

Un cluster est identifié par **`<org>-<env>`** (ex: `acme-prod`), avec
`env` ∈ `prod | staging | dev`. Cet identifiant est le nom du dossier, la clé
du registre IP, le chemin `devver-infra-deployment/<org>/<env>` et le préfixe
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
   besoin réel de ce cluster, et renseigner son stockage : `nfs_server` et
   `nfs_share` — un partage **dédié à ce cluster**, créé au préalable sur le
   NAS avec un accès NFS réservé aux IP de ses noeuds (jamais le partage de
   la prod) : lecture/écriture, squash « Aucun mappage », `AUTH_SYS`, mêmes
   permissions de dossier que la prod (règle de propriété du NAS : voir
   `docs/vault-nouveau-cluster.md` du repo kubernetes, section « Stockage NFS »). Optionnel : `base_domain` (défaut `devver.app` → le cluster est
   servi sous `<org>-<env>.devver.app`) et `kubernetes_git_revision`
   (révision du repo kubernetes suivie par ArgoCD, défaut `main`).

5. Suivre les étapes 1/2/3 du [README racine](../../README.md#mise-en-place)
   (structure Vault → action manuelle → déploiement infra) pour ce cluster.

6. Les secrets du cluster sont préparés par la pipeline dès le 1er
   lancement (job `prepare-secrets`) ; elle s'arrête en listant ce qui reste
   à saisir avant de créer les VMs — voir `terraform/DEPLOY.md`.
