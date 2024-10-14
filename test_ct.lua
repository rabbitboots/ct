-- Test: ct.lua


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local _load = loadstring or load
local jit = rawget(_G, "jit")


require(PATH .. "test.strict")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local ct = require(PATH .. "ct")


local hex = string.char


local cli_verbosity
for i = 0, #arg do
	if arg[i] == "--verbosity" then
		cli_verbosity = tonumber(arg[i + 1])
		if not cli_verbosity then
			error("invalid verbosity value")
		end
	end
end


local self = errTest.new("ct", cli_verbosity)


-- [===[
self:registerFunction("ct.deserialize()", ct.deserialize)
self:registerJob("ct.deserialize()", function(self)

	-- [====[
	do
		self:expectLuaError("arg #1 bad type", ct.deserialize, false)
		self:expectLuaError("arg #1 bad prolog", ct.deserialize, "RETURN {}")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] minimal test")
		local t = ct.deserialize("return {}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEvalFalse(next(t))
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] ignore first line if it starts with '#'")
		local t = ct.deserialize("#foobar\nreturn {}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEvalFalse(next(t))
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] single array value")
		local t = ct.deserialize("return {1}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] single array value, trailing comma")
		local t = ct.deserialize("return {1,}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] single array value, trailing semicolon")
		local t = ct.deserialize("return {1;}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
	end
	--]====]


	-- [====[
	do
		self:expectLuaError("trailing content", ct.deserialize, "return {},")
		self:expectLuaError("no table constructor", ct.deserialize, "return")
		self:expectLuaError("unclosed table constructor", ct.deserialize, "return {")
		self:expectLuaError("too many close braces", ct.deserialize, "return {}}")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] trailing whitespace and comments")
		local t = ct.deserialize("return {1,}   --foo\n  --[[bar]]  ")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] multiple array items")
		local t = ct.deserialize("return {1, 2,3, 4,}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
		self:isEqual(t[2], 2)
		self:isEqual(t[3], 3)
		self:isEqual(t[4], 4)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] multiple array items with various delimiters")
		local t = ct.deserialize("return {1, 2; 3 , 4--[[comment]], 5}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
		self:isEqual(t[2], 2)
		self:isEqual(t[3], 3)
		self:isEqual(t[4], 4)
		self:isEqual(t[5], 5)
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] Lua 5.1 number forms")
		local t = ct.deserialize("return {1.0, 2e+3; 3e-1 , -4, 0x05}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1)
		self:isEqual(t[2], 2e+3)
		self:isEqual(t[3], 3e-1)
		self:isEqual(t[4], -4)
		self:isEqual(t[5], 0x5)
	end
	--]====]


	-- [====[
	if not (_VERSION >= "Lua 5.2") and not jit then
		self:print(4, "[SKIP] Lua 5.2 number forms -- needs Lua 5.2+ or LuaJIT")
	else
		self:print(4, "[+] Lua 5.2 number forms")
		local t = ct.deserialize("return {0x5.5p-1}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 2.65625) -- 0x5.5p-1
	end
	--]====]


	-- [====[
	if not jit then
		self:print(4, "[SKIP] LuaJIT number forms -- requires LuaJIT")
	else
		self:print(4, "[+] LuaJIT number forms")
		local t = ct.deserialize("return {0b1010}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 10) -- 0b1010
	end
	--]====]


	-- [====[
	if not jit then
		self:print(4, "[SKIP] LuaJIT unsupported number forms -- requires LuaJIT")
	else
		self:print(4, "[+] LuaJIT unsupported number forms")
		self:expectLuaError("suffix: 'i'", ct.deserialize, "return {1i}")
		self:expectLuaError("suffix: 'll'", ct.deserialize, "return {1ll}")
		self:expectLuaError("suffix: 'ull'", ct.deserialize, "return {1ull}")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] Hard-coded literals for infinity and NaN")
		local t = ct.deserialize("return {1/0, - 1/0, 0/0}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], 1/0)
		self:isEqual(t[2], -1/0)
		self:isNan(t[3])
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] string value, single quotes")
		local t = ct.deserialize("return {'a'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], "a")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] string value, double quotes")
		local t = ct.deserialize("return {\"a\"}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], "a")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] quoted string with character escapes")
		local t = ct.deserialize("return {'a\t\064'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], [=======[a	@]=======])
	end
	--]====]


	-- [====[
	if not (_VERSION >= "Lua 5.2" or jit) then
		self:print(4, "[SKIP] Lua 5.2+ invalid escapes -- run with Lua 5.2+ or LuaJIT")
	else
		self:expectLuaError("invalid character escapes", ct.deserialize, "return {'a\\Bc'}")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] string value, block-quotes level 0")
		local t = ct.deserialize("return {[[a]]}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], "a")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] string value, block-quotes level 3")
		local t = ct.deserialize("return {[===[a]===]}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t[1], "a")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] one hash assignment")
		local t = ct.deserialize("return {['foo'] = 'bar'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t.foo, "bar")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] multiple hash assignments")
		local t = ct.deserialize("return {['foo'] = 'bar', ['baz'] = 'bop'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t.foo, "bar")
		self:isEqual(t.baz, "bop")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] 'name' form for keys")
		local t = ct.deserialize("return {foo = 'bar'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t.foo, "bar")
	end
	--]====]


	-- [====[
	do
		self:expectLuaError("invalid name", ct.deserialize, "return {f@f = 'bar'}")
	end
	--]====]


	--Test LuaJIT extended names
	-- [====[
	if not jit then
		self:print(4, "[SKIP] LuaJIT extended names -- run with LuaJIT")
	else
		self:print(4, "[+] LuaJIT extended names")
		local t = ct.deserialize("return {ǫųŗş = 'bear'}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isEqual(t["ǫųŗş"], "bear")
	end
	--]====]


	-- [====[
	do
		self:print(4, "[+] nested tables")
		local t = ct.deserialize("return {a={b={c={},},},}")
		self:print(3, inspect(t))
		self:isType(t, "table")
		self:isType(t.a, "table")
		self:isType(t.a.b, "table")
		self:isType(t.a.b.c, "table")
	end
	--]====]


	-- [====[
	do
		self:expectLuaError("not supported: (expressions)", ct.deserialize, "return {a = ('b')}")
	end
	--]====]


	-- [====[
	if not (_VERSION == "Lua 5.1" and not jit) then
		self:print(4, "[SKIP] Lua 5.1 nesting of bracketed comments and strings -- run with Lua 5.1")
	else
		self:expectLuaError("Lua 5.1 deprecated nested '[[...]]' in strings", ct.deserialize, "return {[[ a [[ ]]}")
		self:expectLuaError("Lua 5.1 deprecated nested '[[...]]' in comments", ct.deserialize, "--[[ [[ ]] return {}")
	end
	--]====]
end
)
--]===]


self:runJobs()
