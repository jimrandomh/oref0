#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self

Downloads OpenAPS packages using pip, and dependencies using apt-get and npm.
This is normally invoked from openaps-install.sh.
EOT

# TODO: remove the `-o Acquire::ForceIPv4=true` once Debian's mirrors work reliably over IPv6
apt-get -o Acquire::ForceIPv4=true install -y sudo
sudo apt-get -o Acquire::ForceIPv4=true update && sudo apt-get -o Acquire::ForceIPv4=true -y upgrade
sudo apt-get -o Acquire::ForceIPv4=true install -y git python python-dev software-properties-common python-numpy python-pip nodejs-legacy npm watchdog strace tcpdump screen acpid vim locate jq lm-sensors && \
sudo pip install -U openaps && \
sudo pip install -U openaps-contrib && \
sudo openaps-install-udev-rules && \
sudo activate-global-python-argcomplete && \
sudo npm install -g json oref0 && \
echo openaps installed && \
openaps --version


