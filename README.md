# cluster-k8s-deployment

Provisionnement et déploiement de clusters Kubernetes (RKE2) sur une
infrastructure Proxmox on-prem, pour plusieurs organisations/environnements,
piloté par Terraform + Ansible et automatisé via des pipelines CI sur runner
self-hosted.

## Vue d'ensemble

Deux workflows GitHub Actions, chacun avec son propre déclencheur :

1. **`1 - Vault: création structure org`** — push sur `terraform/clusters/**`
   détecte automatiquement une nouvelle org et crée sa structure Vault
   (mount, policy, secret cloné depuis un template). N'agit que sur l'org
   ajoutée, jamais sur les autres.
2. **`2 - Proxmox: apply/destroy cluster`** — push sur
   `terraform/clusters/**`, `ansible/**` ou `runner-images/ansible/**`.
   Confirme par un vrai `terraform plan` (état réel, pas un simple diff de
   commits) l'une de 4 actions selon ce qui a changé : `create-cluster`
   (nouveau dossier + structure Vault déjà créée), `delete-cluster` (dossier
   supprimé), `add-worker`/`remove-worker` (`additional_workers_count`
   modifié dans `values.auto.tfvars`) — `remove-worker` draine et désinscrit
   proprement le node du cluster Kubernetes **avant** que Terraform ne
   détruise sa VM. Après un `create-cluster`/`add-worker` réussi, les
   playbooks Ansible (RKE2) s'enchaînent **automatiquement**, uniquement sur
   l'org concernée par ce push.

Voir [`terraform/DEPLOY.md`](terraform/DEPLOY.md) et
[`ansible/README.md`](ansible/README.md) pour le détail de chaque flux.

## Composants

| Composant | Rôle |
|---|---|
| **Terraform** | Décrit et provisionne les VMs Proxmox (masters + workers RKE2), l'allocation IP, la structure Vault. |
| **Proxmox** | Hyperviseur on-prem qui héberge les VMs des clusters. |
| **HashiCorp Vault** | Source unique des secrets (credentials Proxmox, backend B2, SSH/login VM par organisation) — jamais de secret en clair dans le repo. |
| **Backblaze B2** | Stockage du `state` Terraform (backend compatible S3), un fichier par module (`vault/`, chaque `clusters/<org>/`). |
| **GitHub Actions (runner self-hosted)** | Exécute la pipeline CI/CD sur l'infrastructure on-prem — un workflow pour la structure Vault, un pour l'infra Proxmox qui enchaîne aussi la configuration Ansible. |
| **Ansible** | Configuration post-provisioning des VMs (installation RKE2) à partir de l'inventaire généré par Terraform et des secrets Vault. |

## Structure du repo

```
.
├── .github/workflows/       # pipeline CI (vault-create-org.yml, proxmox-deploy-cluster.yml — ce dernier inclut aussi Ansible)
├── runner-images/
│   └── ansible/              # Dockerfile (versionné via IMAGE_VERSION=) de l'image du job Ansible (voir ansible/README.md#isolation)
├── terraform/
│   ├── README.md            # documentation technique détaillée (le "pourquoi")
│   ├── DEPLOY.md            # procédure pas-à-pas, manuelle ET pipeline (le "comment")
│   ├── ip-plan.auto.tfvars  # plage IP globale + registre des organisations
│   ├── login.sh             # helper d'authentification Vault pour l'usage local
│   ├── module/               # module Terraform réutilisable (VMs RKE2, allocation IP, inventaire Ansible)
│   ├── vault/                # structure Vault (mount, policies, secrets par org) en Terraform
│   ├── clusters/
│   │   ├── _template/          # dossier à copier pour créer une nouvelle organisation
│   │   └── <org>/               # un dossier par organisation, state Terraform + inventaire Ansible
│   └── scripts/               # scripts utilisés par la pipeline CI
└── ansible/                  # playbooks d'installation RKE2 (voir ansible/README.md)
```

## Pour commencer

- **Comprendre l'architecture** (allocation IP, convention Vault, pourquoi
  chaque mécanisme existe) → [`terraform/README.md`](terraform/README.md).
- **Déployer un cluster** (procédure manuelle pas-à-pas, ou setup de la
  pipeline CI) → [`terraform/DEPLOY.md`](terraform/DEPLOY.md).
- **Ajouter une nouvelle organisation** → copier
  [`terraform/clusters/_template/`](terraform/clusters/_template/) (voir son
  propre README), puis suivre [`terraform/DEPLOY.md`](terraform/DEPLOY.md) —
  manuellement ou en laissant la pipeline CI tout enchaîner.

## Principes de conception

- **Un seul point d'entrée côté admin** : toute l'opération (créer, modifier,
  supprimer un cluster) passe par `terraform/clusters/`. La pipeline déduit
  automatiquement l'action à mener.
- **Vault comme source unique de secrets** : aucun credential (Proxmox, B2,
  SSH, mot de passe VM) n'est jamais commité ni codé en dur — voir la
  [convention Vault](terraform/README.md#convention-vault) pour le détail des
  chemins et de ce que Terraform écrit ou lit seulement.
- **Validation humaine avant toute action sensible** : la création de
  structure Vault reste un déclenchement manuel explicite
  (`workflow_dispatch`). Les opérations sur l'infra Proxmox (créer, détruire,
  scale up/down) se pilotent par push — la revue du commit/PR tient lieu de
  validation, remplacée pour `remove-worker` par un garde-fou automatique qui
  bloque tout retrait de master et échoue net si le drain Kubernetes se
  bloque (aucune VM détruite dans ce cas).
- **Isolation par organisation** : chaque cluster a son propre state Terraform,
  sa propre plage IP, ses propres secrets — la panne ou la modification d'un
  cluster n'affecte jamais les autres.
