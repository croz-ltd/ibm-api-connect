include envfile

loadGW:
	bash bin/load-gateway.sh

k8s:
	sh bin/k8s.sh

helm:
	kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
	helm init
	echo "Waiting for tiller to start in cluster"
	bash bin/sleep.sh 120

ingress:
	helm install --name ingress -f yaml/nginx-ingress-values.yml stable/nginx-ingress

storage:
	kubectl create -f yaml/storage-rbac.yml
	kubectl create -f yaml/hostpath-provisioner.yml

registry:
	helm install --name registry stable/docker-registry  -f yaml/docker-registry-values.yaml
	echo "Waiting for docker registry to start"
	bash bin/sleep.sh 60

upload:
	sudo docker login $(registry) -u admin -p admin
	sudo apicup registry-upload management /vagrant/apic/management-images* $(registry)
	sudo apicup registry-upload analytics /vagrant/apic/analytics-images* $(registry)
	sudo apicup registry-upload portal /vagrant/apic/portal-images* $(registry)
	sudo docker tag "ibmcom/datapower:${GTW_IMAGE_TAG}" "${registry}/ibmcom/datapower:${GTW_IMAGE_TAG}"
	sudo docker push "${registry}/ibmcom/datapower:${GTW_IMAGE_TAG}"
	sudo docker tag "ibmcom/k8s-datapower-monitor:${DPM_IMAGE_TAG}" "${registry}/ibmcom/k8s-datapower-monitor:${DPM_IMAGE_TAG}"
	sudo docker push "${registry}/ibmcom/k8s-datapower-monitor:${DPM_IMAGE_TAG}"

smtp:
	sh bin/fakesmtp.sh

prep: k8s helm ingress storage registry upload

checkReady:
	until kubectl get nodes | grep Ready; do printf 'Waiting for network';sleep 15;done

buildYaml:
	rm -rf myinstall || true
	kubectl create ns $(NAMESPACE) || true
	apicup init myinstall
	cd ./myinstall ; apicup subsys create mgmt management --k8s ;
	cd ./myinstall ; apicup subsys set mgmt registry $(registry) ;	
	cd ./myinstall ; apicup subsys set mgmt platform-api   $(ep_api) ;
	cd ./myinstall ; apicup subsys set mgmt api-manager-ui $(ep_apim)  ;
	cd ./myinstall ; apicup subsys set mgmt cloud-admin-ui $(ep_cm)  ;
	cd ./myinstall ; apicup subsys set mgmt consumer-api $(ep_consumer) ;
	cd ./myinstall ; apicup subsys set mgmt storage-class velox-block;
	cd ./myinstall ; apicup subsys set mgmt namespace $(NAMESPACE) ;
	cd ./myinstall ; apicup subsys set mgmt cassandra-cluster-size 1 ;
	cd ./myinstall ; apicup subsys set mgmt cassandra-max-memory-gb 4 ;
	cd ./myinstall ; apicup subsys set mgmt cassandra-volume-size-gb 5 ;
	cd ./myinstall ; apicup subsys set mgmt create-crd true ;

	cd ./myinstall ; apicup subsys create gw gateway --k8s ;
	cd ./myinstall ; apicup subsys set gw api-gateway $(ep_gw)
	cd ./myinstall ; apicup subsys set gw apic-gw-service $(ep_gwd)
	cd ./myinstall ; apicup subsys set gw namespace $(NAMESPACE) ;
	cd ./myinstall ; apicup subsys set gw max-cpu 4 ;
	cd ./myinstall ; apicup subsys set gw max-memory-gb 8 ;
	cd ./myinstall ; apicup subsys set gw storage-class velox-block;
	cd ./myinstall ; apicup subsys set gw replica-count 1 ;
	cd ./myinstall ; apicup subsys set gw v5-compatibility-mode false ;
	cd ./myinstall ; apicup subsys set gw enable-tms true ;
	cd ./myinstall ; apicup subsys set gw extra-values-file /vagrant/scripts/yaml/extra-values.yaml ;
	cd ./myinstall ; apicup subsys set gw image-repository "${registry}/ibmcom/datapower" ;
	cd ./myinstall ; apicup subsys set gw image-tag "${GTW_IMAGE_TAG}" ;
	cd ./myinstall ; apicup subsys set gw monitor-image-repository "${registry}/ibmcom/k8s-datapower-monitor" ;
	cd ./myinstall ; apicup subsys set gw monitor-image-tag "${DPM_IMAGE_TAG}" ;
	cd ./myinstall ; apicup subsys set gw enable-tms true;
	cd ./myinstall ; apicup subsys set gw tms-peering-storage-size-gb 10;
	cd ./myinstall ; apicup subsys set gw enable-high-performance-peering true;

	cd ./myinstall ; apicup subsys create analytics analytics --k8s ;
	cd ./myinstall ; apicup subsys set analytics registry $(registry) ;
	cd ./myinstall ; apicup subsys set analytics namespace $(NAMESPACE) ;
	cd ./myinstall ; apicup subsys set analytics coordinating-max-memory-gb 6 ;
	cd ./myinstall ; apicup subsys set analytics data-max-memory-gb 8 ;
	cd ./myinstall ; apicup subsys set analytics data-storage-size-gb 200 ;
	cd ./myinstall ; apicup subsys set analytics master-max-memory-gb 6 ;
	cd ./myinstall ; apicup subsys set analytics master-storage-size-gb 5 ;
	cd ./myinstall ; apicup subsys set analytics storage-class velox-block;
	cd ./myinstall ; apicup subsys set analytics analytics-ingestion $(ep_ai) ;
	cd ./myinstall ; apicup subsys set analytics analytics-client $(ep_ac) ;

	cd ./myinstall ; apicup subsys create portal portal --k8s ;
	cd ./myinstall ; apicup subsys set portal registry $(registry) ;
	cd ./myinstall ; apicup subsys set portal portal-admin $(ep_padmin) ;
	cd ./myinstall ; apicup subsys set portal portal-www $(ep_portal) ;
	cd ./myinstall ; apicup subsys set portal namespace $(NAMESPACE) ;
	cd ./myinstall ; apicup subsys set portal storage-class velox-block;
	cd ./myinstall ; apicup subsys set portal www-storage-size-gb 5
	cd ./myinstall ; apicup subsys set portal backup-storage-size-gb 5
	cd ./myinstall ; apicup subsys set portal db-storage-size-gb 12
	cd ./myinstall ; apicup subsys set portal db-logs-storage-size-gb 2
	cd ./myinstall ; apicup subsys set portal admin-storage-size-gb 1
	
	cd ./myinstall ; apicup subsys set gw mode dev ;
	cd ./myinstall ; apicup subsys set mgmt mode dev ;
	cd ./myinstall ; apicup subsys set portal mode dev ;
	cd ./myinstall ; apicup subsys set analytics mode dev ;

deployPortal:
	cd myinstall  ; apicup subsys install portal
deployMgmt:
	cd myinstall  ; apicup subsys install mgmt ;
deployGW:
	cd myinstall  ; apicup subsys install gw
	kubectl patch sts r5673b1bbde-dynamic-gateway-service -n $(NAMESPACE) --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value":"2"}, {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"1Gi"}]'
deployAnalytics:
	cd myinstall  ; apicup subsys install analytics
deploy: deployMgmt deployGW deployAnalytics deployPortal

configureAPIC:
	sh bin/changepassword.sh $(ep_cm) $(admin_email) $(admin_pass)
	sh envfile && sh bin/createDpService.sh

all: prep  work
work: checkReady smtp buildYaml deploy configureAPIC dashboard

dashboard:
	helm install --name metrics-server stable/metrics-server --namespace metrics --set args={"--kubelet-insecure-tls=true,--kubelet-preferred-address-types=InternalIP\,Hostname\,ExternalIP"}
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc3/aio/deploy/recommended.yaml
	kubectl create -f yaml/admin-user.yaml
	echo "Install has successfully completed. Open your browser at https://"$(ep_cm)" and login with user 'admin' and password '${admin_pass}'"
