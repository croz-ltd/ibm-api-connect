#!/usr/bin/env bash

sudo docker load -i /vagrant/apic/idg_dk2018*
if [[ -z $GTW_IMAGE_TAG ]]; then
	echo "export GTW_IMAGE_TAG=$(sudo docker images | grep -e '^ibmcom/datapower' | awk '{print $2}')" | tee -a envfile
fi
sudo docker load -i /vagrant/apic/dpm20184*
if [[ -z $DPM_IMAGE_TAG ]]; then
	echo "export DPM_IMAGE_TAG=$(sudo docker images | grep -e '^ibmcom/k8s-datapower-monitor' | awk '{print $2}')" | tee -a envfile
fi
