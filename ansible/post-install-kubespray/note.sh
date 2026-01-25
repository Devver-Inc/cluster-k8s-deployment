Installer Kubectl sur un appareil
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


Problème Pods DNS
sudo systemctl disable systemd-resolved --now
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf



kubectl label node worker1 node-role.kubernetes.io/worker=""
kubectl label node worker2 node-role.kubernetes.io/worker=""
kubectl label node worker3 node-role.kubernetes.io/worker=""

kubectl taint node master1 node-role.kubernetes.io/control-plane:NoSchedule

prepa pour long horn

sudo mkfs.ext4 /dev/sdb 
sudo mkdir -p /mnt/longhorn 
sudo mount /dev/sdb /mnt/longhorn
sudo apt update 
sudo apt install -y open-iscsi 
sudo systemctl enable --now iscsid

echo "/dev/<DISQUE_LONGHORN> /mnt/longhorn ext4 defaults 0 2" | sudo tee -a /etc/fstab

-------------


sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/longhorn
sudo mount /dev/sdb /mnt/longhorn