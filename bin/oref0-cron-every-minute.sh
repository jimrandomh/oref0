#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self
Do all the things oref0 does once per minute, based on config files. This
should run from cron, in the myopenaps directory. Effects include trying to
get a network connection, killing crashed processes, syncing data, setting temp
basals, giving SMBs, and everything else that oref0 does. Writes to various
different log files, should (mostly) not write to stdout.
EOT

assert_pwd_is_myopenaps

NIGHTSCOUT_HOST="$(get_pref_string .nightscout_host)"
API_SECRET="$(get_pref_string .nightscout_api_secret)"
CGM="$(get_pref_string .cgm)"
BT_PEB="$(get_pref_string .bt_peb)"
BT_MAC="$(get_pref_string .bt_mac)"
ENABLE="$(get_pref_string .enable)"
TTYPORT="$(get_pref_string .ttyport)"
PUSHOVER_TOKEN="$(get_pref_string .pushover_token)"
PUSHOVER_USER="$(get_pref_string .pushover_user)"
MYOPENAPS_DIR="$(get_pref_string .myopenaps_path)"
CGM_LOOP_DIR="$(get_pref_string .cgm_loop_path)"
XDRIPAPS_DIR="$(get_pref_string .xdrip_path)"

function is_process_running_named () {
    ps aux |grep -v grep |grep -q "$1"
    return $?
}

if ! is_process_running_named "oref0-online $BT_MAC"; then
    oref0-online "$BT_MAC" 2>&1 >>'/var/log/openaps/network.log' &
fi

sudo wpa_cli scan &

killall --quiet --process-group --older-than 30m openaps;
killall --quiet --process-group --older-than 30m oref0-pump-loop;
killall --quiet --process-group --older-than 30m openaps-report

# kill pump-loop after 5 minutes of not writing to pump-loop.log
find /var/log/openaps/pump-loop.log -mmin +5 | grep pump && (
    killall --quiet --process-group --older-than 5m openaps;
    killall --quiet --process-group --older-than 5m oref0-pump-loop;
    killall --quiet --process-group --older-than 5m openaps-report
)

if [[ ${CGM,,} =~ "g5-upload" ]]; then
    oref0-upload-entries &
fi
if [[ ${CGM,,} =~ "shareble" || ${CGM,,} =~ "g4-upload" ]]; then
    (
        if ! is_process_running_named 'openaps monitor-cgm'; then
            (
                cd $CGM_LOOP_DIR
                date;
                openaps monitor-cgm
            ) | tee -a /var/log/openaps/cgm-loop.log
        fi
        cp -up $CGM_LOOP_DIR/monitor/glucose-raw-merge.json cgm/glucose.json
        cp -up cgm/glucose.json monitor/glucose.json
    ) &
elif [[ ${CGM,,} =~ "xdrip" ]]; then
    if ! is_process_running_named "monitor-xdrip"; then
        monitor-xdrip | tee -a /var/log/openaps/xdrip-loop.log &
    fi
elif [[ $ENABLE =~ dexusb ]]; then
    true #no-op
elif ! [[ ${CGM,,} =~ "mdt" ]]; then # use nightscout for cgm
    if ! is_process_running_named "openaps get-bg"; then
        (
            date;
            openaps get-bg;
            # TODO: This might have the wrong number of backslashes now?
            cat cgm/glucose.json | jq -r  '.[] | \"\\(.sgv) \\(.dateString)\"' | head -1
        ) | tee -a /var/log/openaps/cgm-loop.log &
    fi
fi

if [[ ${CGM,,} =~ "xdrip" ]]; then # use old ns-loop for now
    if ! is_process_running_named 'openaps ns-loop'; then
        openaps ns-loop |tee -a /var/log/openaps/ns-loop.log &
    fi
else
    if ! is_process_running_named 'oref0-ns-loop'; then
        oref0-ns-loop | tee -a /var/log/openaps/ns-loop.log &
    fi
fi

if ! is_process_running_named oref0-autosens-loop; then
    oref0-autosens-loop 2>&1 | tee -a /var/log/openaps/autosens-loop.log &

fi

if [[ "$TTYPORT" =~ "spi" ]]; then
    oref0-radio-reboot &
fi

if ! is_process_running_named 'bin/oref0-pump-loop'; then
    oref0-pump-loop 2>&1 | tee -a /var/log/openaps/pump-loop.log &
fi

if [[ ! -z "$BT_PEB" ]]; then
    if ! is_process_running_named "peb-urchin-status $BT_PEB"; then
        peb-urchin-status $BT_PEB 2>&1 | tee -a /var/log/openaps/urchin-loop.log &
    fi
fi
if [[ ! -z "$BT_PEB" || ! -z "$BT_MAC" ]]; then
    if ! is_process_running_named "oref0-bluetoothup"; then
        oref0-bluetoothup >> /var/log/openaps/network.log &
    fi
fi

if [[ ! -z "$PUSHOVER_TOKEN" && ! -z "$PUSHOVER_USER" ]]; then
    # TODO: These args are getting refactored away
    oref0-pushover $PUSHOVER_TOKEN $PUSHOVER_USER 2>&1 >> /var/log/openaps/pushover.log &
fi

