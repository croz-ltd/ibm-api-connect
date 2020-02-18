#!/usr/bin/env bash
set -eu -o pipefail

# This should do all steps for creating eks cluster (not APIC) described in
# README.md.

. ./scripts/envfile
echo "Starting script '$0' ($(date))."
echo "Prepared to create cluster '$CLUSTER_NAME' with $CLUSTER_NODES_NO node(s)."
echo "Please check if ./scripts/envfile is correctly configured."
echo "Press return to continue..."
read

echo "Creating cluster '$CLUSTER_NAME' with $CLUSTER_NODES_NO node(s)..."
eksctl create cluster \
--name $CLUSTER_NAME \
--version 1.14 \
--region eu-west-1 \
--nodegroup-name standard-workers \
--node-type t3a.2xlarge \
--nodes $CLUSTER_NODES_NO \
--nodes-min $CLUSTER_NODES_NO \
--nodes-max $CLUSTER_NODES_NO \
--ssh-access \
--ssh-public-key $NODE_KEY_PUB_PATH \
--managed

echo "Getting nodes public DNS names..."
NODES_DNS_NAMES=$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" --output json | jq -r '.Reservations[].Instances[].PublicDnsName')
echo "Nodes public DNS names: $NODES_DNS_NAMES"
echo ""

echo "Use following ssh commands to connect to nodes:"
for NODE in $NODES_DNS_NAMES; do
  echo ssh -i $NODE_KEY_PRIV_PATH ec2-user@$NODE
done
echo ""

# Save DNS name of the first node to install fakeSNT
NODE_EMAIL=""
MAIL_HOSTNAME=""

echo "Configuring vm.max_map_count (max virtual memory areas) settings for each node..."
for NODE in $NODES_DNS_NAMES; do
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE 'aws configure set region eu-west-1'
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE 'sudo sysctl vm.max_map_count'
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE 'echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf'
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE 'sudo sysctl -p'
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE 'sudo sysctl vm.max_map_count'
  if [[ -z "$NODE_EMAIL" ]]; then
    MAIL_HOSTNAME=$(ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE hostname)
    NODE_EMAIL="$NODE"
  fi
done
echo ""

echo "Configuring MailHog email server setup to listen on host '$MAIL_HOSTNAME' port 2525..."
if [[ -n "$NODE_EMAIL" ]]; then
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE_EMAIL curl -OL https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE_EMAIL chmod +x MailHog_linux_amd64
  ssh -oStrictHostKeyChecking=no -i $NODE_KEY_PRIV_PATH ec2-user@$NODE_EMAIL 'nohup ./MailHog_linux_amd64 -smtp-bind-addr ":2525" -storage "maildir" -jim-accept 1 -jim-disconnect 0 -maildir-path emails > MailHog.log 2>&1 &'
  echo "MailHog email server configured to listen on host '$MAIL_HOSTNAME' port 2525 ($NODE_EMAIL)."
else
  echo "ERROR: Can't set mail server, node not found! NODES_DNS_NAMES: [$NODES_DNS_NAMES]."
fi
echo ""

echo "Deploying metrics server..."
MS_RELEASE_JSON=$(curl -Ls "https://api.github.com/repos/kubernetes-sigs/metrics-server/releases/latest")
MS_URL=$(echo "$MS_RELEASE_JSON" | jq -r .tarball_url)
MS_VERSION=$(echo "$MS_RELEASE_JSON" | jq -r .tag_name)

if [[ ! -d "metrics-server-$MS_VERSION" ]]; then
  curl -L $MS_URL -o metrics-server-$MS_VERSION.tar.gz
  mkdir metrics-server-$MS_VERSION
  tar -xzf metrics-server-$MS_VERSION.tar.gz --directory metrics-server-$MS_VERSION --strip-components 1
fi
kubectl apply -f metrics-server-$MS_VERSION/deploy/1.8+/

sleep 2
echo "Verifying metrics server deployment..."
metrics_server_check_res=$(kubectl get deployment metrics-server -n kube-system)
while [[ -z "$metrics_server_check_res" ]]; do
  echo "Waiting metrics-server deployment..."
  sleep 2
  metrics_server_check_res=$(kubectl get deployment metrics-server -n kube-system)
done
echo "Metrics server successfully deployed:"
echo "$metrics_server_check_res"
echo ""

echo "Deploying k8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc2/aio/deploy/recommended.yaml
echo ""

echo "Verifying k8s dashboard deployment..."
k8s_dashboard_res=$(kubectl get deployment -n kubernetes-dashboard)
while [[ "$(echo "$k8s_dashboard_res" | (grep dashboard || true) | (grep "1/1" || true) | wc -l)" != "2" ]]; do
  echo "$k8s_dashboard_res"
  echo "Waiting k8s dashboard deployment..."
  sleep 2
  k8s_dashboard_res=$(kubectl get deployment -n kubernetes-dashboard)
done
echo "k8s dashboard successfully deployed:"
echo "$k8s_dashboard_res"
echo ""

echo "Creating EKS admin user service account..."
kubectl apply -f ./scripts/yaml/eks-admin-service-account.yaml
echo ""

echo "Preparing k8s for helm usage..."
kubectl apply -f ./scripts/yaml/rbac.yaml
helm init --service-account tiller
echo "Checking helm setup..."
helm_setup_res="$(helm ls 2>&1 || true)"
# empty result means success here
while [[ -n "$helm_setup_res" ]]; do
  echo "$helm_setup_res"
  echo "Waiting to setup helm..."
  sleep 2
  helm_setup_res="$(helm ls 2>&1 || true)"
done
echo ""

echo "Deploying nginx-ingress..."
helm install --name apic-eks-ingress stable/nginx-ingress -f ./scripts/yaml/nginx-ingress-values.yml
nginx_ingress_host="$(kubectl --namespace default get services apic-eks-ingress-nginx-ingress-controller -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>&1 || true)"
while [[ -z "$nginx_ingress_host" ]]; do
  echo "Waiting to setup nginx ingress external hostname..."
  echo "$(kubectl --namespace default get services apic-eks-ingress-nginx-ingress-controller)"
  sleep 2
  nginx_ingress_host="$(kubectl --namespace default get services apic-eks-ingress-nginx-ingress-controller -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>&1 || true)"
done
echo "nginx ingress service external hostname successfully setup:"
echo "$nginx_ingress_host"
echo ""

echo "Finding 1 IP address for nginx-ingress host, first wait 30 sec..."
sleep 30
ip_address_list="$(dig +short "$nginx_ingress_host")"
# Count a number of non-blank lines
ip_address_count="$(echo "$ip_address_list" | grep -cv '^\s*$' || true)"
while [[ "$ip_address_count" != "$CLUSTER_NODES_NO" ]]; do
  echo "Waiting for proper DNS addresses for '$nginx_ingress_host' (should be $CLUSTER_NODES_NO address(es), found $ip_address_count address(es)):"
  echo "ip_address_list: $ip_address_list"
  sleep 30
  ip_address_list="$(dig +short "$nginx_ingress_host")"
  ip_address_count="$(echo "$ip_address_list" | grep -cv '^\s*$' || true)"
done
echo "Selecting one of IP addresses for ingress ($nginx_ingress_host).."
nginx_ingress_ip=$(echo "$ip_address_list" | head -n1)
echo "Setting nip.ip hostnames in ./scripts/envfile to '$nginx_ingress_ip'"
sed -i -r "s/\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.nip.\io/.$nginx_ingress_ip.nip.io/" ./scripts/envfile
echo "Hostnames set."
echo ""

. ./scripts/envfile
echo "AWS EKS should be fully setup now and prepared for APIC installation :)"
echo ""
echo "Please use following URLs to connect to configure APIC:"
for hn in ep_cm ep_apim ep_gwd ep_gw ep_ac ep_padmin ep_portal; do
  echo "https://${!hn}"
done
echo ""

# Find running kubectl proxy (remove header line) and stop it if it is running
kubectl_proxy_proc_list=$(ps -fC "kubectl proxy" | grep -v STIME || true)
kubectl_proxy_proc_id=$(echo "$kubectl_proxy_proc_list" | awk '{print $2}')
if [[ -n "$kubectl_proxy_proc_id" ]]; then
  echo "Found 'kubectl proxy' running with PID $kubectl_proxy_proc_id, will kill it."
  kill -SIGHUP $kubectl_proxy_proc_id
fi

k8s_sec="$(kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}'))"

echo "k8s_sec: $k8s_sec"
echo "Use token from eks-admin account to login to dashboard web interface..."
echo "Browse to: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "Running proxy (in background) to enable usage of k8s dashboard."
kubectl proxy &
echo ""

. ./scripts/envfile
echo "Prepared to install APIC into EKS '$CLUSTER_NAME' with $CLUSTER_NODES_NO node(s)."
echo "  k8s namespace: '$NAMESPACE'."
echo "  APIC docker images directory: '$APIC_IMAGES_PATH'."
echo "  Key pair for SSH connections to nodes: '$NODE_KEY_PUB_PATH'/'$NODE_KEY_PRIV_PATH'."

echo "Preparing docker repos & images for APIC installation..."
bash ./scripts/create-repos.sh
echo ""

kubectl create ns apic

mkdir "$CLUSTER_NAME"
cd "$CLUSTER_NAME"

echo "Create dummy secret to avoid filling logs on nodes with warnings (*Unable to retrieve pull secret apic/dummy for*)..."
kubectl create secret -n apic generic dummy --from-literal=username= --from-literal=password=

apicup init

bash -x ../scripts/mgmt-out.sh
apicup subsys install mgmt --debug --plan-dir ./mgmt-out

bash -x ../scripts/gw-out.sh
apicup subsys install gw --debug --plan-dir ./gw-out

bash -x ../scripts/analytics-out.sh
apicup subsys install analytics --debug --plan-dir ./analytics-out

bash -x ../scripts/portal-out.sh
apicup subsys install portal --debug --plan-dir ./portal-out

echo ""
echo "Copy envfile with used values to eks workspace dir."
cp ../scripts/envfile ./
echo ""
echo "APIC installation complete :)"
echo ""
echo "Please use following URLs to connect to configure APIC:"
for hn in ep_cm ep_apim ep_gwd ep_gw ep_ac ep_padmin ep_portal; do
  echo "https://${!hn}"
done
echo ""
echo "Please use following ssh commands to connect to node(s):"
for NODE in $NODES_DNS_NAMES; do
  echo ssh -i $NODE_KEY_PRIV_PATH ec2-user@$NODE
done
echo ""


cluster_info_file="$CLUSTER_NAME.md"
echo "Writting ssh node connection & endpoints information to '$PWD/$cluster_info_file' file..."
echo "# Cluster '$CLUSTER_NAME' using '$CLUSTER_NODES_NO' node(s)" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "## SSH connections to nodes" >> $cluster_info_file
echo "" >> $cluster_info_file
for NODE in $NODES_DNS_NAMES; do
  echo ssh -i $NODE_KEY_PRIV_PATH ec2-user@$NODE >> $cluster_info_file
done
echo "" >> $cluster_info_file
echo "## APIC components" >> $cluster_info_file
echo "" >> $cluster_info_file
for hn in ep_cm ep_apim ep_gwd ep_gw ep_ac ep_padmin ep_portal; do
  echo "https://${!hn}" >> $cluster_info_file
done
echo "" >> $cluster_info_file
echo "(Initial cmc admin login/password: admin/7iron-hide)" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "## Kubernetes dashboard" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "run: kubectl -n kube-system describe secret \$(kubectl -n kube-system get secret | grep eks-admin | awk '{print \$1}')" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "k8s_sec: $k8s_sec" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "Use token from eks-admin account to login to dashboard web interface:" >> $cluster_info_file
echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" >> $cluster_info_file
echo "" >> $cluster_info_file
echo "Run proxy to enable access to k8s dashboard:" >> $cluster_info_file
echo "run: kubectl proxy" >> $cluster_info_file
echo "" >> $cluster_info_file
echo ""

# Wait for kubectl proxy command to finish - don+t just exit script.
#   On Ctrl+C send SIGHUP signal to kubectl proxy command and exit this script.
# [1]+ 12454 Running                 kubectl proxy &
kubectl_proxy_job_list=$(jobs -l | grep "kubectl proxy" || true)
kubectl_proxy_job_id=$(echo "$kubectl_proxy_job_list" | sed -n 's/.*+ //; s/ .*// p')
trap close_kubectl_proxy INT
function close_kubectl_proxy() {
  echo "** Trapped CTRL-C"
  kill -SIGHUP $kubectl_proxy_job_id
}

echo "Finished script '$0' ($(date))."

echo "k8s_sec: $k8s_sec"
echo "Use token from eks-admin account to login to dashboard web interface..."
echo "Waiting for kubectl proxy (PID: $kubectl_proxy_job_id) to finish, press Ctrl+C to stop it."
wait $kubectl_proxy_job_id
