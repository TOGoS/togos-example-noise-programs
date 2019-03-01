--[[
I'm going to define some custom elevation generators,
because elevation has the most dramatic effect
and is probably the most useful thing to customize:
water is placed anywhere elevation is less than zero,
and cliffs are placed along elevation contours.
]]--


--[[ Simplest possible elevation generator

For starters, let's define the simplest possible expression: one that just returns a constant value.

We'll add a 'named noise expression' prototype (`type = "noise-expression"`),
which wraps a raw noise expression to give it a name and some other metadata.

The expression itself has a type and other fields depending on the type.
To make an expression that always returns a constant number which we provide
directly `type = "literal-number"`, and `literal_value` = the numeric value we want to return.
]]--

data:extend{
  {
    type = "noise-expression",
    name = "constant-one-hundred",
    intended_property = "elevation",
    expression = {
      type = "literal-number",
      literal_value = 100
    }
  }
}

--[[
Setting intended_property = "elevation" makes this available in the
'Map type' / 'Elevation generator' drop-down on the map generator options screen
when you start a new game.

Without that, you'd still be able to create a game using this generator,
but you'd have to do it using a custom mapgensettings JSON file and
`--create` a save from the command-line.

We also need to add text to our words.cfg so that the dropdown shows nicely:

  [noise-expression]
  constant-one-hundred=One Hundred

Illustration: https://i.imgur.com/45vh6gk.png -- our "One Hundred" elevation generator appearing in the elevation ('Map type') drop-down

Illustration: https://i.imgur.com/sb3GMLN.png -- The result of our `elevation=100` generator.

]]--

--[[ Variables
Noise expressions used by the terrain generator are evaluated at every point on the map.
Therefore `x`, `y`, and `distance` variables are provided, which resolve to the x and y coordinate
and distance from the closest starting point.
(A few other variables are also provided, but we'll get into those later.)

Let's make a new elevation generator that just returns the value of `x`:
]]--

data:extend{
  {
    type = "noise-expression",
    name = "just-x",
    intended_property = "elevation",
    expression = {
      type = "variable",
      variable_name = "x"
    }
  }
}

--[[
Again, we'll add the name "just-x" to our words.cfg:

  [noise-expression]
  constant-one-hundred=One Hundred
  just-x=Just X

Hopefully we've got down that we need to add things to words.cfg, so I'm not going to mention it again.
At least not for noise expression name translations.

Restart factorio to reload the mod, select it from the list, and...

Illustration: https://i.imgur.com/gp2jiCd.png -- Just X

Pretty boring, huh?
But the water to the west (where `x < 0`) and lines of cliffs to the east
clearly show how `x`, `elevation`, water, and cliffs are related.
]]--

--[[ Arithmetic

We can apply functions to literal value and variable expressions
(as well as other function application expressions) to make more complex stuff happen.
A function-application expression has `type = "function-application"`,
a `function_name`, and a table (keyed by number or name, depending on the function)
of arguments.  Let's use the "add" function to add `x`, `y`, and a constant `100`:
]]--

data:extend{
  {
    type = "noise-expression",
    name = "x-plus-y",
    intended_property = "elevation",
    expression = {
      type = "function-application",
      function_name = "add",
      arguments = {
	{
	  type = "variable",
	  variable_name = "x"
	},
	{
	  type = "variable",
	  variable_name = "y"
	},
	{
	  type = "literal-number",
	  literal_value = 100
	}
      }
    }
  }
}

--[[
Illustration: https://i.imgur.com/ej5ekV9.png -- x + y + 100

As you can see, writing out noise expressions this way is already becoming cumbersome.
Fortunately there's a built-in Lua library to make things easier.

Let's import it:
]]--

local noise = require("noise")

--[[
There's a bunch of stuff in `noise`, but probably the most all-around useful function is
`define_noise_function`.  It lets us define noise expressions using mostly Lua syntax
as if we're defining a Fua function.  As its argument, it takes a function of `x`, `y`, tile properties, and map properties.

If we were to define that x-plus-y expression this way, it would look like this:
]]--

data:extend{
  {
    type = "noise-expression",
    name = "x-plus-y",
    intended_property = "elevation",
    expression = noise.define_noise_function(function(x, y, tile, map)
      return x + y + 100
    end)
  }
}

--[[
The `x` and `y` variables passed into our Lua function by `define_noise_function`
are `variable` noise expression tables like we used above, but with metatables associated with them
so that arithmetic operations work in a helpful way.
Using the `+` operator between two noise expressions results in an `add` function-application expression,
so you can, at least as far as basic arithmetic goes, pretend that you're just writing Lua code.

The other arithmetic operators that work on noise expressions are `+`, `-`, `*`, `/`, and `^` (exponentiate).

If you want to build your own noise expressions manually and be able to use those operators on them,
use the `to_noise_expression` function, usually aliased as `tne` locally:
]]--

local tne = noise.to_noise_expression

local the_variable_x = tne{
  type = "variable",
  variable_name = "x"
}
local the_variable_y = tne{
  type = "variable",
  variable_name = "y"
}

-- Yet another way to write our x-plus-y expression

data:extend{
  {
    type = "noise-expression",
    name = "x-plus-y",
    intended_property = "elevation",
    expression = the_variable_x + the_variable_y + tne(100)
  }
}

--[[ Clamping and ridging

Past basic arithmetic, maybe the second most fundamental functions
used in noise expressions are `clamp` and `ridge`.
They each take 3 arguments: a value to be modified, a lower limit, and an upper limit.

`clamp` returns the lower limit whenever the input value is lower than the lower limit,
and the upper limit whenever the input value is higher than the upper limit.

`ridge` also always returns a value between the lower and upper limits, but does so
by 'folding' the input back between them.  e.g. `ridge(6, 1, 5)` would return 4
(because the input, 6, is one greater than 5, so folding it back under 5 produces 4).
`ridge(-1, 1, 5)` would return 2, since the input is 2 below the lower limit.

We can make a map that's rings of land and water by just taking
the `distance` variable (which is made handy as `tile.distance` when using `define_noise_function`)
and ridging it between a negative and positive value:
]]--

data:extend{
  {
    type = "noise-expression",
    name = "rings",
    intended_property = "elevation",
    expression = noise.define_noise_function(function(x, y, tile, map)
      return noise.ridge(tile.distance, -20, 20)
    end)
  }
}

--[[
Giving us this beautiful thing:

Illustration: https://i.imgur.com/m5OsxaQ.png -- Rings!
]]--

--[[ Terrain segmentation and water level

If you mess with the "water scale" slider you'll notice that nothing changes.  Let's fix that!

For historical reasons, water scale inversely controls a variable called "segmentation multiplier".
When you set water scale to 600%, `segmentation_multiplier = 1/6`.

To have it make a nice effect on our rings map, we can just multiply `distance` by `segmentation_multiplier`
(which is provided to our `define_noise_function` callback as `map.segmentation_multiplier`)
and divide our function's output by it
(because if ridges are 6 times as wide, you'd expect them to be 6 times as tall, too, right?)
]]--

data:extend{
  {
    type = "noise-expression",
    name = "rings",
    intended_property = "elevation",
    expression = noise.define_noise_function(function(x, y, tile, map)
      return noise.ridge(tile.distance * map.segmentation_multiplier, -20, 20) / map.segmentation_multiplier
    end)
  }
}

--[[
Yay, now scale has an effect!

Illustration: https://i.imgur.com/rGCUeCZ.png -- tiny rings
Illustration: https://i.imgur.com/rGRqwXV.png -- wide rings

But water level still does nothing!

Water level doesn't actually change the level of the water.
Usually the way it is handled is by being subtracted from elevation.

There are a few map variables that are affected by the water level control:
`map.wlc_elevation_offset` ('water level correction offset') is a value that should
be added to our elevation to account for water level.
To accomodate the 'no water' case without dealing with infinities,
`map.wlc_elevation_minimum` provides a minimum value that our elevation should be clamped above.

We can define a function that takes our pre-corrected elevation and the `map` object to help us handle these:
]]--

local function water_level_correct(to_be_corrected, map)
  return noise.max(
    map.wlc_elevation_minimum,
    to_be_corrected + map.wlc_elevation_offset
  )
end

--[[
And use it for our rings generator:
]]--

data:extend{
  {
    type = "noise-expression",
    name = "rings",
    intended_property = "elevation",
    expression = noise.define_noise_function(function(x, y, tile, map)
      local raw_elevation = noise.ridge(tile.distance * map.segmentation_multiplier, -20, 20) / map.segmentation_multiplier
      return water_level_correct(raw_elevation, map)
    end)
  }
}

--[[
Illustration: https://i.imgur.com/J1QRIqt.gif -- Now water level works!
]]--

--[[ Ensuring a starting lake
Notice that 'only in starting area' does not actually make a starting area lake!
That's because our generator hasn't ensured that there is one.

We can use the `distance-from-nearest-point` function
(to which calls can be constructed using `noise.distance_from(x, y, point_list)`),
combined with the `starting_lake_positions` variable
(which evaluates to a list of starting lake positions automatically generated from MapGenSettings)
to get the distance to the nearest starting area lake.
We can then subtract our desired lake depth from that distance to get starting area lakes,
and take the minimum of that and our other function to ensure that there is always
a starting area lake, regardless of water level.
]]--

data:extend{
  {
    type = "noise-expression",
    name = "rings",
    intended_property = "elevation",
    expression = noise.define_noise_function(function(x, y, tile, map)
      local starting_lake_distance = noise.distance_from(x, y, noise.var("starting_lake_positions"))
      local starting_lake_bottom = starting_lake_distance - 10
      local raw_elevation = noise.ridge(tile.distance * map.segmentation_multiplier, -20, 20) / map.segmentation_multiplier
      local corrected = water_level_correct(raw_elevation, map)
      return noise.min(corrected, starting_lake_bottom)
    end)
  }
}

--[[
Illustration: https://i.imgur.com/P83fvDS.png -- Guaranteed starting lake!

It's not the most interesting lake, but there's guaranteed to be some water, now,
so players can definitely build some working steam boilers.
]]--

--[[ Basis noise

TODO: Write about what's going on, here.  Probably introduce the noise function by itself without all the goop around it first.

Also note that correcting water level and adding starting area lakes is such a common thing
that we should write a function that does all of that.

]]--

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
    intended_property = "elevation",
    expression = noise.define_noise_function( function(x,y,tile,map)
      reset_seed(map.seed)
      local the_noise = new_basis_noise(x, y, 8 / map.segmentation_multiplier, map.segmentation_multiplier / 32)
      local corrected = water_level_correct(the_noise, map)
      local starting_lake_distance = noise.distance_from(x, y, noise.var("starting_lake_positions"))
      local starting_lake_bottom = starting_lake_distance - 10
      return noise.min(corrected, starting_lake_bottom)
    end)
  },
}

--[[
Illustration: https://i.imgur.com/q9xJ48u.png
]]--
