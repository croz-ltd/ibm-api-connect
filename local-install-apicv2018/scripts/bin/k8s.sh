echo --------
echo start k8s
echo --------
sudo kubeadm init --pod-network-cidr 192.168.0.0/16
mkdir -p ~/.kube
sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config
sudo chmod 755 -R  ~/.kube/
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/master-
