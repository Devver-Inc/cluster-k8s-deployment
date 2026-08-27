# Plage globale disponible pour tous les clusters RKE2, et taille des sous-plages
# allouées par organisation. Modifier ici uniquement — chaque clusters/<org>/ symlinke
# ce fichier et en hérite automatiquement au prochain plan/apply.
network_base        = "192.168.45"
network_range_start = 100
network_range_end   = 190
subnet_size         = 10 # nb d'IP réservées par org (noeuds + 1 IP MetalLB en dernière position)

# Registre CENTRALISÉ des subnet_index par org — SEUL endroit à modifier pour
# ajouter une org ou consulter les index déjà pris. Chaque clusters/<org>/ lit
# org_subnet_index[var.org] au lieu d'un subnet_index en dur — impossible
# d'oublier de l'incrémenter puisqu'il n'y a plus qu'ici à l'écrire. Le module
# échoue explicitement si deux orgs partagent accidentellement le même index.
org_subnet_index = {
  prod = 0
  # preprod = 1
  # orgaX   = 2
}
