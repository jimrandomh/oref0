
var tz = require('moment-timezone');
var find_insulin = require('./history');
var calculate = require('./calculate');
var sum = require('./total');

function generate (inputs, currentIOBOnly, treatments) {

    if (!treatments) {
        var treatments = find_insulin(inputs);
        // calculate IOB based on continuous future zero temping as well
        var treatmentsWithZeroTemp = find_insulin(inputs, 240);
    } else {
        var treatmentsWithZeroTemp = [];
    }

    var opts = {
        treatments: treatments
    , profile: inputs.profile
    , calculate: calculate
    };
    if ( inputs.autosens ) {
        opts.autosens = inputs.autosens;
    }
    var optsWithZeroTemp = {
        treatments: treatmentsWithZeroTemp
    , profile: inputs.profile
    , calculate: calculate
    };

    var iobArray = [];
    if (! /(Z|[+-][0-2][0-9]:?[034][05])+/.test(inputs.clock) ) {
        console.error("Warning: clock input " + inputs.clock + " is unzoned; please pass clock-zoned.json instead");
    }
    var clock = new Date(tz(inputs.clock));

    var lastBolusTime = new Date(0).getTime(); //clock.getTime());
    var lastTemp = {};
    lastTemp.date = new Date(0).getTime(); //clock.getTime());
    treatments.forEach(function(treatment) {
        if (treatment.insulin && treatment.started_at) {
            lastBolusTime = Math.max(lastBolusTime,treatment.started_at);
        } else if (typeof(treatment.rate) === 'number' && treatment.duration ) {
            if ( treatment.date > lastTemp.date ) {
                lastTemp = treatment;
                lastTemp.duration = Math.round(lastTemp.duration*100)/100;
            }
        }
    });
    var iStop;
    if (currentIOBOnly) {
        // for COB calculation, we only need the zeroth element of iobArray
        iStop=1
    } else {
        // predict IOB out to 4h, regardless of DIA
        iStop=4*60;
    }
    for (i=0; i<iStop; i+=5){
        t = new Date(clock.getTime() + i*60000);
        var iob = sum(opts, t);
        var iobWithZeroTemp = sum(optsWithZeroTemp, t);
        iobArray.push(iob);
        iobArray[iobArray.length-1].iobWithZeroTemp = iobWithZeroTemp;
    }
    iobArray[0].lastBolusTime = lastBolusTime;
    iobArray[0].lastTemp = lastTemp;
    return iobArray;
}

exports = module.exports = generate;
