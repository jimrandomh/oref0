#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)

usage "$@" <<EOT
Usage: $self
Do all the things that oref0 does once per reboot, based on config files. This
should run from cron, in the myopenaps directory.
EOT

assert_pwd_is_myopenaps

CGM="$(get_pref_string .cgm)"
ENABLE="$(get_pref_string .enable)"
XDRIPAPS_DIR="$(get_pref_string .xdrip_path)"
TTYPORT="$(get_pref_string .ttyport)"


if [[ ${CGM,,} =~ "shareble" || ${CGM,,} =~ "g4-upload" ]]; then
    true #no-op
elif [[ ${CGM,,} =~ "xdrip" ]]; then
    python $HOME/.xDripAPS/xDripAPS.py &
elif [[ $ENABLE =~ dexusb ]]; then
    /usr/bin/python -u /usr/local/bin/oref0-dexusb-cgm-loop \
        >> /var/log/openaps/cgm-dexusb-loop.log 2>&1 &
fi

if [[ "$TTYPORT" =~ "spi" ]]; then
    reset_spi_serial.py &
fi

oref0-delete-future-entries

(
    cd ~/src/oref0/www && \
        export FLASK_APP=app.py && \
        flask run -p 80 --host=0.0.0.0 | tee -a /var/log/openaps/flask.log &
)