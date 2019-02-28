local noise = require("noise")
local tne = noise.to_noise_expression

local seed0 = 1
local next_seed1 = 1

function reset_seed(seed0)
  seed0 = seed0
  next_seed1 = 1
end

function get_next_seed1()
  local s = next_seed1
  next_seed1 = s + 7
  return s
end

function new_basis_noise(x, y, output_scale, input_scale)
  output_scale = output_scale or 1
  input_scale = input_scale or 1 / output_scale
  seed1 = get_next_seed1()
  next_seed0 = next_seed1 + 1
  return {
    type = "function-application",
    function_name = "factorio-basis-noise",
    arguments = {
      x = tne(x),
      y = tne(y),
      seed0 = tne(seed0),
      seed1 = tne(seed1),
      input_scale = tne(input_scale),
      output_scale = tne(output_scale)
    }
  }
end

local function make_basis_noise_function(seed0,seed1,outscale0,inscale0)
  outscale0 = outscale0 or 1
  inscale0 = inscale0 or 1/outscale0
  return function(x,y,inscale,outscale)
    return tne
    {
      type = "function-application",
      function_name = "factorio-basis-noise",
      arguments =
      {
        x = tne(x),
        y = tne(y),
        seed0 = tne(seed0),
        seed1 = tne(seed1),
        input_scale = tne((inscale or 1) * inscale0),
        output_scale = tne((outscale or 1) * outscale0)
      }
    }
  end
end


local function multioctave_noise(params)
  local x = params.x or noise.var("x")
  local y = params.y or noise.var("y")
  local seed0 = params.seed0 or 1
  local seed1 = params.seed1 or 1
  local octave_count = params.octave_count or 1
  local octave0_output_scale = params.octave0_output_scale or 1
  local octave0_input_scale = params.octave0_input_scale or 1
  if params.persistence and params.octave_output_scale_multiplier then
    error("Both persistence and octave_output_scale_multiplier were provided to multioctave_noise, which makes no sense!")
  end
  local octave_output_scale_multiplier = params.octave_output_scale_multiplier or 2
  local octave_input_scale_multiplier = params.octave_input_scale_multiplier or 1/2
  local basis_noise_function = params.basis_noise_function or make_basis_noise_function(seed0, seed1)

  if params.persistence then
    octave_output_scale_multiplier = params.persistence
    -- invert everything so that we can multiply by persistence every time
    -- first octave is the largest instead of the smallest
    octave0_input_scale = octave0_input_scale * math.pow(octave_input_scale_multiplier, octave_count - 1)
    -- 'persistence' implies that the octaves would otherwise have been powers of 2, I think
    octave0_output_scale = octave0_output_scale * math.pow(2, octave_count - 1)
    octave_input_scale_multiplier = 1 / octave_input_scale_multiplier
  end


  return tne{
    type = "function-application",
    function_name = "factorio-quick-multioctave-noise",
    arguments =
    {
      x = tne(x),
      y = tne(y),
      seed0 = tne(seed0),
      seed1 = tne(seed1),
      input_scale = tne(octave0_input_scale),
      output_scale = tne(octave0_output_scale),
      octaves = tne(octave_count),
      octave_output_scale_multiplier = tne(octave_output_scale_multiplier),
      octave_input_scale_multiplier = tne(octave_input_scale_multiplier)
    }
  }
end

local standard_starting_lake_elevation_expression = noise.define_noise_function( function(x,y,tile,map)
  local starting_lake_distance = noise.distance_from(x, y, noise.var("starting_lake_positions"), 1024)
  local starting_lake_depth = 4
  local minimal_starting_lake_bottom = starting_lake_distance / 4 - starting_lake_depth
  local starting_lake_noise = multioctave_noise{
    x = x,
    y = y,
    seed0 = map.seed,
    seed1 = 14, -- CorePrototypes::elevationNoiseLayer->getID().getIndex()
    octave0_input_scale = 1/8,
    octave0_output_scale = 1/8,
    octave_count = 5,
    persistence = 0.75
  }
  return noise.min(
    minimal_starting_lake_bottom,
    starting_lake_distance / 8 - starting_lake_depth + starting_lake_noise
  )
end)

local function water_level_correct(to_be_corrected, map)
  return noise.max(
    map.wlc_elevation_minimum,
    to_be_corrected + map.wlc_elevation_offset
  )
end

local function water_level_correct_and_add_starting_lake(to_be_corrected, map)
  return noise.min(
    standard_starting_lake_elevation_expression,
    water_level_correct(to_be_corrected, map)
  )
end

data:extend{
  {
    type = "noise-expression",
    name = "straight-basis-noise",
    intended_property = "elevation",
    expression = noise.define_noise_function( function(x,y,tile,map)
      reset_seed(map.seed)
      -- TODO: divide 32 by map.segmentation_multiplier
      -- when compiler is able to handle complex constant expressions
      return new_basis_noise(x,y,32)
    end)
  },
  {
    type = "noise-expression",
    name = "terraced-basis-noise",
    intended_property = "elevation",
    expression = noise.define_noise_function( function(x,y,tile,map)
      reset_seed(map.seed)
      -- TODO: divide 32 by map.segmentation_multiplier
      -- when compiler is able to handle complex constant expressions
      local bn = new_basis_noise(x,y,16,1/64)
      -- We want the transitions in terrace strength to be sharp,
      -- because values between 0 and 1 result in crappy little chunks of cliffs,
      -- but not /too/ sharp, or the terracing strength transition will itself create cliffs!
      local ts = noise.clamp(new_basis_noise(x,y,2,1/64), 0, 1)
      return noise.terrace_for_cliffs(bn, ts, map)
    end)
  },
  {
    type = "noise-expression",
    name = "starting-area-webbing",
    intended_property = "elevation",
    expression = noise.define_noise_function( function(x,y,tile,map)
      local noise_input_scale = map.segmentation_multiplier
      reset_seed(map.seed)
      -- TODO: divide 32 by map.segmentation_multiplier
      -- when compiler is able to handle complex constant expressions
      local continents = new_basis_noise(x,y,16,1/(256*noise_input_scale))
      local webbing = noise.ridge(new_basis_noise(x,y,16,1/(64*noise_input_scale)), -math.huge, 16)
      local regular = noise.max(continents, webbing - tile.tier)
      -- We want the transitions in terrace strength to be sharp,
      -- because values between 0 and 1 result in crappy little chunks of cliffs,
      -- but not /too/ sharp, or the terracing strength transition will itself create cliffs!
      -- local ts = noise.clamp(new_basis_noise(x,y,4,1/64), -1, 0)
      return water_level_correct_and_add_starting_lake(regular, map)
    end)
  },
}

data.raw["map-gen-presets"]["default"]["webby"] = {
  type = "map-gen-preset",
  name = "webby",
  order = "b",
  basic_settings =
  {
    property_expression_names = {
      elevation = "starting-area-webbing"
    },
    autoplace_controls = {}
  }
}
