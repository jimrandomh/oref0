#!/bin/bash

self=$(basename $0)
function usage () {
cat <<EOT
Usage: $self
Attempt to establish a Bluetooth tethering connection.
EOT
}

case "$1" in
  --help|-h|help)
    usage
    exit 0
esac
# start bluetoothd if bluetoothd is not running
if ! ( ps -fC bluetoothd ) ; then
   sudo /usr/local/bin/bluetoothd &
fi

if getent passwd edison && ! ( hciconfig -a | grep -q "PSCAN" ) ; then
   sudo killall bluetoothd
   sudo /usr/local/bin/bluetoothd &
fi

if ( hciconfig -a | grep -q "DOWN" ) ; then
   sudo hciconfig hci0 up
   sudo /usr/local/bin/bluetoothd &
fi

if !( hciconfig -a | grep -q $HOSTNAME ) ; then
   sudo hciconfig hci0 name $HOSTNAME
fi
