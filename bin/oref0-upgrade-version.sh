#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOF
Usage: $self
Check if any config files or crontab entries correspond to an older version of
oref0, and if so, update them. This script should be idempotent, ie, if you
run it when you didn't need to, or you run it a second time, then it does
nothing.
EOF

assert_pwd_is_myopenaps

# Usage: remove_from_crontab <regex>
# If the crontab contains a line where any part of the line matches the given
# regular expression, remove that line.
function remove_from_crontab () {
    (crontab -l |grep -v "$1") |crontab -
}

# Crontab cleanup
# In oref0 versions 0.6.1 and earlier, there were many cronjobs, which are now
# consolidated into oref0-cron-post-reboot, oref0-cron-every-minute,
# oref0-cron-every-15min, and oref0-cron-nightly.
function remove_0.6.1_jobs_from_crontab () {
    remove_from_crontab "sudo wpa_cli scan"
    remove_from_crontab "killall -g --older-than 30m openaps"
    remove_from_crontab "killall -g --older-than 5m openaps"
    remove_from_crontab "openaps monitor-cgm"
    remove_from_crontab "monitor-xdrip"
    remove_from_crontab ".xDripAPS/xDripAPS.py"
    remove_from_crontab "oref0-dexusb-cgm-loop"
    remove_from_crontab "openaps get-bg"
    remove_from_crontab "openaps ns-loop"
    remove_from_crontab "oref0-ns-loop"
    remove_from_crontab "oref0-autosens-loop"
    remove_from_crontab "oref0-autotune"
    remove_from_crontab "reset_spi_serial.py"
    remove_from_crontab "oref0-radio-reboot"
    remove_from_crontab "peb-urchin-status"
    remove_from_crontab "oref0-bluetoothup"
    remove_from_crontab "EdisonVoltage"
    remove_from_crontab "oref0-delete-future-entries"
    remove_from_crontab "oref0-pushover"
    remove_from_crontab "oref0-version"
    remove_from_crontab "flask run"
}

remove_0.6.1_jobs_from_crontab
