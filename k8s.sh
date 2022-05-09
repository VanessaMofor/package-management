#!/bin/bash
# Common stages for both master and worker nodes
# This can be used as user data in launch template or launch configurations
sudo hostnamectl set-hostname master
sudo -i 
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo apt update -y
sudo apt install -y apt-transport-https -y

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt update -y
sudo apt install -y kubelet kubeadm  containerd kubectl
# apt-mark hold will prevent the package from being automatically upgraded or removed.

sudo apt-mark hold kubelet kubeadm kubectl containerd

sudo cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Enable and start kubelet service
sudo systemctl daemon-reload
sudo systemctl start kubelet
sudo systemctl enable kubelet.service

       #Now in MASTER ONLY
#switch to normal user before running the following set of commands
sudo su - ubuntu
#to initialise the cluster run the following command;
sudo kubeadm init       #copy token generated and save somewhere to be used to enable worker nodes join the cluster

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

       #now check if control plane is ready
kubectl get node

       #Worker nodes only
#copy token from above and run here to join the cluster
#example; kubeadm join 172.31.10.12:6443 --token cdm6fo.dhbrxyleqe5suy6e \
        --discovery-token-ca-cert-hash sha256:1fc51686afd16c46102c018acb71ef9537c1226e331840e7d401630b96298e7d
        
kubectl get nodes

#To generate new token in the future for your cluster use the command below;
kubeadm token create --print-join-command
