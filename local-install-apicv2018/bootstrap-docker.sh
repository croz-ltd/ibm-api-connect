#!/usr/bin/env bash

if ! [ -x "$(command -v docker)" ]; then
	echo 'Installing docker'
	sudo add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update
	sudo apt-cache madison docker-ce
	sudo apt-get install -y --allow-unauthenticated docker-ce=18.06.3~ce~3-0~ubuntu containerd.io
	sudo groupadd docker
	sudo usermod -aG docker vagrant
	docker --version
	echo "Docker is installed"
fi
