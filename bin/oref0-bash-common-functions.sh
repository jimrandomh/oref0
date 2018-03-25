#!/bin/echo This file should be source'd from another script, not run directly:
#
# Common functions for shell script components of oref0.

# Set $self to the name the currently-executing script was run as. This is usually
# used in help messages.
self=$(basename $0)


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
