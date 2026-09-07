# Déployer un cluster — guide de A à Z

Procédure complète pour déployer un premier cluster (`prod`) depuis un Vault
vide. Pour une org suivante, sauter aux étapes marquées **(nouvelle org)**.

Ce guide décrit la procédure **manuelle** (debug/test local). En usage normal,
une fois la pipeline CI en place (voir [section dédiée](#via-la-pipeline-ci)
en fin de fichier) : pour **créer** un cluster, il suffit de créer un dossier
`terraform/clusters/<org>/` et de merger la PR ; pour **supprimer** un cluster,
ne jamais supprimer le dossier soi-même — lancer directement le workflow
`2 - Proxmox: apply/destroy cluster` avec `action=delete`, c'est la pipeline
qui retire le dossier une fois le destroy confirmé (voir la section dédiée
pour le pourquoi).

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
terraform init  -backend-config=backend.hcl
terraform apply -var='orgs=["prod"]'   # (nouvelle org) ajouter son nom à la liste
```

Crée : le mount KV `devver-infra-deployment`, la policy + role AppRole par org,
et clone `vm_secret_template` → `devver-infra-deployment/prod` (une seule fois,
jamais réécrit ensuite).

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
cat generated/inventory-prod.ini   # groupes [server]/[agent] peuplés
```

## Nettoyage (si besoin)

```bash
terraform destroy
```

## Via la pipeline CI

Deux workflows, découpés en deux fichiers **parce que GitHub ne propose pas
de pause/validation manuelle native (Environments + required reviewers) sur
un repo privé en plan Free** — un second déclenchement manuel joue ce rôle à
la place, gratuitement sur tout plan :

1. [`vault-create-org.yml`](../.github/workflows/vault-create-org.yml)
   (« **1 - Vault: création structure org** » dans l'onglet Actions) —
   automatique, déclenché par un push touchant `terraform/clusters/` sur
   `main`. Détecte si un **nouveau** dossier d'org a été ajouté (uniquement
   les créations, voir plus bas pour les suppressions), crée la structure
   Vault correspondante, puis **s'arrête** et affiche la suite à donner dans
   le résumé du run (onglet Summary de la page du run GitHub Actions).
2. [`proxmox-deploy-cluster.yml`](../.github/workflows/proxmox-deploy-cluster.yml)
   (« **2 - Proxmox: apply/destroy cluster** » dans l'onglet Actions) —
   déclenché **toujours manuellement** (**Actions > 2 - Proxmox: apply/destroy
   cluster > Run workflow**), avec deux champs à renseigner (`org`, `action`).
   Pour une création, `org`/`action=create` sont copiés depuis le résumé du
   run précédent. Pour une suppression, se déclenche directement (voir plus
   bas — jamais précédé d'une suppression manuelle du dossier).

Si l'org passe un jour sur un plan GitHub payant (Team/Enterprise), il devient
possible de revenir à un unique workflow avec de vrais Environments — pas
nécessaire pour l'instant, ce découpage en deux fonctionne aussi bien.

### Prérequis logiciels sur le runner self-hosted

À installer une fois sur la machine qui héberge le runner (pas géré par les
workflows eux-mêmes) :
- **`terraform`** — exécute les `plan`/`apply`/`destroy`.
- **`git`** — utilisé par `terraform/scripts/detect-org-change.sh` pour
  comparer les commits et détecter l'ajout/suppression d'un dossier d'org.
- **`jq`** — utilisé par `terraform/scripts/list-orgs.sh` pour générer la
  liste des orgs au format JSON attendu par `-var='orgs=...'`.

L'authentification à Vault passe entièrement par l'action `hashicorp/vault-action`
dans les workflows — le CLI `vault` n'est pas nécessaire sur le runner pour la CI
(contrairement à l'usage manuel local documenté plus haut, où `login.sh` en a besoin).

> **Isolation** : les jobs `runs-on: self-hosted` s'exécutent **directement sur
> la machine du runner**, pas dans un conteneur éphémère — contrairement aux
> runners hébergés par GitHub. Il n'y a donc pas d'isolation filesystem/process
> stricte entre jobs ou entre runs, et pas de nettoyage garanti au-delà du
> dossier de travail du repo (les credentials injectés en variables d'env ne
> survivent pas au job qui les exporte, mais rien d'autre n'est assaini
> automatiquement). Accepté comme tel pour ce projet (repo privé, équipe
> restreinte de confiance) — à revisiter avec un conteneur Docker éphémère par
> job (`container:` dans le YAML) si le contexte de confiance change.

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
`vault-create-org.yml` détecte l'ajout, exécute `vault-sync` (structure
Vault créée automatiquement pour la nouvelle org), puis affiche dans son
résumé : *« saisir les secrets, puis lancer 2 - Proxmox: apply/destroy cluster
avec org=... action=create »*. Une fois les vrais secrets saisis dans Vault
(Étape 2 ci-dessus), lancer manuellement `proxmox-deploy-cluster.yml` avec
`action=create` → job `apply-infra-create` (VMs créées).

**Supprimer un cluster** — ne jamais supprimer `clusters/<org>/` soi-même :

Lancer directement `proxmox-deploy-cluster.yml` (**Actions > 2 - Proxmox:
apply/destroy cluster > Run workflow**) avec `org=<org>` et `action=delete`,
dossier encore présent dans le repo. Le job `destroy-infra` détruit les VMs
(le code Terraform est disponible directement dans le checkout normal, plus
besoin de retrouver un commit de suppression dans l'historique — ancien
mécanisme abandonné, trop fragile si des commits s'accumulent entre la
suppression du dossier et le déclenchement de la pipeline), puis **la
pipeline elle-même** committe et pousse la suppression du dossier sur `main`.
Le job `vault-cleanup` termine en nettoyant la structure Vault de l'org.

Ce commit automatique redéclenche `vault-create-org.yml` (même trigger sur
`terraform/clusters/**`) — normal, il se termine sans rien faire (`action=none`,
aucune nouvelle org à créer dans ce diff).

> **Permission requise** : le commit automatique utilise le `GITHUB_TOKEN` par
> défaut du job pour pousser sur `main`. Vérifier que les Actions du repo ont
> la permission d'écriture (Settings > Actions > General > Workflow
> permissions > **Read and write permissions**), sinon le step `Remove cluster
> folder and push` échoue avec une erreur d'autorisation.
