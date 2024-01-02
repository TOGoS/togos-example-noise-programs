function json_escape_string_chars(str)
	return str:gsub('[%z\1-\31\\"]', function(chr)
		if chr == "\\" then
			return "\\\\"
		elseif chr == '"' then
			return '\\"'
		elseif chr == "\b" then
			return "\\b"
		elseif chr == "\f" then
			return "\\f"
		elseif chr == "\n" then
			return "\\n"
		elseif chr == "\r" then
			return "\\r"
		elseif chr == "\t" then
			return "\\t"
		else
			return string.format('\\u%04x', string.byte(char))
		end
	end)
end

function is_list(tab)
	local nexti = 1
	for k, v in pairs(tab) do
		if k == nexti then
			nexti = nexti + 1
		else
			return false
		end
	end
	return true
end

local function sorted_pairs(tab)
	local keys = {}
	for k, v in pairs(tab) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local count = #keys
	for _, k in ipairs(keys) do
		local i = 0
		return function() 
			i = i + 1
			if i <= count then return keys[i], tab[keys[i]] end
		end
	end
end

function to_json(thing, indent_delta, lsep, indent)
	local typ = type(thing)
	if indent_delta == nil then indent_delta = "" end
	if lsep == nil then
		if indent_delta == "" then
			lsep = " "
		else
			lsep = "\n"
		end
	end
	if indent == nil then indent = "" end
	
	if typ == "nil" then
		return "null"
	elseif typ == "string" then
		return '"' .. json_escape_string_chars(thing) .. '"'
	elseif typ == "number" or typ == "boolean" then
		return tostring(thing)
	elseif typ == "table" then
		local subindent = indent .. indent_delta
		local is_non_empty = false
		if is_list(thing) then
			local json = "["
			local sep = lsep .. subindent
			for k, v in pairs(thing) do
				json = json .. sep .. to_json(v, indent_delta, lsep, subindent)
				sep = "," .. lsep .. subindent
				is_non_empty = true
			end
			if is_non_empty then json = json .. lsep .. indent end
			return json .. "]"
		else
			local json = "{"
			local sep = lsep .. subindent
			for k, v in sorted_pairs(thing) do
				json = json .. sep .. to_json(tostring(k)) .. ": " .. to_json(v, indent_delta, lsep, subindent)
				sep = "," .. lsep .. subindent
				is_non_empty = true
			end
			if is_non_empty then json = json .. lsep .. indent end
			return json .. "}"
		end
	else
		error("Don't know how to convert Lua value of type " .. typ .. " to JSON")
	end
end

local function_data = {
	factorio1_functions = {
		{
			factorio1_function_name = "add",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Add"
		},
		{
			factorio1_function_name = "subtract",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Subtract"
		},
		{
			factorio1_function_name = "multiply",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Multiply"
		},
		{
			factorio1_function_name = "divide",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Divide"
		},
	},
	factorio2_functions = {
		{
			syntax_mode = "infix",
			symbol = "+",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Add"
		},
		{
			syntax_mode = "infix",
			symbol = "-",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Subtract"
		},
		{
			syntax_mode = "infix",
			symbol = "*",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Multiply"
		},
		{
			syntax_mode = "infix",
			symbol = "/",
			togvm_function_name = "http://ns.nuke24.net/TOGVM/Functions/Divide"
		},

	}
}

local function clone(obj)
	if type(obj) == "table" then
		local the_clone = {}
		for k, v in pairs(obj) do
			the_clone[k] = clone(v)
		end
		return the_clone
	else
		return obj
	end
end

local function make_function_database(raw_data)
	local db = { raw_data = raw_data }
	local merged = {}
	local merged_by_f1_name = {}
	local function initfunc(name)
		if merged[name] ~= nil then
			return merged[name]
		else
			merged[name] = {
				factorio2_functions = { }
			}
			return merged[name]
		end
	end
	for _, f1func in pairs(raw_data.factorio1_functions) do
		local func = initfunc(f1func.togvm_function_name)
		for k, v in pairs(f1func) do
			func[k] = v
		end
		merged_by_f1_name[f1func.factorio1_function_name] = func
	end
	for _, f2func in pairs(raw_data.factorio2_functions) do
		local func = initfunc(f2func.togvm_function_name)
		func.factorio2_functions[f2func.symbol] = f2func
	end
	db.merged = merged
	db.merged_by_f1_name = merged_by_f1_name
	setmetatable(db, { __index = {
		get_by_name = function(self, name) return self.merged[name] end,
		get_by_factorio1_name = function(self, name) return self.merged_by_f1_name[name] end,
	}})
	return db
end

local function_database = make_function_database(function_data)
-- print( to_json(function_database,"\t") )



local fmtf2ne_infix
local fmt2fne

function fmtf2ne_infix(op, args)
	local res = ""
	local sep = ""
	local opsep = " " .. op .. " "
	local argcount = 0
	for k, v in pairs(args) do
		res = res .. sep .. fmtf2ne(v)
		sep = opsep
		argcount = argcount + 1
	end
	if argcount == 0 then
		error("No arguments to infix-format!")
	elseif argcount == 1 then
		return res
	else
		return "(" .. res .. ")"
	end
end

function fmtf2ne(expr)
	if expr.type == "function-application" then
		local func = function_database:get_by_factorio1_name(expr.function_name)
		if func == nil then
			error("Don't yet know how to convert function '" .. expr.function_name .. "'")
		else
			for _, f2func in pairs(func.factorio2_functions) do
				if f2func.syntax_mode == "infix" then
					return fmtf2ne_infix(f2func.symbol, expr.arguments)
				end
				break
			end
			error("No Factorio 2 functions registered for '" .. expr.function_name .. "'")
		end
	elseif expr.type == "literal-number" then
		return tostring(expr.literal_value)
	elseif expr.type == "literal-boolean" then
		return tostring(expr.literal_value)
	elseif expr.type == "variable" then
		return tostring(expr.variable_name)
	elseif expr.type == nil then
		error("Expression has no type: " .. to_json(expr))
	else
		error("Don't yet know how to convert expression type '" .. expr.type .. "'")
	end
end

return {
	is_list = is_list,
	to_json = to_json,
	to_factorio_2_noise_expression_string = fmtf2ne,
}
