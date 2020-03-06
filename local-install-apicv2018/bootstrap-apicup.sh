#!/usr/bin/env bash

apicFile=/vagrant/apic/apicup-linux_lts_v2018.4.1*
if ! [ -x "$(command -v apicup)" ] && [ -f $apicFile ]; then
	copyTo=/home/vagrant/apicup
	cp $apicFile $copyTo
	chmod +x $copyTo
	sudo mv $copyTo /usr/local/bin
	yes Y | apicup version
fi
