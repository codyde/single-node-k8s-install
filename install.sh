export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/root/bin

swapoff -a

# Install and configure IPtables; remove firewalld - Docker uses IPtables 

yum install iptables-services.x86_64 -y
systemctl stop firewalld.service
systemctl disable firewalld.service
systemctl mask firewalld.service
systemctl start iptables
systemctl enable iptables
systemctl unmask iptables
iptables -F
service iptables save

# Configure repo and set Docker daemon to use systemd driver 

yum install -y yum-utils

cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
  "insecure-registries" : [ "10.0.0.0/8:5000" ]
}
EOF

# Install Docker

yum install -y docker
systemctl enable docker && systemctl start docker

sysctl net.bridge.bridge-nf-call-iptables=1

# Configure Kubernetes repository; disable selinux; install kubeadm, kubectl, and kubelet

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet


# Deploy single node Kubernetes cluster 
kubeadm init --pod-network-cidr=10.244.0.0/16

mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml

kubectl --kubeconfig=/etc/kubernetes/admin.conf taint node --all node-role.kubernetes.io/master:NoSchedule-

kubectl --kubeconfig=/etc/kubernetes/admin.conf create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
