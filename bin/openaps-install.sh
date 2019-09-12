#!/bin/bash

set -e

self=$(basename $0)
function usage () {
    cat <<EOT
Usage: $self

OpenAPS installer. This is downloaded and executed by openaps-bootstrap.sh (but
you can run it directly). Interactively configures your rig's hostname, account
passwords, timezone, and log-file rotation. Then downloads and runs
openaps-packages.sh from GitHub (branch "dev"), checks out oref0 from GitHub
(master branch), and runs oref0-setup.sh to interactively configure pump and
CGM settings.

    --oref0-git-url=git://...
        (Optional) Specify an alternate source to download/install oref0 from,
        typically a github URL starting with git://. If you download from a
        source other than the default, make sure to read any documentation
        provided by that source. Be aware that versions of oref0 from alternate
        sources may be completely untested, and you should only use this flag
        if you are a software developer and know what you're doing.
        Default: git://github.com/openaps/oref0.git

    --oref0-branch=...
        (Optional) Specify a git branch to download/isntall oref0 from. This
        is intended for software developers, not end-users; branches other than
        the default are extremely experimental and likely to be broken in both
        obvious and subtle ways.
        Default: master
EOT
}

OREF0_GIT_URL="git://github.com/openaps/oref0.git"
OREF0_BRANCH="master"

for i in "$@"; do
  case "$i" in
    help|-h|--help)
      usage
      exit 0
      ;;
    --oref0-git-url=*)
      OREF0_GIT_URL="${i#*=}"
      shift
      ;;
    --oref0-branch=*)
      OREF0_BRANCH="${i#*=}"
      shift
      ;;
  esac
done

read -p "Enter your rig's new hostname (this will be your rig's "name" in the future, so make sure to write it down): " -r
myrighostname=$REPLY
echo $myrighostname > /etc/hostname
sed -r -i"" "s/localhost( jubilinux)?$/localhost $myrighostname/" /etc/hosts
sed -r -i"" "s/127.0.1.1.*$/127.0.1.1       $myrighostname/" /etc/hosts

# if passwords are old, force them to be changed at next login
passwd -S edison 2>/dev/null | grep 20[01][0-6] && passwd -e root
# automatically expire edison account if its password is not changed in 3 days
passwd -S edison 2>/dev/null | grep 20[01][0-6] && passwd -e edison -i 3

if [ -e /run/sshwarn ] ; then
    echo Please select a secure password for ssh logins to your rig:
    echo 'For the "root" account:'
    passwd root
    echo 'And for the "pi" account (same password is fine):'
    passwd pi
fi

grep "PermitRootLogin yes" /etc/ssh/sshd_config || echo "PermitRootLogin yes" > /etc/ssh/sshd_config

# set timezone
dpkg-reconfigure tzdata

#Workarounds for Jubilinux v0.2.0 (Debian Jessie) migration to LTS
if cat /etc/os-release | grep 'PRETTY_NAME="Debian GNU/Linux 8 (jessie)"' &> /dev/null; then
    #Disable validity check for archived Debian repos
    echo "Acquire::Check-Valid-Until false;" | tee -a /etc/apt/apt.conf.d/10-nocheckvalid
    #Replace apt sources.list with new archive.debian.org locations
    echo -e "deb http://security.debian.org/ jessie/updates main\n#deb-src http://security.debian.org/ jessie/updates main\n\ndeb http://archive.debian.org/debian/ jessie-backports main\n#deb-src http://archive.debian.org/debian/ jessie-backports main\n\ndeb http://archive.debian.org/debian/ jessie main contrib non-free\n#deb-src http://archive.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list
fi

#Workaround for Jubilinux to install nodejs/npm from nodesource
if getent passwd edison &> /dev/null; then
    #Use nodesource setup script to add nodesource repository to sources.list.d
    curl -sL https://deb.nodesource.com/setup_8.x | bash -
fi

#dpkg -P nodejs nodejs-dev
# TODO: remove the `-o Acquire::ForceIPv4=true` once Debian's mirrors work reliably over IPv6
apt-get -o Acquire::ForceIPv4=true update && apt-get -o Acquire::ForceIPv4=true -y dist-upgrade && apt-get -o Acquire::ForceIPv4=true -y autoremove
apt-get -o Acquire::ForceIPv4=true update && apt-get -o Acquire::ForceIPv4=true install -y sudo strace tcpdump screen acpid vim python-pip locate ntpdate git
#check if edison user exists before trying to add it to groups

if  getent passwd edison > /dev/null; then
  echo "Adding edison to sudo users"
  adduser edison sudo
  echo "Adding edison to dialout users"
  adduser edison dialout
 # else
  # echo "User edison does not exist. Apparently, you are runnning a non-edison setup."
fi

sed -i "s/daily/hourly/g" /etc/logrotate.conf
sed -i "s/#compress/compress/g" /etc/logrotate.conf

mkdir -p ~/src; cd ~/src && git clone "$OREF0_GIT_URL" || (cd oref0 && git checkout "$OREF0_BRANCH" && git pull)

~/src/bin/openaps-packages.sh

if [[ "$OREF0_BRANCH" == master ]]; then
  echo "Press Enter to run oref0-setup with the current release (master branch) of oref0,"
else
  echo "Press Enter to run oref0-setup with branch $OREF0_BRANCH of oref0,"
fi

read -p "or press ctrl-c to cancel. " -r
cd && ~/src/oref0/bin/oref0-setup.sh
