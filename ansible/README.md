# Ansible — installation RKE2

Quatre playbooks indépendants qui amènent les VMs provisionnées par
Terraform jusqu'à un cluster RKE2 fonctionnel, et retirent proprement un
node avant qu'il ne soit détruit. Cible : Rocky Linux 9 (template Terraform
actuel).

## Prérequis

Pour un run **local/manuel** :

```bash
pip install ansible
ansible-galaxy collection install -r requirements.yml
```

En **CI** (jobs `configure`/`remove-worker` du workflow `2 - Proxmox`), ces
prérequis sont fournis par l'image `runner-images/ansible/` — voir
[Isolation](#isolation--exécution-en-conteneur).

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

`fetch-ssh-key.sh` récupère `ssh_private_key` depuis Vault et l'écrit dans un
fichier temporaire local, **toujours supprimé en sortie de shell** (`trap
EXIT`), à sourcer avant chaque run. Le chemin de ce fichier est ensuite passé
explicitement à chaque `ansible-playbook` via `-e
ansible_ssh_private_key_file=...` — **pas** défini dans `group_vars/all.yml` :
`{{ playbook_dir }}` ne s'est pas révélé fiable pour une variable de connexion
(résolue avant la 1ère connexion SSH), Ansible retombait alors silencieusement
sur aucune clé (`Permission denied` sans jamais signaler de chemin
introuvable) :

```bash
cd ansible
INV=../terraform/clusters/<org>/ansible-inventory/inventory-<org>.ini

source ./fetch-ssh-key.sh <org>
KEY_PATH="$(pwd)/.ssh_key_<org>"

ansible-playbook -i "$INV" -e cluster_org=<org> -e ansible_ssh_private_key_file="$KEY_PATH" playbooks/01-base.yml
ansible-playbook -i "$INV" -e cluster_org=<org> -e ansible_ssh_private_key_file="$KEY_PATH" playbooks/02-dependencies.yml
ansible-playbook -i "$INV" -e cluster_org=<org> -e ansible_ssh_private_key_file="$KEY_PATH" playbooks/03-cluster-init.yml
```

## Ce que fait chaque playbook

1. **`01-base.yml`** (tous les nœuds) — maj système, DNS, désactive IPv6 et le
   swap, charge les modules kernel requis par RKE2 (`overlay`,
   `br_netfilter`) + sysctl associés, active chronyd (NTP) et
   `qemu-guest-agent` (requis côté OS pour que Proxmox obtienne l'IP/état
   réel de la VM — Terraform active déjà `agent.enabled=true` côté hyperviseur).
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
4. **`04-remove-node.yml`** — désinstalle RKE2 (`rke2-killall.sh` puis
   `rke2-uninstall.sh`) sur un worker déjà drainé côté Kubernetes, juste
   avant que Terraform ne détruise sa VM. **Toujours** lancé avec `--limit`
   ciblant précisément le(s) node(s) concerné(s) (jamais tout l'inventaire),
   orchestré par le job `remove-worker` de
   [`proxmox-deploy-cluster.yml`](../.github/workflows/proxmox-deploy-cluster.yml)
   — voir [Retrait d'un worker](#retrait-dun-worker) plus bas.

## Limitation connue — jonction sans VIP

Tous les nœuds pointent directement vers l'IP du 1er master
(`rke2_first_server_ip`, `server: https://<ip>:9345`). Si ce nœud est down,
les masters/workers déjà joints continuent de fonctionner entre eux, mais un
**nouveau** join échoue tant qu'il n'est pas relancé. Migration prévue plus
tard vers une VIP HAProxy devant les masters — implique de reconfigurer
`server:` sur tous les nœuds et de régénérer le kubeconfig stocké dans Vault
pour qu'il pointe vers cette VIP plutôt que l'IP du 1er master.

## Retrait d'un worker

Avant cette procédure, réduire `additional_workers_count` dans
`values.auto.tfvars` puis relancer `terraform apply` détruisait directement
la VM du worker **sans jamais le retirer du cluster** — le node restait
`NotReady` indéfiniment dans `kubectl get nodes`, rien ne le nettoyait après
coup.

Le job `remove-worker` de
[`proxmox-deploy-cluster.yml`](../.github/workflows/proxmox-deploy-cluster.yml)
automatise désormais la séquence complète, dans cet ordre strict :

1. `terraform/scripts/detect-worker-removal.sh` lit un vrai `terraform plan`
   pour savoir EXACTEMENT quel(s) `worker-N` va être détruit — échoue net
   (garde-fou) si le plan révèle la destruction d'un **master** (retrait de
   master non supporté par ce mécanisme, risque de perte de quorum etcd,
   intervention manuelle requise).
2. `fetch-kubeconfig.sh` récupère le kubeconfig depuis Vault (même pattern
   que `fetch-ssh-key.sh` : fichier temporaire, `trap EXIT`, jamais
   committé), puis `kubectl drain <node> --ignore-daemonsets
   --delete-emptydir-data --force --timeout=120s` — **si le drain
   échoue/timeout, tout le job échoue, aucune VM n'est détruite ensuite**
   (pas de bascule automatique en force au-delà de ce qui est déjà dans la
   commande).
3. `playbooks/04-remove-node.yml` (SSH, `--limit` sur le node ciblé) :
   `rke2-killall.sh` puis `rke2-uninstall.sh`.
4. `kubectl delete node <node>` — le node disparaît de `kubectl get nodes`.
5. **Seulement si tout ce qui précède a réussi** : `terraform apply` détruit
   la VM, désormais proprement désinscrite du cluster.

Drain/delete-node se font en `kubectl` direct depuis le job CI (pas en
Ansible) : ce sont des opérations API Kubernetes pures, sans rapport avec le
node lui-même — Ansible n'intervient que pour la partie SSH/désinstallation
système (`04-remove-node.yml`).

## Isolation (exécution en conteneur)

Contrairement à Terraform (qui reste à plat sur le runner, voir
`terraform/DEPLOY.md`), **les jobs `configure` et `remove-worker`** du
workflow `2 - Proxmox` — y compris le login Vault (`hashicorp/vault-action`)
et `fetch-ssh-key.sh`/`fetch-kubeconfig.sh` — tournent dans un conteneur
Docker custom défini par
[`runner-images/ansible/Dockerfile`](../runner-images/ansible/Dockerfile)
(`container:` au niveau du job dans le YAML). Le runner self-hosted lui-même
n'a besoin que de Docker installé — ni Ansible, ni le CLI `vault`/`kubectl`,
ni la collection `community.hashi_vault` ne sont requis à plat.

L'image contient : `ansible-core`, la collection `community.hashi_vault`, le
CLI `vault`, `kubectl`, `git` (pour `actions/checkout`) et un client SSH.
Elle est buildée par le job `build-ansible-image` et poussée sur GHCR
(`ghcr.io/<owner>/<repo>/ansible-runner`, package privé rattaché au repo),
**taguée par la ligne `# IMAGE_VERSION=` en tête du
[`Dockerfile`](../runner-images/ansible/Dockerfile)** — `build-ansible-image`
réutilise l'image si ce tag existe déjà sur GHCR, et ne rebuild/push que si
cette version a été incrémentée manuellement (à faire à chaque changement du
`Dockerfile` ou de `ansible/requirements.yml`). Un registry est nécessaire
même en 100% self-hosted : un job qui déclare `container:` fait toujours un
`docker pull` avant de démarrer, sans fallback sur le cache Docker local de la
machine.

La clé SSH privée écrite par `fetch-ssh-key.sh` n'existe que dans le
filesystem éphémère du conteneur, jamais sur le disque persistant du runner,
et reste nettoyée en sortie de shell (`trap EXIT`) en plus de disparaître avec
le conteneur en fin de job.

## Pipeline CI

Ansible n'a plus de workflow dédié — il est entièrement intégré au workflow
[`proxmox-deploy-cluster.yml`](../.github/workflows/proxmox-deploy-cluster.yml)
(« **2 - Proxmox: apply/destroy cluster** » dans l'onglet Actions), déclenché
par push sur `terraform/clusters/**`, `ansible/**` ou
`runner-images/ansible/**`.

Après un `terraform apply` réussi pour **create-cluster** ou **add-worker**,
le job `configure` s'enchaîne **automatiquement** (`needs:` sur le job
Terraform correspondant) et applique les 3 playbooks
(`01-base.yml`/`02-dependencies.yml`/`03-cluster-init.yml`) — mais
**uniquement sur l'org concernée par ce push**, jamais sur tous les clusters
existants (contrairement à l'ancien workflow séparé, qui reconfigurait
systématiquement toutes les orgs à chaque modification sous `ansible/`).
Accepté sans confirmation manuelle parce que les playbooks sont
**idempotents** : les rejouer sur un cluster déjà configuré ne doit rien
casser — c'est d'ailleurs ce qui se produit naturellement si `ansible/**`
change seul (sans modification Terraform) : tant qu'aucune org n'a de
`create-cluster`/`add-worker` détecté pour ce push, le job `configure` ne se
déclenche sur aucune org (il n'y a alors rien à reconfigurer automatiquement
— relancer manuellement en local, voir ci-dessus, ou via
`workflow_dispatch`).

## Prochaines étapes

- Déployer le CSI driver NFS (`nfs.csi.k8s.io`) une fois le cluster prêt.
- MetalLB / allocation IP (volontairement hors périmètre ici).
