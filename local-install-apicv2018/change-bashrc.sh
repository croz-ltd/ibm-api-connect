#!/usr/bin/env bash

token=$(cat <<'END_HEREDOC'
function dashboard() {
	local -r token=$(kubectl -n kube-system describe secret \
		$(kubectl -n kube-system get secret | awk '/^admin-user-token-/{print $1}') \
		| awk '$1=="token:"{print $2}')
	echo -e "Access Dashboard by opening http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy and login using token: \n$token"
	kubectl proxy --address 0.0.0.0 --accept-hosts '.*'
}
END_HEREDOC
)

dpui=$(cat <<'END_HEREDOC'
function dpui() {
	echo "Run in ssh following: 'socat tcp-listen:9090,bind=10.0.0.100,reuseaddr,fork tcp:localhost:9090'"
	kubectl port-forward $(kubectl get pods -n apic | grep gateway | awk '{print $1;}') 9090:9090 -n apic
}
END_HEREDOC
)

echo "$token" 						| sudo tee -a /home/vagrant/.bashrc
echo "$dpui" 							| sudo tee -a /home/vagrant/.bashrc