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

local function test_f1_to_f2(f2str, f1expr, outer_precedence)
	if outer_precedence == nil then outer_precedence = 0 end
	assert_equals(f2str, conv.to_factorio_2_noise_expression_string(f1expr, outer_precedence))
end

-- Simple cases
test_f1_to_f2('6 + x', tne(6) + noise.var('x'))

-- Don't need to parenthesize negative numbers when used in + and - expressions
test_f1_to_f2('(-6 + x)', tne(-6) + noise.var('x'), 9999)
test_f1_to_f2('-6 + x', tne(-6) + noise.var('x'))

-- But do when outer precedence is higher:
test_f1_to_f2('(-6) / x', tne(-6) / noise.var('x'))
test_f1_to_f2('(-6) * x', tne(-6) * noise.var('x'))
test_f1_to_f2('(-3) ^ x', tne(-3) ^ noise.var('x'))

-- Homogeneous/associative/commutative arguments should be flattened
test_f1_to_f2('x + y + z', noise.var('x') + noise.var('y') + noise.var('z'))
test_f1_to_f2('x + (5 - y) + z', noise.var('x') + (5 - noise.var('y')) + noise.var('z'))

-- Non-associative/commutative operations don't flatten
test_f1_to_f2('(x - (5 + y)) - z', (noise.var('x') - (5 + noise.var('y'))) - noise.var('z'))
test_f1_to_f2('x - ((5 + y) - z)', noise.var('x') - ((5 + noise.var('y')) - noise.var('z')))

-- Don't need parens when inner operation has higher precedence:
test_f1_to_f2('x + y * z', noise.var('x') + (noise.var('y') * noise.var('z')))

-- But do need it otherwise:
test_f1_to_f2('(x + y) * z', (noise.var('x') + noise.var('y')) * noise.var('z'))

-- TODO: Test conversion of functions
-- referenced by resource_autoplace_all_patches example:
-- - [X] + - * / ^
-- - [ ] min / max
-- - [ ] spot_noise
-- - [ ] basis_noise
-- - [ ] random_penalty_between
-- Constants:
-- - [ ] pi

-- print(conv.to_json(extract_named_noise_expressions(data), "\t"))
