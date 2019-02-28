.DELETE_ON_ERROR: index.html
index.html: data.lua.html index-header.html index-footer.html
	cat index-header.html data.lua.html index-footer.html >"$@"

.DELETE_ON_ERROR: data.lua.html
data.lua.html: data.lua lua-to-html
	./lua-to-html <"$<" >"$@"
