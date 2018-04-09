#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self
Do all the things that oref0 does once per night, based on config files.
Currently this just means autotune. This should run from cron, in the
myopenaps directory. By default, this happens at 4:05am every night.
EOT

assert_pwd_is_myopenaps

MYOPENAPS_DIR="$(get_pref_string .myopenaps_path)"
ENABLE="$(get_pref_string .enable)"
NIGHTSCOUT_HOST="$(get_pref_string .nightscout_host)"

if [[ $ENABLE =~ autotune ]]; then
    # autotune nightly at 4:05am using data from NS
    (
        oref0-autotune -d=$MYOPENAPS_DIR -n=$NIGHTSCOUT_HOST && \
            cat $MYOPENAPS_DIR/autotune/profile.json | jq . | grep -q start && \
            cp $MYOPENAPS_DIR/autotune/profile.json $MYOPENAPS_DIR/settings/autotune.json
    ) 2>&1 | tee -a /var/log/openaps/autotune.log &
fi

# NOTE: Changed from hourly to nightly
oref0-version --check-for-updates > /tmp/oref0-updates.txt &
