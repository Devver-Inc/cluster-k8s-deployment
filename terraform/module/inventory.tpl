# Généré automatiquement par Terraform — ne pas éditer à la main.
# Cluster: ${org}  |  MetalLB IP réservée: ${metallb_ip}

[server]
%{ for name, node in mixed_nodes ~}
${name} ansible_host=${node.ip} ansible_user=${vm_user}
%{ endfor ~}

[agent]
%{ for name, node in worker_only_nodes ~}
${name} ansible_host=${node.ip} ansible_user=${vm_user}
%{ endfor ~}

[k8s_cluster:children]
server
agent

[k8s_cluster:vars]
# IP de l'ingress (Traefik, Service LoadBalancer annoncé par MetalLB) —
# utilisée par ansible/playbooks/03-cluster-init.yml.
metallb_ip=${metallb_ip}
%{ for k, v in cluster_vars ~}
${k}=${v}
%{ endfor ~}
