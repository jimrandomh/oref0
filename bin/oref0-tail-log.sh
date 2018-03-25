#!/bin/bash

self=$(basename $0)
function usage ( ) {
cat <<EOF
Usage: $self
Monitors /var/log/openaps/pump-loop.log
EOF
}
case "$1" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac


tail -n 100 -F /var/log/openaps/pump-loop.log
