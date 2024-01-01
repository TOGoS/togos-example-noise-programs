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
			for k, v in pairs(thing) do
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

return {
	is_list = is_list,
	to_json = to_json
}
