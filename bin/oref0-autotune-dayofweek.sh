#!/bin/bash

# This script allows you to run autotune separately for each day of the week

[ -z "$OPENAPS_DIR" ] && OPENAPS_DIR="$1"
myopenaps="$OPENAPS_DIR"
nsurl=$2
DOW=$(date +%u)

if [ -z $myopenaps ] || [ -z $nsurl ]; then
  echo "Usage: $0 ~/myopenaps http://mynightscouthost.herokuapp.com"
  echo "If you have day-of-the-week autotune profiles named like"
  echo '"myopenaps/autotune/profile-day0.json", copies the profile for whichever day'
  echo "today is to myopenaps/autotune/profile.json and reruns autotune. Day 0 is"
  echo "Sunday, day 1 is Monday, etc."
  echo
  echo "This script is not used up by a default install."
  exit
fi

# if we have a day of week profile file, copy that over before autotuning
if [ -e $myopenaps/autotune/profile-day$DOW.json ]; then
  cp $myopenaps/autotune/profile-day$DOW.json $myopenaps/autotune/profile.json
fi

# do the regular autotune and update autotune.json, and then 
# copy the updated profile.json back to the day of week profile file
oref0-autotune -d=$myopenaps -n=$nsurl \
&& cat $myopenaps/autotune/profile.json | json | grep -q start \
&& cp $myopenaps/autotune/profile.json $myopenaps/settings/autotune.json \
&& cp $myopenaps/autotune/profile.json $myopenaps/autotune/profile-day$DOW.json
