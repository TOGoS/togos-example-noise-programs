-- The 'noise' library from Factorio core is not strictly necessary for
-- constructing noise programs, but it makes it a lot easier, so let's import it:
local noise = require("noise")

-- 'tne' is the idiomatic alias for the 'to noise expression' function:
local tne = noise.to_noise_expression

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

https://i.imgur.com/45vh6gk.png -- our "One Hundred" elevation generator appearing in the elevation ('Map type') drop-down

https://i.imgur.com/sb3GMLN.png -- The result of our `elevation=100` generator.

]]--

--[[ Variables

Noise expressions used by the terrain generator are evaluated at every point on the map.
Therefore `x`, `y`, and `distance` variables are provided, which resolve to the x and y coordinate
and distance from the closest starting point.

Let's make a new elevation generator that just returns the value of `x`.
The expressionw will be of 

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

Restart factorio to reload the mod, select it from the list, and...

https://i.imgur.com/gp2jiCd.png -- Just X

Pretty boring, huh?
But the water to the west (where `x < 0`) and lines of cliffs to the east
clearly show how `x`, `elevation`, water, and cliffs are related.

]]--
