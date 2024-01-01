data = {
	extend = function(self,stuff)
		for k,v in pairs(stuff) do
			self[k] = v
		end
	end
}

require "data"

local conv = require "conv"
local noise = require "noise"
local tne = noise.to_noise_expression

print(conv.to_json(tne(5)))
