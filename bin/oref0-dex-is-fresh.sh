#!/bin/bash

self=$(basename $0)
function usage ( ) {
cat <<EOT
Usage: $self <glucose.json> <minutes>
Given a glucose log file, check whether the most recent sample is newer than
the given number of minutes (default 5). If it's fresh, exit with status 0;
otherwise exit with status 1. Either way, output a text description of how
recent the latest sample is.
EOT
}

case "$1" in
  --help|-h|help)
    usage
    exit 0
esac


GLUCOSE=$1

OLD=${2-5}
TIME_SINCE=$(oref0-dex-time-since $GLUCOSE)

if (( $(bc <<< "$TIME_SINCE >= $OLD") )); then
  echo "CGM Data $TIME_SINCE mins ago is old (>=$OLD)"
  exit 1
else
  echo "CGM Data $TIME_SINCE mins ago is fresh (< $OLD)"
  exit 0
fi

