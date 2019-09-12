#!/bin/bash

self=$(basename $0)
function usage () {
    cat <<EOT
Usage: $self

Prompt for wifi credentials, attempt to connect, download the OpenAPS oref0
installer from github (master branch), and then run the next step of the
installer. If this all succeeds, installation continues in openaps-install.sh.

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
      ;;
    --oref0-branch=*)
      OREF0_BRANCH="${i#*=}"
      ;;
    *)
      echo "Unrecognized argument: $1"
      exit 1
      ;;
  esac
done

INSTALLER_URL="$(echo "$OREF0_GIT_URL" |sed -e "s/^git:\/\/github.com\/\(.*\).git$/https:\/\/raw.githubusercontent.com\/\1\/${OREF0_BRANCH}\/bin\/openaps-install.sh/")"

(
dmesg -D
echo Scanning for wifi networks:
ifup wlan0
wpa_cli scan
echo -e "\nStrongest networks found:"
wpa_cli scan_res | sort -grk 3 | head | awk -F '\t' '{print $NF}' | uniq
set -e
echo -e /"\nWARNING: this script will back up and remove all of your current wifi configs."
read -p "Press Ctrl-C to cancel, or press Enter to continue:" -r
echo -e "\nNOTE: Spaces in your network name or password are ok. Do not add quotes."
read -p "Enter your network name: " -r
SSID=$REPLY
read -p "Enter your network password: " -r
PSK=$REPLY
cd /etc/network
cp interfaces interfaces.$(date +%s).bak
echo -e "auto lo\niface lo inet loopback\n\nauto usb0\niface usb0 inet static\n  address 10.11.12.13\n  netmask 255.255.255.0\n\nauto wlan0\niface wlan0 inet dhcp\n  wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" > interfaces
echo -e "\n/etc/network/interfaces:\n"
cat interfaces
cd /etc/wpa_supplicant/
cp wpa_supplicant.conf wpa_supplicant.conf.$(date +%s).bak
echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nnetwork={\n  ssid=\"$SSID\"\n  psk=\"$PSK\"\n}" > wpa_supplicant.conf
echo -e "\n/etc/wpa_supplicant/wpa_supplicant.conf:\n"
cat wpa_supplicant.conf
echo -e "\nAttempting to bring up wlan0:\n"
ifdown wlan0; ifup wlan0
sleep 10
echo -ne "\nWifi SSID: "; iwgetid -r
sleep 5

curl "$INSTALLER_URL" > /tmp/openaps-install.sh
bash /tmp/openaps-install.sh "--oref0-git-url=$OREF0_GIT_URL" "--oref0-branch=$OREF0_BRANCH"
)
