#!/bin/bash

source $(dirname $0)/oref0-bash-common-functions.sh || (echo "ERROR: Failed to run oref0-bash-common-functions.sh. Is oref0 correctly installed?"; exit 1)
set -eu

usage "$@" <<EOT
Usage: $self [--title=title] [--message=message] [--config-prefix=prefix] [--priority=-2..2] [--sound=sound] [--cooldown=15] [--cooldown-token=identifier]

  --title=<title>
    Title string for the alert. Any localization should be performed prior to
    passing it here.
    Default: "OpenAPS Alert"

  --message=<message>
    The body text of the alert. Any localization should be performed prior to
    passing it here. If omitted, stdin is read and used.

  --config-prefix=<string>
    Prefix for config-file settings related to this alert. If set, defining
    PREFIX_PRIORITY and PREFIX_COOLDOWN in preferences.json will set the alert
    priority and cooldown, and the priority and cooldown given as command-line
    flags will be taken as defaults and used only if the config settings are
    undefined.

  --priority=<number>
    The priority the alert will be sent at, from -2 (lowest) to 2 (highest).
    Priority levels are as defined in https://pushover.net/api#priority . May
    be overridden by preferences.json if a PREFIX_PRIORITY is defined.
    Default: 0 (normal priority; sound plays, no acknowledgement required,
    silenced during quiet hours).
    
  --sound=<sound>
    Name of the sound that will be played with the notification. If omitted,
    a default sound (configured on the Pushover client) will be used. May be
    overridden by preferences.json if PREFIX_SOUND is defined. For a list of
    possible sounds, see https://pushover.net/api#sounds .

  --cooldown=<minutes>
    If an alert with the same cooldown token has been sent this many minutes
    ago or less, don't send the alert again this time. If the user acknowledges
    the alert each time it appears, this will be the interval at which it
    repeats. (To make the alert repeat more frequently until acknowledged, use
    priority level 2.) May be overridden by preferences.json if PREFIX_COOLDOWN
    is defined.
    Default: 30

  --cooldown-token=<token>
    An identifier for the type of alert that this is. This should be an
    identifier in the traditional sense, ie a letter or underscore followed by
    zero or more letters, underscores or digits. If no cooldown token is given,
    but a config prefix is, the config prefix is used.
  
  --retry=<seconds>
    For emergency (priority=2) notifications only, specifies how often (in
    seconds) the Pushover servers will send the same notification to the user.
    In a situation where your user might be in a noisy environment or sleeping,
    retrying the notification (with sound and vibration) will help get his or
    her attention. This parameter must have a value of at least 30 seconds
    between retries. May be overridden by preferences.json if PREFIX_RETRY is
    defined.

  --expire=<seconds>
    For emergency (priority=2) notifications only, specifies how many seconds
    your notification will continue to be retried for (every retry seconds).
    If the notification has not been acknowledged in expire seconds, it will
    be marked as expired and will stop being sent to the user. Note that the
    notification is still shown to the user after it is expired, but it will
    not prompt the user for acknowledgement. This parameter must have a
    maximum value of at most 10800 seconds (3 hours). May be overridden by
    preferences.json if PREFIX_EXPIRE is defined.

Exit status:

    0 if the notification was sent or was skipped because of cooldown
    1 if the notification failed to send because of lack of internet accesss
      or some other problem.
EOT

assert_pwd_is_myopenaps

TITLE="OpenAPS Alert"
MESSAGE="-"
CONFIG_PREFIX=""
PRIORITY=0
SOUND="default"
COOLDOWN=30
COOLDOWN_TOKEN=""
RETRY=60
EXPIRE=600
ENABLED=true

for i in "$@"; do
  case "$i" in
    --title=*)
      TITLE="${i#*=}"
      ;;
    --message=*)
      MESSAGE="${i#*=}"
      ;;
    --config-prefix=*)
      CONFIG_PREFIX="${i#*=}"
      ;;
    --priority=*)
      PRIORITY="${i#*=}"
      ;;
    --sound=*)
      SOUND="${i#*=}"
      ;;
    --cooldown=*)
      COOLDOWN="${i#*=}"
      ;;
    --cooldown-token=*)
      COOLDOWN_TOKEN="${i#*=}"
      ;;
    --retry=*)
      RETRY="${i#*=}"
      ;;
    --expire=*)
      EXPIRE="${i#*=}"
      ;;
    --disable-by-default)
      ENABLED=false
      ;;
    *)
      echo "Unrecognized option: $i"
      exit 1
      ;;
  esac
done

PUSHOVER_TOKEN="$(get_pref_string .pushover_token)"
PUSHOVER_USER="$(get_pref_string .pushover_user)"

# If message is omitted, read from stdin
if [[ "$MESSAGE" == "-" ]]; then
    MESSAGE="$(cat)"
fi

# If a config prefix is present, check for config settings for priority and
# cooldown. If settings are present, they take precedence over those given in
# command-line options.
if [[ "$CONFIG_PREFIX" != "" ]]; then
    PRIORITY="$(get_pref_string .${CONFIG_PREFIX}_PRIORITY "$PRIORITY")"
    SOUND="$(get_pref_string .${CONFIG_PREFIX}_SOUND "$SOUND")"
    COOLDOWN="$(get_pref_float .${CONFIG_PREFIX}_COOLDOWN "$COOLDOWN")"
    RETRY="$(get_pref_float .${CONFIG_PREFIX}_RETRY "$RETRY")"
    EXPIRE="$(get_pref_float .${CONFIG_PREFIX}_EXPIRE "$EXPIRE")"
    ENABLED="$(get_pref_bool .${CONFIG_PREFIX}_ENABLED "$ENABLED")"
fi

if [[ "$ENABLED" == false ]]; then
    echo "Skipping notification because it is disabled by default"
    exit 0
fi

# If no cooldown token is given, but a config prefix is, the config prefix is
# used. If neither are given, there is no cooldown.
if [[ "$COOLDOWN_TOKEN" == "" ]]; then
    if [[ "$CONFIG_PREFIX" != "" ]]; then
        COOLDOWN_TOKEN="$CONFIG_PREFIX"
    fi
fi

# Check whether priority is an invalid value
if ((PRIORITY < -2)) || ((PRIORITY > 2)); then
    die "Invalid priority setting: $PRIORITY"
fi

# Check whether there's a cooldown lockfile that hasn't expired
COOLDOWN_LOCKFILES=./alert-cooldowns
COOLDOWN_FILE="$COOLDOWN_LOCKFILES/$COOLDOWN_TOKEN"
mkdir -p "$COOLDOWN_LOCKFILES"
if [[ "$COOLDOWN_TOKEN" != "" ]]; then
    if find "$COOLDOWN_LOCKFILES" -mmin "-$COOLDOWN" |grep -x "$COOLDOWN_FILE"; then
        echo "Skipping notification (a similar notification was sent recently)"
        exit 0
    fi
fi

if [ "$SOUND" = "default" ]; then
    SOUND_OPTION=""
else
    SOUND_OPTION="-F sound=$SOUND"
fi

if ((PRIORITY == 2)); then
    PRIORITY_OPTIONS="-F retry=$RETRY -F expire=$EXPIRE"
else
    PRIORITY_OPTIONS=""
fi

if curl -s \
    -F token="$PUSHOVER_TOKEN" \
    -F user="$PUSHOVER_USER" \
    $SOUND_OPTION \
    -F priority=$PRIORITY \
    $PRIORITY_OPTIONS \
    -F "title=$TITLE" \
    -F "message=$MESSAGE" \
    https://api.pushover.net/1/messages.json
then
    # If curl was successful, write a cooldown lockfile
    echo "Sent pushover notification"
    if [[ "$COOLDOWN_TOKEN" != "" ]]; then
        touch "$COOLDOWN_FILE"
    fi
    exit 0
else
    echo "Sending pushover notification failed"
    exit 1
fi

