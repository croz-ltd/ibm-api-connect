echo --------
echo start MailHog
echo --------
nohup MailHog_linux_amd64 -smtp-bind-addr ":2525" -storage "maildir" -jim-accept 1 -jim-disconnect 0 -maildir-path /vagrant/fakesmtp/emails > /vagrant/fakesmtp/MailHog.log 2>&1 &
echo "MailHog email server setup to listen on host '$(hostname)' port 2525."
