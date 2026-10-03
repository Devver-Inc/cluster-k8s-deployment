# Déployer un cluster — guide de A à Z

Procédure complète pour déployer un premier cluster (`prod`) depuis un Vault
vide. Pour une org suivante, sauter aux étapes marquées **(nouvelle org)**.

Ce guide décrit la procédure **manuelle** (debug/test local). En usage normal,
une fois la pipeline CI en place (voir [section dédiée](#via-la-pipeline-ci)
en fin de fichier), tout se pilote par **push** sur `terraform/clusters/**` —
le workflow `2 - Proxmox: apply/destroy cluster` détecte automatiquement
l'action à mener selon ce qui a changé :
- **créer** un cluster : créer un dossier `terraform/clusters/<org>/` et
  merger la PR.
- **supprimer** un cluster : supprimer le dossier soi-même (`git rm -r
  terraform/clusters/<org>/`) et merger — le destroy complet se déclenche
  automatiquement sur ce push (voir la section dédiée pour le détail).
- **ajouter/retirer un worker** : modifier `additional_workers_count` dans
  `values.auto.tfvars` et merger — un retrait déclenche automatiquement un
  retrait propre du node (drain + désinscription Kubernetes) avant la
  destruction de sa VM (voir [`ansible/README.md`](../ansible/README.md#retrait-dun-worker)).

## Prérequis

```bash
export VAULT_ADDR='https://vault.devver.app'
export VAULT_TOKEN=$(cat ~/.vault-token)   # ou: vault login
vault token lookup                          # doit réussir
```

## Étape 0 — Amorçage (une seule fois, jamais répété)

Écrire les credentials B2 à la main (aucune autre source possible au tout
premier `apply` — le backend doit exister avant que Terraform sache lire Vault) :

```bash
cd terraform/vault
export AWS_ACCESS_KEY_ID='...'      # keyID Backblaze B2
export AWS_SECRET_ACCESS_KEY='...'  # applicationKey Backblaze B2

terraform init -backend-config=backend.hcl
```

Écrire dans Vault, une fois pour toutes :

```bash
vault kv put devver-infra-deployment/s3-backend \
  key_id="$AWS_ACCESS_KEY_ID" \
  application_key="$AWS_SECRET_ACCESS_KEY"

vault kv put devver-infra-deployment/vm_secret_template \
  vm_user="devver" \
  ssh_public_key="ssh-ed25519 AAAA..." \
  vm_password="CHANGE_ME" \
  ssh_private_key="CHANGE_ME"
```

## Étape 1 — Créer la structure Vault (à chaque nouvelle org)

```bash
cd terraform/vault
source ../login.sh          # relit VAULT_ADDR + AWS_* depuis Vault désormais
terraform init -backend-config=backend.hcl

# Toujours partir de l'état RÉEL de Vault (pas d'une liste tapée à la main) et
# n'y AJOUTER que la nouvelle org — jamais un remplacement complet. Une liste
# tapée en dur (ex: -var='orgs=["prod"]') RETIRE du for_each toute org absente
# de cette liste, donc la SUPPRIME au prochain apply si elle existe déjà dans
# Vault. C'est arrivé en pratique (structure de prod proposée à la destruction
# par erreur) — toujours passer par cette commande, jamais une liste en dur :
current=$(bash ../scripts/list-vault-orgs.sh)
new_orgs=$(printf '%s\n%s\n' "${current}" "test" | grep -v '^$' | sort -u | jq -R . | jq -s -c .)
terraform apply -var="orgs=${new_orgs}"
```

Crée : le mount KV `devver-infra-deployment`, la policy + role AppRole pour la
nouvelle org, et clone `vm_secret_template` → `devver-infra-deployment/<org>`
(une seule fois, jamais réécrit ensuite) — sans jamais toucher aux orgs déjà
existantes.

Écrire les credentials Proxmox si pas déjà fait (secret partagé, une fois) :

```bash
vault kv put devver-infra-deployment/proxmox \
  token_id='root@pam!devver' \
  token_secret='...'
```

Récupérer le `role_id` (stable) et générer un `secret_id` (à refaire à chaque
usage si expiré, TTL 1h par défaut) :

```bash
vault read -field=role_id auth/terraform-orgs/role/terraform-prod/role-id
vault write -f auth/terraform-orgs/role/terraform-prod/secret-id
```

## Étape 2 — Compléter les secrets de l'org (action manuelle)

Remplacer les placeholders du clone (`devver-infra-deployment/prod`) par de
vraies valeurs — ne sera **plus jamais écrasé** par Terraform ensuite :

```bash
vault kv patch devver-infra-deployment/prod \
  vm_password='...' \
  ssh_private_key='...'
```

## Étape 3 — Déployer le cluster

**(nouvelle org)** copier le template avant cette étape :
```bash
cd terraform/clusters
cp -r _template <org> && cd <org>
rm README.md
# remplacer REPLACE_ME_ORG dans values.auto.tfvars et backend.hcl
```
Ajouter l'org à `org_subnet_index` dans `../../ip-plan.auto.tfvars` (index
libre, jamais réutilisé).

Puis, pour `prod` comme pour toute org :

```bash
cd terraform/clusters/prod
source ../../login.sh

export TF_VAR_vault_role_id='<role_id étape 1>'
export TF_VAR_vault_secret_id='<secret_id étape 1>'

terraform init -backend-config=backend.hcl
terraform plan     # vérifier : nombre de noeuds, IP, template, tags
terraform apply
```

## Vérification

```bash
terraform output metallb_ip
cat ansible-inventory/inventory-prod.ini   # groupes [server]/[agent] peuplés
```

## Nettoyage (si besoin)

```bash
terraform destroy
```

## Via la pipeline CI

Deux workflows, tous deux pilotés par **push** — l'admin modifie le code
(crée/supprime un dossier `terraform/clusters/<org>/`, change
`additional_workers_count`) et pousse, le pipeline déduit l'action à mener :

1. [`vault-create-org.yml`](../.github/workflows/vault-create-org.yml)
   (« **1 - Vault: création structure org** » dans l'onglet Actions) — sur
   push touchant `terraform/clusters/**` : le job `detect` compare l'état du
   repo à l'état **réel** de Vault, et le job `vault-create` crée
   automatiquement la structure Vault de toute org présente dans le repo
   mais pas encore dans Vault — en **ajoutant** uniquement ces orgs à l'état
   réel de Vault, jamais en recalculant la liste complète depuis un scan du
   repo (ça a réellement failli supprimer la structure Vault de `prod` avec
   l'ancien mécanisme — éliminé structurellement ici, aucune org déjà connue
   de Vault ne peut disparaître via ce chemin). `workflow_dispatch` (input
   `org`) reste disponible pour une création ponctuelle manuelle (ex: rejouer
   après un échec), mais n'est plus le chemin principal.
2. [`proxmox-deploy-cluster.yml`](../.github/workflows/proxmox-deploy-cluster.yml)
   (« **2 - Proxmox: apply/destroy cluster** » dans l'onglet Actions) —
   déclenché **automatiquement par push** sur `terraform/clusters/**`. Un job
   `detect` compare l'état du repo avant/après le push (dossiers
   apparus/disparus, `additional_workers_count` changé dans
   `values.auto.tfvars`) pour en déduire l'une de 4 actions, chacune son
   propre job : `create-cluster`, `delete-cluster`, `add-worker`,
   `remove-worker` (voir détail plus bas).

La structure Vault créée automatiquement contient encore les placeholders du
template (`vm_password=CHANGE_ME`, etc.) — `create-cluster` peut se
déclencher dans la foulée sur le même push dès que la structure existe, mais
échouera proprement (credentials VM invalides) tant que les vrais secrets
n'ont pas été saisis dans Vault (Étape 2 ci-dessus). Pas de risque, juste un
job en erreur à corriger avant de repousser un commit trivial pour relancer.

Si l'org passe un jour sur un plan GitHub payant (Team/Enterprise), il devient
possible de revenir à un unique workflow avec de vrais Environments — pas
nécessaire pour l'instant, ce découpage en deux fonctionne aussi bien.

### Prérequis logiciels sur le runner self-hosted

À installer une fois sur la machine qui héberge le runner (pas géré par les
workflows eux-mêmes) :
- **`terraform`** — exécute les `plan`/`apply`/`destroy`.
- **`jq`** — utilisé par `terraform/scripts/list-orgs.sh` et
  `terraform/scripts/list-vault-orgs.sh` pour parser/générer du JSON.
- **`vault`** (CLI) — utilisé par `terraform/scripts/list-vault-orgs.sh` pour
  lire l'état réel de Vault (`vault list sys/policies/acl`) et déterminer
  quelles orgs ont déjà une structure Vault. `detect-org-change.sh` compare
  cet état à celui du repo plutôt que de déduire un diff git — ce dernier
  mécanisme s'est révélé peu fiable en pratique (une création pouvait être
  "perdue" si plusieurs commits/push s'enchaînaient avant qu'un run réussisse).
  Le CLI utilise `VAULT_ADDR`/`VAULT_TOKEN` déjà exportés par
  `hashicorp/vault-action` (`exportToken: true`), pas de config supplémentaire
  à faire sur le runner au-delà de l'installation.
- **`git`** — utilisé par le step `Remove cluster folder and push` (suppression
  d'un cluster, voir plus bas) pour committer et pousser sur `main`.
- **`docker`** — utilisé par le workflow `3 - Ansible: configurer les
  clusters` et par le job `remove-worker` de `2 - Proxmox` (voir
  `ansible/README.md`) pour builder/exécuter l'image
  `runner-images/ansible/Dockerfile` dans laquelle tourne tout le job (Ansible
  + `kubectl` installés uniquement dans l'image, pas sur le runner).
  L'utilisateur qui fait tourner le service `actions-runner` doit pouvoir
  lancer `docker build`/`docker run` (membre du groupe `docker`, ou
  équivalent).

> **Isolation** : les jobs `runs-on: self-hosted` s'exécutent **directement sur
> la machine du runner**, pas dans un conteneur éphémère — contrairement aux
> runners hébergés par GitHub. Il n'y a donc pas d'isolation filesystem/process
> stricte entre jobs ou entre runs, et pas de nettoyage garanti au-delà du
> dossier de travail du repo (les credentials injectés en variables d'env ne
> survivent pas au job qui les exporte, mais rien d'autre n'est assaini
> automatiquement). Accepté comme tel pour Terraform/Vault (repo privé, équipe
> restreinte de confiance). Le workflow `3 - Ansible` et le job `remove-worker`
> de `2 - Proxmox` font exception : tout le job (y compris le login Vault)
> tourne dans le conteneur `runner-images/ansible/` (`container:` dans le
> YAML) — voir `ansible/README.md#isolation`.

### Prérequis one-shot (à faire manuellement avant le premier run)

Un AppRole `terraform-ci` dédié à la pipeline, distinct des roles
`terraform-<org>` de l'usage manuel ci-dessus — un seul role pour toutes les
orgs, car GitHub Actions ne permet pas de référencer un secret par un nom
construit dynamiquement (voir justification dans `terraform/README.md`).
Portée quasi-admin (gère `vault/` en écriture, lit toutes les orgs) : à
traiter avec la même prudence qu'un token root, protégé par le fait qu'il ne
tourne que sur le runner self-hosted et par le déclenchement manuel explicite
requis avant toute action sensible.

Sa policy et son role sont définis comme n'importe quelle autre resource de
`vault/main.tf` (`vault_policy.ci`, `vault_approle_auth_backend_role.ci`) —
`vault/` contient toute la configuration Vault du projet, `clusters/` ne fait
qu'utiliser cette configuration pour déployer. Rien à écrire à la main pour la
policy/le role eux-mêmes : ils sont créés au prochain `apply` de l'Étape 1
ci-dessus. Seuls le `role_id`/`secret_id` restent générés manuellement, comme
pour tous les autres roles (jamais dans le state) :

```bash
vault read -field=role_id auth/terraform-orgs/role/terraform-ci/role-id
vault write -f auth/terraform-orgs/role/terraform-ci/secret-id
```

> **Dette technique assumée** : ce `secret_id` n'a pas de `secret_id_ttl` (illimité
> par défaut) — il ne périme jamais et n'a donc pas besoin d'être régénéré. Bonne
> pratique standard pour une CI serait un TTL de 30-90 jours avec rotation
> périodique documentée, mais ce compromis est accepté pour l'instant (projet en
> cours de mise en place). À revisiter avant une mise en prod à plus grande échelle.

### Secrets et variables GitHub à créer (Settings du repo)

- Variable de repo (Settings > Secrets and variables > Actions > Variables) :
  `VAULT_ADDR` = `https://vault.devver.app`
- Secrets (Settings > Secrets and variables > Actions > Secrets) :
  `VAULT_CI_ROLE_ID`, `VAULT_CI_SECRET_ID` (valeurs ci-dessus) — aucun autre
  secret nécessaire, aucun secret par org.

### Ce que fait chaque workflow selon le cas

**Ajout d'un dossier `clusters/<org>/`** :
Le push déclenche `vault-create-org.yml` : `detect` repère que `<org>` n'a
pas encore de structure Vault → job `vault-create` la crée automatiquement
(uniquement pour cette org, sans toucher aux autres). Le même push déclenche
aussi `proxmox-deploy-cluster.yml`, mais `create-cluster` échoue à ce stade
(secrets encore à leurs placeholders `CHANGE_ME`) : saisir les vrais secrets
dans Vault (Étape 2 ci-dessus), puis pousser un **second commit** (même
trivial) touchant `terraform/clusters/<org>/` pour redéclencher
`create-cluster` avec les bons secrets cette fois.

**Supprimer un cluster** — supprimer `terraform/clusters/<org>/` soi-même
(`git rm -r terraform/clusters/<org>/`) et pousser sur `main` :

Le job `detect` repère la disparition du dossier → job `delete-cluster`
(checkout du commit **précédent**, où le code existe encore, pour pouvoir
faire le `terraform destroy`), puis `vault-cleanup` nettoie la structure
Vault de l'org. Rien d'autre à committer après coup — le dossier a déjà
disparu dans le commit qui a déclenché tout ça.

**Ajouter/retirer un worker** — modifier `additional_workers_count` dans
`values.auto.tfvars` et pousser sur `main` :

- Valeur **augmentée** → job `add-worker` : `terraform apply` ajoute
  directement la nouvelle VM (`for_each` sur une clé `worker-N`, aucune
  autre ressource touchée).
- Valeur **diminuée** → job `remove-worker` : voir
  [`ansible/README.md#retrait-dun-worker`](../ansible/README.md#retrait-dun-worker)
  pour la séquence complète (drain Kubernetes, désinstallation RKE2 via SSH,
  retrait du node, **puis seulement** destruction de la VM). Échoue
  explicitement sans rien détruire si le plan révèle un retrait de
  **master** (`node_count` modifié plutôt que `additional_workers_count`) —
  intervention manuelle requise dans ce cas.

> **Permission requise** : les commits automatiques (inventaire Ansible
> régénéré) utilisent le `GITHUB_TOKEN` par défaut du job pour pousser sur
> `main`. Vérifier que les Actions du repo ont la permission d'écriture
> (Settings > Actions > General > Workflow permissions > **Read and write
> permissions**), sinon ces steps échouent avec une erreur d'autorisation.
