# subnet_index n'est plus défini ici : le module le lit automatiquement depuis
# org_subnet_index[var.org] dans ../../ip-plan.auto.tfvars (registre centralisé,
# seul endroit à modifier pour ajouter/consulter les index par org).

org                      = "prod"
node_count               = 3
additional_workers_count = 0
tags                     = ["devver", "prod", "test-deploy"]

proxmox_node  = "PROXMOX-PVE1"
datastore_id  = "SSD-PVE-DATA"
template_name = "rocky9-cloud-template"

# Ressources personnalisables indépendamment par org/environnement (valeurs par
# défaut dans module/variables.tf si omises ici) :
master_cpu_cores = 4
master_memory    = 2048
master_disk_size = 35

# worker_cpu_cores       = 4
# worker_memory          = 6144
# worker_disk_size       = 40
# worker_extra_disk_size = 150
