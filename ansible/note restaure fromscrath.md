---
Partie ansible TF

revoir playbooks ansible car parfois worker+master et d'autres jsute worker ou just master
taint noshcedule on master a revoir
Definir plus de type de role ?

Gérer ssh auto apporuver et reset ancien host

Managé kubeconfig avec ansible + vault ?
> modifié ivnetaire lors intall pour avoir bon endpoint

Voir accès et interaction kubeconfig round robin haproxy ou vip a partir du cluster ?
a choisir 


Necessite reboot pour IPV6 a rajouter dans playbooks

A rajouter dans les labels master/worker > kubectl label nodes devver-k8s-prod-mw-1 devver-k8s-prod-mw-2 devver-k8s-prod-mw-3 node-role.kubernetes.io/worker=""

---

Partie Kubernetes

Restaurer tout depuis git (pas applicatif seulement la stack de base) et PVC depuis sauvegarde

comment gérer le rename des ingress ?

revoir la partir secret et ingress , reflector

secrete external DNS a mettre avec celui de traefik

Ordre de deploiement
metallb > certmanager > traefik > external-nds >longhon

gestion des kubeconfig VIP pour api server

