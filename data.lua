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

data:extend{
  {
    type = "noise-expression",
    name = "straight-basis-noise",
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
}
