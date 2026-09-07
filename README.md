# cluster-k8s-deployment

Provisionnement et déploiement de clusters Kubernetes (RKE2) sur une
infrastructure Proxmox on-prem, pour plusieurs organisations/environnements,
entièrement piloté par Terraform et automatisé via une pipeline CI sur runner
self-hosted.

## Vue d'ensemble

```
Admin                 terraform/clusters/<org>/       CI (GitHub Actions)
  │                          │                              │
  │  ajoute/supprime ───────▶│                              │
  │  un dossier org          │──── push sur main ──────────▶│
  │                          │                              │
  │                          │              ┌───────────────┴───────────────┐
  │                          │              │  vault/  (structure secrets)  │
  │                          │              └───────────────┬───────────────┘
  │                          │                              │
  │  ◀── saisit les vrais secrets dans Vault ── gate ────────┤ (approbation manuelle)
  │       (vm_password, ssh_private_key, ...)                │
  │                          │              ┌───────────────┴───────────────┐
  │                          │              │  clusters/<org>/ (VMs Proxmox)│
  │                          │              └────────────────────────────────┘
  ▼                                                          ▼
HashiCorp Vault  ◀──────── secrets ────────────────── Proxmox (VMs) + Backblaze B2 (state)
```

Un seul point d'entrée côté admin : **ajouter ou supprimer un dossier sous
`terraform/clusters/`**. Tout le reste — création de la structure Vault pour
la nouvelle organisation, pause pour la saisie manuelle des secrets, création
ou destruction des VMs sur Proxmox — s'enchaîne automatiquement via la
pipeline GitHub Actions, avec des points de validation humaine explicites
avant toute action sensible (saisie de secrets, destruction d'infrastructure).

## Composants

| Composant | Rôle |
|---|---|
| **Terraform** | Décrit et provisionne les VMs Proxmox (masters + workers RKE2), l'allocation IP, la structure Vault. |
| **Proxmox** | Hyperviseur on-prem qui héberge les VMs des clusters. |
| **HashiCorp Vault** | Source unique des secrets (credentials Proxmox, backend B2, SSH/login VM par organisation) — jamais de secret en clair dans le repo. |
| **Backblaze B2** | Stockage du `state` Terraform (backend compatible S3), un fichier par module (`vault/`, chaque `clusters/<org>/`). |
| **GitHub Actions (runner self-hosted)** | Exécute la pipeline CI/CD sur l'infrastructure on-prem, déclenchée par les changements dans `terraform/clusters/`. |
| **Ansible** *(à venir)* | Configuration post-provisioning des VMs (installation RKE2, etc.) à partir de l'inventaire généré par Terraform. |

## Structure du repo

```
.
├── .github/workflows/       # pipeline CI (detect-and-prepare.yml + continue-deploy.yml)
├── terraform/
│   ├── README.md            # documentation technique détaillée (le "pourquoi")
│   ├── DEPLOY.md            # procédure pas-à-pas, manuelle ET pipeline (le "comment")
│   ├── ip-plan.auto.tfvars  # plage IP globale + registre des organisations
│   ├── login.sh             # helper d'authentification Vault pour l'usage local
│   ├── module/               # module Terraform réutilisable (VMs RKE2, allocation IP, inventaire Ansible)
│   ├── vault/                # structure Vault (mount, policies, secrets par org) en Terraform
│   ├── clusters/
│   │   ├── _template/          # dossier à copier pour créer une nouvelle organisation
│   │   └── <org>/               # un dossier par organisation, state Terraform indépendant
│   └── scripts/               # scripts utilisés par la pipeline CI
└── ansible/                  # (vide pour l'instant — post-provisioning des clusters)
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
- **Validation humaine avant toute action sensible** : la pipeline s'arrête et
  attend une approbation explicite avant de créer des secrets ou de détruire
  de l'infrastructure — jamais d'automatisation "silencieuse" sur ces points.
- **Isolation par organisation** : chaque cluster a son propre state Terraform,
  sa propre plage IP, ses propres secrets — la panne ou la modification d'un
  cluster n'affecte jamais les autres.
