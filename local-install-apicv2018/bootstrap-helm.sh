#!/usr/bin/env bash

readonly HELM_FILE='helm-v2.16.1-linux-amd64.tar.gz '
if ! [ -x "$(command -v helm)" ]; then
  curl -OLk "https://get.helm.sh/${HELM_FILE}"
  tar xvfz "${HELM_FILE}"
 	cd linux-amd64/
	chmod +x helm
	mv helm /usr/local/bin/
	cd ..
	rm -f "${HELM_FILE}"
	rm -rf linux-amd64
fi