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

local function assert_equals(expected, actual)
 	if expected ~= actual then
		error("Assertion failure; expected <<" .. expected .. ">> but got <<" .. actual .. ">>")
	end
end

local conv = require "conv"
local noise = require "noise"
local tne = noise.to_noise_expression

assert_equals('"foo"', conv.to_json("foo"))
assert_equals('123', conv.to_json(123))
assert_equals('[]', conv.to_json{})
assert_equals('{ "baz": "quux", "foo": "bar" }', conv.to_json{ foo = "bar", baz = "quux" })
assert_equals('{\n\t"baz": "quux",\n\t"foo": "bar"\n}', conv.to_json({ foo = "bar", baz = "quux" }, "\t"))

assert_equals('(-6 + x)', conv.to_factorio_2_noise_expression_string(tne(-6) + noise.var('x')))
assert_equals('(-6 / x)', conv.to_factorio_2_noise_expression_string(tne(-6) / noise.var('x')))

-- print(conv.to_json(extract_named_noise_expressions(data), "\t"))
