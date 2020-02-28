#!/usr/bin/env bash

TZ="Europe/Zagreb"
echo $TZ > /etc/timezone
apt-get update && apt-get install -y tzdata
rm /etc/localtime
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
apt-get clean