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

# Pushover token
# In oref0 versions 0.6.1 and earlier, if Pushover alerts are enabled, the
# Pushover username and API token are given as command-line arguments to
# oref0-pushover.sh by cron, and stored only in crontab.
# In newer versions, if pushover is enabled, the username and API token are
# instead stored in preferences.json.
if crontab -l |grep oref0-pushover >/dev/null; then
    if [[ $(get_pref_string .PUSHOVER_TOKEN missing) == missing ]]; then
        PUSHOVER_TOKEN="$(crontab -l |grep oref0-pushover |sed -e 's/.*oref0-pushover \([a-z0-9]*\).*/\1/')"
        PUSHOVER_USER="$(crontab -l |grep oref0-pushover |sed -e 's/.*oref0-pushover [a-z0-9]* \([a-z0-9]*\).*/\1/')"
        
        set_pref .PUSHOVER_TOKEN "\"${PUSHOVER_TOKEN}\""
        set_pref .PUSHOVER_USER "\"${PUSHOVER_USER}\""
    fi
fi
