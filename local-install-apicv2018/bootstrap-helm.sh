#!/usr/bin/env bash

if ! [ -x "$(command -v helm)" ]; then
  curl -OLk https://get.helm.sh/helm-v2.16.1-linux-amd64.tar.gz 
  tar xvfz helm-v2.16.1-linux-amd64.tar.gz
 	cd linux-amd64/
	chmod +x helm
	mv helm /usr/local/bin/
	cd ..
	rm -f helm-v2.16.1-linux-amd64.tar.gz
	rm -rf linux-amd64
fi