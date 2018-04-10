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
    (
        cd $directory
        sudo ~/src/EdisonVoltage/voltage json batteryVoltage battery \
            | jq .batteryVoltage \
            | awk '{if ($1<=3050)system("sudo shutdown -h now")}'
    )
fi

# Get remaining free space (in kb). Whichever partition the log files are on
# is the one we check.
FREE_SPACE="$(df /var/log/openaps |tail -1 |awk '{print($4)}')"

# Default thresholds 50MB and 2MB for warning and critical alerts, respectively
DISK_WARN_THRESHOLD="$(get_pref_float .disk_warn_threshold 50000)"
DISK_CRITICAL_THRESHOLD="$(get_pref_float .disk_critical_threshold 2000)"

if ((FREE_SPACE < DISK_CRITICAL_THRESHOLD)); then
    oref0-send-notification \
        --title="Low disk space on $(hostname)" \
        --message="${FREE_SPACE}kb remaining." \
        --config-prefix=disk_warn \
        --priority=1 \
        --cooldown=60 \
        --cooldown-token=disk_critical
elif ((FREE_SPACE < DISK_WARN_THRESHOLD)); then
    oref0-send-notification \
        --title="Critically low disk space on $(hostname)" \
        --message="${FREE_SPACE}kb remaining." \
        --config-prefix=disk_critical \
        --priority=0 \
        --cooldown=720 \
        --coldown-token=disk_warn
fi
