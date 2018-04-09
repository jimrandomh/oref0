#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self
Do all the things that oref0 does at 15-minute intervals. This should run from
cron, in the myopenaps directory.
EOT

assert_pwd_is_myopenaps

#if [[ "$ttyport" =~ "spidev5.1" ]]; then
if egrep -i "edison" /etc/passwd 2>/dev/null; then
   # proper shutdown once the EdisonVoltage very low (< 3050mV; 2950 is dead)
    cd $directory
    sudo ~/src/EdisonVoltage/voltage json batteryVoltage battery \
        | jq .batteryVoltage \
        | awk '{if (\$1<=3050)system(\"sudo shutdown -h now\")}'
fi
