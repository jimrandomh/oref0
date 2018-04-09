#!/bin/bash

source bin/oref0-bash-common-functions.sh

fail_test () {
    echo "$@" 1>&2
    exit 1
}

# Create a temp directory to run the test in
mkdir bash-unit-test-temp
(
    cd bash-unit-test-temp
    
    # Test that defaults are used when no config-file is present
    if ! check_pref_bool .noConfigFile true; then
        fail_test "Wrong result for check_pref_bool on a true default with no config file"
    fi
    if check_pref_bool .noConfigFile false; then
        fail_test "Wrong result for check_pref_bool on a false default with no config file"
    fi
    if [[ "$(get_pref_float .noConfigFile 5)" != 5 ]]; then
        fail_test "Wrong result for check_pref_float with no config file"
    fi
    if [[ "$(get_pref_string .noConfigFile "Hello")" != "Hello" ]]; then
        fail_test "Wrong result for check_pref_string with no config file"
    fi
    
    # Make a fake preferences.json to test the getters that extract values from it
    cat >preferences.json <<EOT
        {
            "bool_true": true,
            "bool_false": false,
            "number_5": 5,
            "number_3_5": 3.5,
            "string_hello": "hello"
        }
EOT

    # Test boolean getter
    if ! check_pref_bool .bool_true; then
        fail_test "Wrong result for check_pref_bool on a true value"
    fi
    if check_pref_bool .bool_false; then
        fail_test "Wrong result for check_pref_bool on a false value"
    fi
    if check_pref_bool .missing false; then
        fail_test "Wrong result for check_pref_bool on a missing value with default false"
    fi
    if check_pref_bool .missing; then
        fail_test "Wrong result for check_pref_bool on a missing value with implicit default"
    fi
    if ! check_pref_bool .missing true; then
        fail_test "Wrong result for check_pref_bool on a missing value with default true"
    fi
    
    # Test numeric getter
    if [ "$(get_pref_float .number_5)" -ne "5" ]; then
        fail_test "Wrong result for check_pref_float on a zero value"
    fi
    if [ "$(get_pref_float .number_3_5)" != "3.5" ]; then
        fail_test "Wrong result for check_pref_float on a non-integer value"
    fi
    if [ "$(get_pref_float .missing 123)" -ne 123 ]; then
        fail_test "Wrong result for check_pref_float on a missing value with default specified"
    fi
    if [ "$(get_pref_float .missing)" -ne 0 ]; then
        fail_test "Wrong result for check_pref_float on a missing value with default omitted"
    fi
    
    # Test string getter
    if [ "$(get_pref_string .string_hello)" != "hello" ]; then
        fail_test "Wrong result for check_pref_float on a string value"
    fi
    if [ "$(get_pref_string .missing stringDefault)" != "stringDefault" ]; then
        fail_test "Wrong result for check_pref_float on a missing value with default"
    fi
    
    # Test mutating a (non-empty) config file to add a new setting
    set_pref_json .mutated_pref 123
    if [ "$(get_pref_float .mutated_pref)" != 123 ]; then
        fail_test "set_pref_json didn't set a pref correctly"
    fi
    
    # Test mutating a config file to change an existing setting
    set_pref_json .mutated_pref 567
    if [ "$(get_pref_float .mutated_pref)" != 567 ]; then
        fail_test "set_pref_json didn't mutate a pref correctly"
    fi
    
    # Test mutating an (empty) config file
    rm -f preferences.json
    set_pref_json .empty_mutated_pref 123
    if [ "$(get_pref_float .empty_mutated_pref)" != 123 ]; then
        fail_test "set_pref_json didn't set a pref correctly when config file was empty"
    fi
    
    # Test mutating a config file, adding a quoted string
    set_pref_string .mutated_pref Hello
    if [ "$(get_pref_string .mutated_pref)" != "Hello" ]; then
        fail_test "set_pref_string didn't set a string pref correctly"
    fi
)

rm -f bash-unit-test-temp/preferences.json
rmdir bash-unit-test-temp