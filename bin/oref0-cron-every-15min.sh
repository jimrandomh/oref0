#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self
Do all the things that oref0 does at 15-minute intervals. This should run from
cron, in the myopenaps directory.
EOT

assert_pwd_is_myopenaps

#if [[ "$ttyport" =~ "spidev5.1" ]]; then
if is_edison; then
    # proper shutdown once the EdisonVoltage very low (< 3050mV; 2950 is dead)
    sudo ~/src/EdisonVoltage/voltage json batteryVoltage battery \
        | jq .batteryVoltage \
        | awk '{if ($1<=3050)system("sudo shutdown -h now")}'
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
        --config-prefix=disk_critical \
        --priority=1 \
        --cooldown=60 \
        --cooldown-token=disk_critical
elif ((FREE_SPACE < DISK_WARN_THRESHOLD)); then
    oref0-send-notification \
        --title="Critically low disk space on $(hostname)" \
        --message="${FREE_SPACE}kb remaining." \
        --config-prefix=disk_warn \
        --priority=0 \
        --cooldown=720 \
        --coldown-token=disk_warn
fi

# Check uptime, Pushover notify if system has been up more than a configured
# duration. This alert defaults to disabled, and is intended for the use case
# where:
#   (1) you're using USB batteries, so the Edison can't see how charged # they are,
#   (2) you have two or more identical USB batteries,
#   (3) you always charge a battery fully before connecting your rig to it, and
#   (4) you have measured the battery life, and set the alert time to a number
#       of hours that the battery will definitely last for with margin for error

# Get uptime. Note that this has to use /proc/uptime, rather than uptime
# --since or anything like that, because on startup the clock will be incorrect.
TIME_SINCE_BOOT_SECS=$(cat /proc/uptime |cut -d ' ' -f 1)
UPTIME_WARN_HOURS="$(get_pref_float .uptime_warn_hours 12)"
if ((UPTIME_WARN_HOURS*3600 > TIME_SINCE_BOOT)); then
    oref0-send-notification \
        --title="Check rig battery" \
        --config-prefix=uptime_warn \
        --priority=1 \
        --disable-by-default \
        --cooldown=60 <<EOM
Rig has been running for $((TIME_SINCE_BOOT/3600)) hours which is longer than warning threshold of $UPTIME_WARN_HOURS hours; check battery charge and change if necessary.
EOM
fi

# Check for IP address changes
CURRENT_IP="$(ifconfig |grep 'inet addr' |awk '{print($2)}' |grep -v '127.0.0.1' |sed s/addr://)"
LAST_KNOWN_IP="$(cat /tmp/last_known_ip)"
if [[ "$CURRENT_IP" != "$LAST_KNOWN_IP" ]]; then
    echo "$CURRENT_IP" >/tmp/last_known_ip
    oref0-send-notification \
        --title="IP address changed" \
        --config-prefix=notify_ip_addr \
        --priority=-2 \
        --disable-by-default \
        --cooldown=5 <<EOM
Rig has a new IP address. Current IP address(es): $CURRENT_IP
EOM
fi
