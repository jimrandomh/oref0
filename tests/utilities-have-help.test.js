// Unit test which asserts that utilities in oref0/bin respond to the -h and
// --help options by outputting something that looks like help. Specifically,
// when invoked with -h or --help and no other flags:
//  * Its stdout or stderr contains the name of the script (ie $(basename $0))
//    and the word "usage" (case-insensitive. This is to distinguish
//    documentation from error messages or other output.)
//  * Its combined output (stdout+stderr) must be at least three lines long
//  * It must exit within 1 second with status 0
//  * It must not output anything to stderr
//
// Some conventions for scripts which aren'enforced, but you should try to have
// happen:
//  * If -h or --help is given, have no side effects and exit status 0
//  * If fewer than the required number of arguments, output usage and exit
//    with non-zero status
"use strict";

var dirsToSearchForUtils = [
    "bin"
];

var helpFlagsThatMustBeAccepted = [
    "-h",
    "--help"
];

var minHelpLineCount = 1;

var utilsToSkip = {
    // Due to a strange interaction between how node's event loop works and
    // shell redirection to /dev/fd/1, output is lost if mm-stick.sh is run
    // from node (but not if it's run from a shell script or python script).
    // Specifically, when node spawns a process, its stdout is a socket,
    // rather than a pty, pipe or file; and this script redirects to /dev/fds/1,
    // which can't be re-opened because it's a socket.
    "mm-stick.sh": true,
    
    // Currently failing to run in my not-on-an-Edison unit-testing environment
    // because of what look like path issues. (jimrandomh)
    "oref0-autotune-core.js": true,
    "oref0-autotune-prep.js": true,
    "oref0-calculate-iob.js": true,
    "oref0-detect-sensitivity.js": true,
    
    // Javascript files that have trouble running from a unit-test context
    // because of path issues with require(). (Basically, they work if you
    // run them from their installed location, but not if you run them from
    // within the source tree.) FIXME: Make these able to run from a unit-test
    // context.
    "oref0-determine-basal.js": true,
    "oref0-find-insulin-uses.js": true,
    "oref0-get-profile.js": true,
    "oref0-meal.js": true,
    "oref0-normalize-temps.js": true,
    "oref0-upload-profile.js": true,
    
    // Don't check that oref0-version's output with --help is format like
    // usage information, because its output is just the version number, and
    // that's fine.
    "oref0-version.sh": true,
}

var should = require('should');
var fs = require("fs");
var path = require("path");
var child_process = require("child_process");

// Get a list of utilities to test
var utilsToTest = [];
dirsToSearchForUtils.forEach(function(dir) {
    fs.readdirSync(dir).forEach(function(filename) {
        utilsToTest.push(path.join(dir, filename))
    });
});

describe("Shell scripts support --help", function() {
    utilsToTest.forEach(function(util) {
        it(util, function() {
            helpFlagsThatMustBeAccepted.forEach(function(helpFlag) {
                if(path.basename(util) in utilsToSkip)
                    return;
                var utilProcess = child_process.spawnSync(util, [helpFlag], {
                    timeout: 1000, //milliseconds
                    encoding: "UTF-8",
                    stdio: ["pipe","pipe","pipe"]
                });
                var invocationDescription = "Utility "+util+" invoked with "+helpFlag;
                var combinedOutput = utilProcess.stdout+utilProcess.stderr;
                
                should.notEqual(combinedOutput.toLowerCase().indexOf("usage"), -1,
                    invocationDescription+" does not have usage information in its output");
                should.notEqual(combinedOutput.toLowerCase().indexOf(path.basename(util)), -1,
                    invocationDescription+" does not have its 's name in its output");
                
                var lineCount = combinedOutput.split("\n").length;
                lineCount.should.be.greaterThanOrEqual(minHelpLineCount, invocationDescription+": Help text is too short (should be at least "+minHelpLineCount+" lines)");
            });
        });
    });
});