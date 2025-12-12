all:
  hosts:
%{ for ip in masters ~}
    master-${ip}:
      ansible_host: ${ip}
%{ endfor %}
%{ for ip in workers ~}
    worker-${ip}:
      ansible_host: ${ip}
%{ endfor %}

  children:
    kube_control_plane:
      hosts:
%{ for ip in masters ~}
        master-${ip}: {}
%{ endfor %}

    kube_node:
      hosts:
%{ for ip in workers ~}
        worker-${ip}: {}
%{ endfor %}
