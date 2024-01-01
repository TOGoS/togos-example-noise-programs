data = { }

setmetatable(data, { __index = {
	extend = function(self,stuff)
		for k,v in pairs(stuff) do
			self[k] = v
		end
	end
}})

require "data"

local function extract_named_noise_expressions(data)
	local nnes = {}
	for k, v in pairs(data) do
		if v.type == "noise-expression" then
			nnes[v.name] = v
		end
	end
	return nnes
end

local conv = require "conv"
local noise = require "noise"
local tne = noise.to_noise_expression

print(conv.to_json(extract_named_noise_expressions(data)))
