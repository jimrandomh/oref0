#!/bin/echo This file should be source'd from another script, not run directly:
#
# Common functions for shell script components of oref0.

# Set $self to the name the currently-executing script was run as. This is usually
# used in help messages.
self=$(basename $0)

PREFERENCES_FILE="preferences.json"


function overtemp {
    # check for CPU temperature above 85°C
    sensors -u 2>/dev/null | awk '$NF > 85' | grep input \
    && echo Edison is too hot: waiting for it to cool down at $(date)\
    && echo Please ensure rig is properly ventilated
}

function highload {
    # check whether system load average is high
    uptime | awk '$NF > 2' | grep load
}


die() {
    echo "$@"
    exit 1
}



# Takes a copy of the overall-program's arguments as arguments, and usage text
# as stdin. If the first argument is help, -h, or --help, print usage
# information and exit with status 0 (success). Otherwise, save the usage
# information in environment variable HELP_TEXT so it can be used by print_usage
# later.
#
# Correct invocation would look like:
#    usage "$@" <<EOT
#    Usage: $(basename $0) [--some-argument] [--some-other-argument]
#    Description of what this tool does. Information about what the arguments do.
#    EOT
usage () {
    case "$1" in
        help|-h|--help)
            cat -
            exit 0
            ;;
    esac
    export HELP_TEXT=$(cat -)
}

# Print the program's help text, as previously set by usage(). This would
# typically be used after detecting invalid arguments, and followed by "exit 1".
print_usage () {
    echo "$HELP_TEXT"
}

# Check that the current working directory is the myopenaps directory; if it
# isn't, print a message to stderr and exit with status 1 (failure). We assume
# we're in the right directory if there's a file named "openaps.ini" here.
assert_pwd_is_myopenaps () {
    if [[ ! -e "openaps.ini" ]]; then
        echo "$self: This script should be run from the myopenaps directory, but was run from $PWD which does not contain openaps.ini." 1>&2
        exit 1
    fi
}

# Usage: check_pref_bool <preference-name> <default-value>
# Check myopenaps/preferences.json for a setting matching preference-name. If
# present, return 0 (success) if it is truthy, or 1 (fail) if it is falsy. If
# not present, return 0 (success) if default-value is the string "true", or
# 1 (failure) if default-value is the string "false" or is omitted. If the
# preferences file doesn't exit, outputs default-value.
check_pref_bool () {
    if [[ -f "$PREFERENCES_FILE" ]]; then
        local PREFS="$(cat "$PREFERENCES_FILE")"
        RESULT=$(echo $PREFS |jq -e "$1")
        RETURN_CODE=$?
        if [[ "$RESULT" == "null" ]]; then
            if [[ "$2" == "true" ]]; then
                return 0
            else
                return 1
            fi
        else
            return $RETURN_CODE
        fi
    else
        if [[ "$2" == "true" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Usage: get_pref_float <preference-name> <default-value>
# Check myopenaps/preferences.json for a setting matching preference-name which
# is a float. If it's present and is a number, output it. If it's not present,
# output default-value. If it's present but is not a number, output an error to
# stderr and output default-value. If the preferences file doesn't exist,
# outputs default-value. If no value could be found and no default is provided,
# exits with status 1 and writes a message to stderr; otherwise exits with
# status 0.
get_pref_float () {
    if [[ -f "$PREFERENCES_FILE" ]]; then
        local PREFS="$(cat "$PREFERENCES_FILE")"
        RESULT=$(echo $PREFS |jq "$1")
        if [[ "$RESULT" == "null" ]]; then
            if [[ "$2" != "" ]]; then
                echo "$2"
                return 0
            else
                echo 0
                echo "Undefined preference setting and no default provided for $1" 1>&2
                return 1
            fi
        else
            echo "$RESULT"
            return 0
        fi
    else
        if [[ "$2" != "" ]]; then
            echo "$2"
            return 0
        else
            echo 0
            echo "No preferences file and no default provided for $1" 1>&2
            return 1
        fi
    fi
}

# Usage: get_pref_string <preference-name> <default-value>
# Check myopenaps/preferences.json for a setting matching preference-name which
# is a string. If it's present and is a string, output it (as its string value,
# without quotes or escaping). If it's not present, output default-value. If
# it's present but is not a string, output a warning to stderr, and a
# stringified version of its value to stdout. If the preferences file doesn't
# exist, outputs default-value.
get_pref_string () {
    if [[ -f "$PREFERENCES_FILE" ]]; then
        local PREFS="$(cat "$PREFERENCES_FILE")"
        RESULT=$(echo $PREFS |jq --exit-status --raw-output "$1")
        RETURN_CODE=$?
        
        if [[ $RETURN_CODE == 0 ]]; then
            echo "$RESULT"
        else
            echo "$2"
        fi
    else
        echo "$2"
    fi
}

# Usage: set_pref_json <preference-name> <new-value>
# Change the value of something in preferences.json. The preference-name is
# given as a jq selector, typically ".pref_name"; the value should be JSON,
# including quotes if it's a string. (For setting strings you probably want
# set_pref_string which handles the string-escaping.)
set_pref_json () {
    if [[ -f "$PREFERENCES_FILE" ]]; then
        local OLD_PREFS="$(cat "$PREFERENCES_FILE")"
        local NEW_PREFS="$(echo "$OLD_PREFS" |jq "$1 |= $2")"
    else
        local NEW_PREFS="$(echo '{}' |jq "$1 |= $2")"
    fi
    
    # Write the whole file and move into place, so that the change is atomic
    echo "$NEW_PREFS" >"${PREFERENCES_FILE}.new"
    mv "${PREFERENCES_FILE}.new" "$PREFERENCES_FILE"
}

# Usage: set_pref_string <preference-name> <string-value>
set_pref_string () {
    set_pref_json "$1" "\"$2\""
}
