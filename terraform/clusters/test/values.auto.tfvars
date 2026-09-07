# Template de cluster — copier ce dossier vers clusters/<org>/, puis :
# 1. Remplacer REPLACE_ME_ORG partout (ici, backend.hcl, variables.tf) par le vrai nom d'org.
# 2. Ajouter l'org à org_subnet_index dans ../../ip-plan.auto.tfvars (prochain index libre).
# 3. Recréer le symlink : ln -s ../../ip-plan.auto.tfvars ip-plan.auto.tfvars
# 4. Ajuster node_count/tags/ressources ci-dessous selon le besoin réel du cluster.
# subnet_index n'est PAS défini ici : lu automatiquement depuis org_subnet_index[var.org].

org                      = "test"
node_count               = 3 # minimum 3 (masters+workers)
additional_workers_count = 0
tags                     = ["devver", "test"]

proxmox_node  = "PROXMOX-PVE1"
datastore_id  = "SSD-PVE-DATA"
template_name = "rocky9-cloud-template"
#
# Ressources personnalisables indépendamment par org/environnement (valeurs par
# défaut dans module/variables.tf si omises ici) :
# master_cpu_cores = 4
# master_memory    = 6144
# master_disk_size = 40

# worker_cpu_cores       = 4
# worker_memory          = 6144
# worker_disk_size       = 40
# worker_extra_disk_size = 150
