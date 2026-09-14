# Ansible — installation RKE2

Trois playbooks indépendants (pas encore raccordés à la pipeline CI) qui
amènent les VMs provisionnées par Terraform jusqu'à un cluster RKE2
fonctionnel. Cible : Rocky Linux 9 (template Terraform actuel).

## Prérequis

```bash
pip install ansible
ansible-galaxy collection install -r requirements.yml
```

## Secrets et inventaire

- **Inventaire** : généré par Terraform dans
  `../terraform/clusters/<org>/ansible-inventory/inventory-<org>.ini`
  (committé — ne contient que IP/hostname/user, jamais de secret).
- **Secrets** (`ssh_private_key`, `vm_password`, et en sortie `kubeconfig`,
  `rke2_token`) : lus/écrits dans Vault (`devver-infra-deployment/<org>`) via
  le plugin `community.hashi_vault`, avec le même AppRole `terraform-ci` que
  Terraform. Fournir avant chaque run :

```bash
export VAULT_ROLE_ID='...'
export VAULT_SECRET_ID='...'
```

## Lancer un déploiement complet

`ansible_ssh_private_key_file` (`group_vars/all.yml`) est résolu **avant** la
première connexion SSH — aucune tâche d'un playbook ne peut donc écrire cette
clé à temps. `fetch-ssh-key.sh` la récupère depuis Vault et l'écrit dans un
fichier temporaire local, **toujours supprimé en sortie de shell** (`trap
EXIT`), à sourcer avant chaque run :

```bash
cd ansible
INV=../terraform/clusters/<org>/ansible-inventory/inventory-<org>.ini

source ./fetch-ssh-key.sh <org>

ansible-playbook -i "$INV" -e cluster_org=<org> playbooks/01-base.yml
ansible-playbook -i "$INV" -e cluster_org=<org> playbooks/02-dependencies.yml
ansible-playbook -i "$INV" -e cluster_org=<org> playbooks/03-cluster-init.yml
```

## Ce que fait chaque playbook

1. **`01-base.yml`** (tous les nœuds) — maj système, DNS, désactive IPv6 et le
   swap, charge les modules kernel requis par RKE2 (`overlay`,
   `br_netfilter`) + sysctl associés, active chronyd (NTP).
2. **`02-dependencies.yml`** (tous les nœuds) — `nfs-utils` (préreq de la
   storage class `nfs.csi.k8s.io`, le CSI driver lui-même n'est pas déployé
   ici), ouvre les ports firewalld RKE2 (différents selon `[server]`/`[agent]`,
   voir `group_vars/server.yml`/`agent.yml`), installe le binaire RKE2 sans
   démarrer le service.
3. **`03-cluster-init.yml`** — initialise le 1er master, récupère son token de
   jonction, joint les masters suivants puis les workers (tous pointent vers
   l'IP du 1er master — pas de VIP/HAProxy pour l'instant), récupère le
   kubeconfig (adapté pour pointer vers l'IP réelle plutôt que `127.0.0.1`),
   écrit `kubeconfig` + `rke2_token` dans Vault sans écraser les champs déjà
   présents (`vm_user`, `ssh_public_key`, ...).

## Limitation connue — jonction sans VIP

Tous les nœuds pointent directement vers l'IP du 1er master
(`rke2_first_server_ip`, `server: https://<ip>:9345`). Si ce nœud est down,
les masters/workers déjà joints continuent de fonctionner entre eux, mais un
**nouveau** join échoue tant qu'il n'est pas relancé. Migration prévue plus
tard vers une VIP HAProxy devant les masters — implique de reconfigurer
`server:` sur tous les nœuds et de régénérer le kubeconfig stocké dans Vault
pour qu'il pointe vers cette VIP plutôt que l'IP du 1er master.

## Isolation (exécution à plat sur le runner)

Comme Terraform (décision déjà actée dans `terraform/DEPLOY.md`), ces
playbooks tournent **directement sur la machine du runner self-hosted**, pas
dans un conteneur éphémère — pas d'isolation filesystem/process stricte entre
runs. La clé SSH privée écrite par `fetch-ssh-key.sh` n'existe sur disque que
le temps du run (toujours nettoyée, `trap EXIT`), même ordre de risque que les
credentials B2/Vault déjà acceptés en clair en variables d'environnement
pendant un job CI. Accepté pour ce contexte (repo privé, équipe restreinte) —
à revisiter avec un conteneur dédié si le contexte de confiance change.

## Pipeline CI

[`ansible-configure-clusters.yml`](../.github/workflows/ansible-configure-clusters.yml)
(« **3 - Ansible: configurer les clusters** » dans l'onglet Actions) —
automatique, déclenché par un push touchant `ansible/` sur `main`.
Volontairement **indépendant de Terraform/Vault** (aucun trigger sur
`terraform/clusters/**`) : un nouveau cluster créé côté Terraform n'a pas
Ansible appliqué automatiquement, il faut soit lancer les playbooks en local
(voir ci-dessus), soit attendre/provoquer un prochain push sur `ansible/`.

Applique les 3 playbooks à **tous** les clusters existants d'un coup (scan de
`terraform/clusters/<org>/` via `terraform/scripts/list-orgs.sh`, un job par
org via une `matrix` GitHub Actions) — sans confirmation manuelle, accepté
parce que les playbooks sont **idempotents** : les rejouer sur un cluster déjà
configuré ne doit rien casser.

## Prochaines étapes

- Déployer le CSI driver NFS (`nfs.csi.k8s.io`) une fois le cluster prêt.
- MetalLB / allocation IP (volontairement hors périmètre ici).
