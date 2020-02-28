#!/usr/bin/env bash

if ! [ -x "$(command -v MailHog_linux_amd64)" ]; then
	echo "Installing MailHog_linux_amd64"
	curl --silent -OL https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
	chmod +x MailHog_linux_amd64
	sudo mv MailHog_linux_amd64 /usr/local/bin
fi
