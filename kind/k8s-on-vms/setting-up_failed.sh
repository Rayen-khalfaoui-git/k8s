#i am going to set up kubernetes manually on 3 vms
#on master node
#disable swap
swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
#Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply sysctl params without reboot
sudo sysctl --system
# Verify that the br_netfilter, overlay modules are loaded by running the following commands:
lsmod | grep br_netfilter
lsmod | grep overlay
# Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system variables are set to 1 in your sysctl config by running the following command:
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
#install containerd
apt-get update && apt-get install -y containerd
#got errors and it apears to be becaue of wrong time
# Set correct timezone
sudo timedatectl set-timezone UTC

# Sync with NTP (Network Time Protocol)
sudo apt install -y systemd-timesyncd
sudo systemctl start systemd-timesyncd
sudo systemctl enable systemd-timesyncd
# Force immediate sync
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
#verifying time 
date
# now it should be ok
sudo apt update && sudo apt upgrade -y
sudo apt-get install containerd
sudo systemctl enable --now containerd
systemctl status containerd
#containerd is installed now
#installing runc
sudo apt-get install runc
#looks like runc is already installed
#installing cni plugin, i dont understand which cni plugin is this ? 
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.0.tgz
#now installing kubeadm kubelet kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
#the previous commands added the repo and the gpg key
sudo apt-get update
sudo apt-get install -y kubelet=1.29.6-1.1 kubeadm=1.29.6-1.1 kubectl=1.29.6-1.1 --allow-downgrades --allow-change-held-packages
sudo apt-mark hold kubelet kubeadm kubectl
#hold prevents automatic updates because components should be updated together
#Configure crictl to work with containerd
#initialize control plane
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=172.31.89.68 --node-name master
#i got an error of timeout 
#looks like containerd was not configured properly 
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
#now fixing critcl permissions
# Configure crictl to use containerd socket
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
sudo crictl config image-endpoint unix:///var/run/containerd/containerd.sock
# Test crictl
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps
#it works now
#reseting kubeadm
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d $HOME/.kube
# Clean up any leftover containers
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock rmi --prune
# Pull kubeadm images first
sudo kubeadm config images pull
# Now initialize kubeadm again
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=172.31.89.68 \
  --cri-socket=unix:///var/run/containerd/containerd.sock
#got the same timeout error
#checking ports usage
sudo ss -tlnp | grep 6443
sudo ss -tlnp | grep 2379
#looks like no process is using these ports
# Test if containerd can run a simple container
sudo ctr images pull docker.io/library/nginx:alpine
sudo ctr run --rm docker.io/library/nginx:alpine test nginx -v
#it works
#resetting kubeadm again
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/ /var/lib/etcd/ $HOME/.kube /etc/cni/net.d
#Clean ALL containers
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock rmi --prune
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock rmp --all
# Verify containerd config
cat /etc/containerd/config.toml | grep -A2 -B2 SystemdCgroup
#ah the config file is empty or missing
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
#Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
#Verify the change
cat /etc/containerd/config.toml | grep -A2 -B2 SystemdCgroup
#same problem ,there is nothing
#i will be reverting to a clean install snapshot of the vm and following a tutorial 