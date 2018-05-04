
var tz = require('moment-timezone');
var findMealInputs = require('./history');
var recentCarbs = require('./total');

function generate (inputs) {

  var treatments = findMealInputs(inputs);

  var opts = {
    treatments: treatments
  , profile: inputs.profile
  , pumphistory: inputs.history
  , glucose: inputs.glucose
  , basalprofile: inputs.basalprofile
  };

  var clock = new Date(tz(inputs.clock));

  var meal_data = recentCarbs(opts, clock);
  return meal_data;
}

exports = module.exports = generate;
