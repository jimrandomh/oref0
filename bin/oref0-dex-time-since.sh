#!/bin/bash

self=$(basename $0)
function usage ( ) {
cat <<EOT
Usage: $self <glucose.json>
Given a glucose log file, output the number of minutes it's been since the
latest sample.
EOT
}

case "$1" in
  --help|-h|help)
    usage
    exit 0
esac

GLUCOSE=$1

cat $GLUCOSE | json -e "this.minAgo=Math.round(100*(new Date()-new Date(this.dateString))/60/1000)/100" | json -a minAgo | head -n 1

