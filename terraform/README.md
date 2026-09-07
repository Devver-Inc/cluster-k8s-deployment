# Terraform — cluster-k8s-deployment

Provisionnement de clusters RKE2 sur Proxmox, multi-organisation, avec state
sur Backblaze B2 et secrets dans HashiCorp Vault.

> Pour déployer un cluster de A à Z (commandes prêtes à copier-coller), voir
> [`DEPLOY.md`](DEPLOY.md). Ce README explique le *pourquoi* de chaque mécanisme ;
> `DEPLOY.md` est la procédure condensée.

## Structure

```
terraform/
├── ip-plan.auto.tfvars   # SEUL endroit qui définit la plage IP globale + taille des sous-plages
├── login.sh              # à sourcer avant chaque init/apply : VAULT_ADDR + credentials B2 depuis Vault
├── module/                # module RKE2 réutilisable (VMs, allocation IP, inventaire Ansible)
├── clusters/
│   ├── _template/           # dossier prêt à copier-coller pour créer un nouveau cluster
│   ├── prod/                # un dossier racine Terraform par org, state séparé
│   └── ...                  # copier _template/ pour chaque nouvelle org
└── vault/                 # config Vault (KV mount, policies, AppRole, secrets par org) en Terraform
```

Chaque `clusters/<org>/` est un root module Terraform indépendant (son propre
`terraform init`/state sur B2), qui appelle le module partagé `../../module`.
Pour créer un nouveau cluster, copier [`clusters/_template/`](clusters/_template/)
(voir son propre README) plutôt que de dupliquer `prod/` à la main.

## Allocation IP

La plage globale, la taille des sous-plages, **et le registre `subnet_index` par org**
sont tous définis à un **seul endroit** : [`ip-plan.auto.tfvars`](ip-plan.auto.tfvars) :

```hcl
network_base         = "192.168.45"
network_range_start  = 100
network_range_end    = 190
subnet_size          = 10   # IP réservées par org

org_subnet_index = {
  prod = 0
  # preprod = 1
}
```

`subnet_index` n'est **plus jamais saisi dans `clusters/<org>/values.auto.tfvars`** —
le module le lit automatiquement via `org_subnet_index[var.org]`, et dérive sa
sous-plage : `start = network_range_start + subnet_index * subnet_size`. Ajouter une
org = ajouter une ligne ici, dans ce seul fichier — impossible d'oublier de
l'incrémenter puisqu'il n'y a plus qu'un seul endroit où il existe.

La **dernière IP de la sous-plage** est toujours réservée à MetalLB (jamais
assignée à un nœud), exposée en `output "metallb_ip"`.

Changer `subnet_size`, la plage globale, ou `org_subnet_index` dans `ip-plan.auto.tfvars`
met à jour tous les clusters au prochain `plan`/`apply` — chaque
`clusters/<org>/ip-plan.auto.tfvars` est un **symlink** vers ce fichier central.

Une **validation Terraform** (`module/variables.tf`) échoue explicitement si deux
orgs de `org_subnet_index` partagent accidentellement le même index — protection
contre une erreur de frappe, avant tout risque de collision IP réelle.

## Convention Vault

Mount KV v2 unique : **`devver-infra-deployment`**, avec à sa racine :

- `devver-infra-deployment/proxmox` : credentials API Proxmox (`token_id`, `token_secret`), partagés entre toutes les orgs.
- `devver-infra-deployment/s3-backend` : credentials B2 (`key_id`, `application_key`) pour le backend S3, partagés entre toutes les orgs.
- `devver-infra-deployment/ansible` : réservé pour un usage futur, pas encore géré par ce Terraform (pas de policy dessus pour l'instant).
- `devver-infra-deployment/vm_secret_template` : secret "template" (`vm_user`, `ssh_public_key`, `vm_password`/`ssh_private_key` en placeholders) saisi manuellement une fois, cloné vers chaque nouvelle org.
- `devver-infra-deployment/<org>` : copie du template pour cette org — créée automatiquement par `vault/` (voir plus bas). `vm_password`/`ssh_private_key` y restent les placeholders du template tant que tu ne les as pas remplacés à la main ; une fois remplacés, plus jamais écrasés par un futur apply.

Une policy read-only + un role AppRole dédiés existent par org (accès à `proxmox` + `<org>`), créés par `vault/`. Un role à part (`terraform-backblaze`, TTL court) ne donne accès qu'à `devver-infra-deployment/s3-backend`.

### Comment `devver-infra-deployment/<org>` est créé, sans jamais être réécrit

`vault/main.tf` contient une resource `vault_kv_secret_v2.org_secret` (`for_each` sur
la liste des orgs) qui clone `vm_secret_template` vers `<org>` — **mais seulement à la
création**. Elle porte `lifecycle { ignore_changes = [data_json] }` : dès que le secret
existe, Terraform ignore toute différence entre le contenu réel dans Vault et ce que le
`.tf` décrirait, même en relançant `apply` pour d'autres orgs. Concrètement :

- 1er `apply` pour une nouvelle org → le secret `<org>` est créé avec `vm_user`/`ssh_public_key`/`vm_password`/`ssh_private_key` copiés du template (les placeholders de `vm_password`/`ssh_private_key` atterrissent donc dans le state de `vault/` à ce moment précis).
- Toute modification manuelle ensuite dans l'UI Vault (remplacer les placeholders `vm_password`/`ssh_private_key` par de vraies valeurs, changer la clé SSH publique...) est **définitivement préservée** et ne remonte plus jamais dans le state — Terraform ignore ce secret après sa création.

Cette resource vit uniquement dans `vault/` (Terraform admin) — les `clusters/<org>/`
ne font que **lire** `<org>` (`data source`), jamais écrire, donc aucun de ces secrets
n'atterrit dans leur state à eux. Seul le state de `vault/` contient une trace de ces
champs, et uniquement les placeholders initiaux pour `vm_password`/`ssh_private_key` —
jamais les vraies valeurs.

### Pourquoi les credentials B2 ne sont pas lues via une data source Terraform

Le backend S3 (`terraform { backend "s3" {} }`) doit être résolu **avant**
que Terraform puisse évaluer quoi que ce soit d'autre, y compris une
`data "vault_kv_secret_v2"` — impossible donc de lire les credentials B2
depuis Vault *via le module lui-même* sans se retrouver dans une dépendance
circulaire (il faudrait le backend pour interroger Vault, et Vault pour
configurer le backend). Vault reste malgré tout la source de vérité : les
credentials B2 sont récupérées à part, juste avant chaque `init`, via
[`login.sh`](login.sh) — jamais commitées ni codées en dur. Ce même script
force aussi `VAULT_ADDR` (évite le fallback silencieux vers `127.0.0.1:8200`
si la variable n'est pas déjà exportée dans le shell).

## Mise en place

Trois grandes étapes, qui correspondent aux jobs de la pipeline CI
(voir [`DEPLOY.md`](DEPLOY.md#via-la-pipeline-ci)) :
**0-1. créer la structure Vault** → **2. action manuelle (compléter les secrets)** → **3. déployer l'infra**.

### 0. Amorçage — le seul point où Vault n'est pas encore la source

Le tout premier `apply` de `vault/` est l'exception inévitable : Vault n'a pas encore
de secret `devver-infra-deployment/s3-backend` à ce stade (c'est cet apply qui crée le
mount KV où on l'écrira), donc les credentials B2 doivent être saisies manuellement une
seule fois, ici seulement :

```bash
cd vault
export VAULT_TOKEN=...          # token admin/root
export AWS_ACCESS_KEY_ID=...    # clés B2 (saisies à la main, uniquement ici)
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend.hcl
```

Écrire ensuite les credentials B2 dans Vault, une fois pour toutes, pour que tous les
runs suivants (y compris les prochains `apply` de ce même dossier) les récupèrent
depuis Vault plutôt qu'à la main :

```bash
vault kv put devver-infra-deployment/s3-backend key_id=... application_key=...
```

Écrire aussi le template, avant le premier `apply` (il est lu par la resource qui clone
vers chaque org) — `vm_password`/`ssh_private_key` y sont de simples placeholders, à
remplacer ensuite dans chaque `<org>` individuellement, jamais utilisés tels quels :

```bash
vault kv put devver-infra-deployment/vm_secret_template \
  vm_user=devver \
  ssh_public_key="ssh-ed25519 ..." \
  vm_password="CHANGE_ME" \
  ssh_private_key="CHANGE_ME"
```

### 1. Créer/mettre à jour la structure Vault (à chaque ajout d'org)

```bash
cd vault
source ../login.sh   # VAULT_ADDR + AWS_ACCESS_KEY_ID/SECRET depuis Vault désormais

terraform init -backend-config=backend.hcl
terraform apply -var='orgs=["prod","<nouvelle-org>"]'
```

Ça crée (ou laisse intact si déjà existant) : le mount KV, la policy + role AppRole de
chaque org, et le secret `devver-infra-deployment/<org>` cloné depuis le template.

Écrire les credentials Proxmox si pas déjà fait :
```bash
vault kv put devver-infra-deployment/proxmox token_id=... token_secret=...
```

Récupérer le `role_id` (stable, pas besoin de le régénérer) et générer un `secret_id`
pour l'org (jamais stocké dans le state) :
```bash
vault read -field=role_id auth/terraform-orgs/role/terraform-prod/role-id
vault write -f auth/terraform-orgs/role/terraform-prod/secret-id
```

### 2. Action manuelle — compléter les secrets de l'org

Dans l'UI Vault (ou CLI), sur `devver-infra-deployment/<org>` fraîchement créé :
remplacer les placeholders `vm_password`/`ssh_private_key` par de vraies valeurs, ou
ajuster `vm_user`/`ssh_public_key` si cette org a besoin de credentials différents du
template. Ces valeurs ne seront plus jamais écrasées par Terraform.

```bash
vault kv patch devver-infra-deployment/prod vm_password='...' ssh_private_key='...'
```

### 3. Déployer un cluster

```bash
cd clusters/prod
source ../../login.sh   # VAULT_ADDR + AWS_ACCESS_KEY_ID/SECRET depuis Vault

export TF_VAR_vault_role_id=...
export TF_VAR_vault_secret_id=...

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

L'inventaire Ansible est généré dans `clusters/prod/generated/inventory-prod.ini`
(groupes `[server]` pour les nœuds control-plane+worker, `[agent]` pour les
workers additionnels — convention RKE2 type `lablabs.rke2`).

### Ajouter une nouvelle organisation — résumé

1. Copier `clusters/_template/` vers `clusters/<org>/` et suivre son [README](clusters/_template/README.md)
   (remplacer `REPLACE_ME_ORG`, recréer le symlink `ip-plan.auto.tfvars`).
2. Ajouter l'org à `org_subnet_index` dans `ip-plan.auto.tfvars` (prochain index libre).
3. Étape 1 : ajouter l'org à `vault/` (`terraform apply -var='orgs=["prod","<org>"]'`), générer son `secret_id`.
4. Étape 2 : compléter `vm_password`/`ssh_private_key` (et ajuster le reste si besoin) dans `devver-infra-deployment/<org>`.
5. Étape 3 : `terraform init/plan/apply` dans `clusters/<org>/`.

## Pipeline CI

Les 3 étapes ci-dessus sont automatisées par deux workflows,
[`detect-and-prepare.yml`](../.github/workflows/detect-and-prepare.yml) (auto)
et [`continue-deploy.yml`](../.github/workflows/continue-deploy.yml) (manuel) :
un push ajoutant/supprimant un dossier `clusters/<org>/` déclenche la
détection et la structure Vault, puis un second déclenchement manuel termine
l'apply/destroy infra (découpage en deux dû à l'absence des Environments
GitHub natifs sur repo privé en plan Free). Voir
[`DEPLOY.md`](DEPLOY.md#via-la-pipeline-ci) pour le setup initial (AppRole
`terraform-ci`, secrets GitHub) et le détail du flux.

## Prochaines étapes

- Consommation de `output "metallb_ip"` par l'installation MetalLB du cluster.
