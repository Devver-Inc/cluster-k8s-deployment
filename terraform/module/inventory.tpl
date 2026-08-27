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
