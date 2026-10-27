# Template de cluster — copier ce dossier vers clusters/<org>-<env>/, puis :
# 1. Remplacer vr / REPLACE_ME_ENV (ici et backend.hcl) par le vrai nom d'org et l'env.
# 2. Ajouter <org>-<env> à org_subnet_index dans ../../ip-plan.auto.tfvars (prochain index libre).
# 3. Recréer le symlink : ln -s ../../ip-plan.auto.tfvars ip-plan.auto.tfvars
# 4. Ajuster node_count/tags/ressources ci-dessous selon le besoin réel du cluster.
# subnet_index n'est PAS défini ici : lu automatiquement depuis org_subnet_index["<org>-<env>"].
#
# Le nom du dossier DOIT être "<org>-<env>" : c'est l'identifiant de cluster
# utilisé par la CI (scripts/list-orgs.sh), les noms de VM, devver-infra-deployment/<org>-<env>
# et la structure Vault Kubernetes (terraform/vault/k8s-secrets.tf).

org                      = "vr27"
env                      = "dev" # prod | staging | dev
node_count               = 3                # minimum 3 (masters+workers)
additional_workers_count = 0
tags                     = ["devver", "vr27", "dev"]

proxmox_node  = "PROXMOX-PVE1"
datastore_id  = "SSD-PVE-DATA"
template_name = "rocky9-cloud-template"

# Ressources personnalisables indépendamment par org/environnement (valeurs par
# défaut dans module/variables.tf si omises ici) :
# master_cpu_cores = 4
# master_memory    = 6144
# master_disk_size = 40

# worker_cpu_cores       = 4
# worker_memory          = 6144
# worker_disk_size       = 40
# worker_extra_disk_size = 150
