#!/usr/bin/env bash
# https://stackoverflow.com/questions/49721708/how-to-install-specific-version-of-kubernetes
K8S_VERSION=1.15.9-00
K8S_CNI_VERSION=0.7.5-00

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
  sudo apt-get update -q && \
  sudo apt-get install -qy kubernetes-cni=$K8S_CNI_VERSION kubelet=$K8S_VERSION kubectl=$K8S_VERSION kubeadm=$K8S_VERSION
