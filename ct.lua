-- CT: loads a subset of Lua table constructors.
-- v1.0.0
-- https://www.github.com/rabbitboots/ct
-- See LICENSE and README.md for details.


local ct = {}


local jit = rawget(_G, "jit")


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local _makeLUT = require(PATH .. "pile_table").makeLUT
local interp = require(PATH .. "pile_interp")
local stringWalk = require(PATH .. "string_walk")


ct.lang = {
	err_bad_brk = "invalid bracketed key",
	err_bad_sep = "expected separator (',' or ';')",
	err_bad_val = "invalid value",
	err_close_brk = "expected closing ']'",
	err_key_nan = "cannot use NaN as table key",
	err_kv_no_eq = "expected '='",
	err_51_nested_str = "nesting of '[[...]]' in Lua 5.1 is deprecated",
	err_no_expr = "cannot parse this expression or function call",
	err_no_return = "expected 'return'",
	err_no_tbl = "expected initial table constructor",
	err_num_conv = "tonumber() conversion failed",
	err_str_parse = "parsing string failed: $1",
	err_tbl_unbal = "unbalanced nested tables",
	err_trailing = "trailing content after table constructor"
}
local lang = ct.lang


local keywords = {}


keywords["Lua 5.1"] = _makeLUT({
	"and", "break", "do", "elseif", "else", "end", "false", "for", "function", "if", "in",
	"local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"
})
keywords["Lua 5.2"] = _makeLUT({
	"and", "break", "do", "elseif", "else", "end", "false", "for", "function", "goto", "if", "in",
	"local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"
})
keywords["Lua 5.3"] = keywords["Lua 5.2"]
keywords["Lua 5.4"] = keywords["Lua 5.2"]



local function _ignoreLine(W)
	return W:match("^#[^\n]*\n?")
end


local function _whitespace(W)
	return W:match("^%s+")
end


local function _check51Nest(W, s, i)
	if _VERSION == "Lua 5.1" and not jit and W.S:find("^%[%[", i) and s:find("[[", 1, true) then
		W:error(lang.err_51_nested_str)
	end
end


local function _comment(W)
	if W:match("^%-%-") then
		local i = W.I
		local _, s = W:match("^%[(=*)%[(.-)%]%1%]")
		if s then
			_check51Nest(W, s, i)
			return s
		end
		return W:match("^[^\n]*")
	end
end


local function _skipWS(W)
	while _whitespace(W) or _comment(W) do end
end


local function _nil(W)
	return W:lit("nil")
end


local _bools = {[false]=false, [true]=true}
local function _bool(W)
	return _bools[W:lit("false") or W:lit("true")]
end


local _load = rawget(_G, "loadstring") or load


local function _loadShortString(W, s, q)
	local ret, err = _load("return " .. q .. s .. q, "(unescape short string)")
	if not ret then
		W:error(interp(lang.err_str_parse, err))
	end
	return ret
end


local function _string(W)
	local i = W.I
	-- bracketed string
	local l1, s1 = W:match("^%[(=*)%[(.-)%]%1%]")
	if s1 then
		_check51Nest(W, s1, i)
		-- Lua ignores initial newlines in bracketed strings
		return s1:match("\r?\n(.*)") or s1
	-- quoted string
	else
		local i, q, j = W:match("^()(['\"]).-[^\\]()%2")
		if q then
			local s2 = W.S:sub(i + 1, j - 1)
			return s2:find("\\", 1, true) and _loadShortString(W, s2, q) or s2
		end
	end
end


local function _number(W, is_key)
	local i = W.I
	-- unary minus
	local minus = W:match("^%-")
	if minus then
		_skipWS(W)
	end

	-- check hardcoded literals
	if W:match("^1/0") then
		return math.huge * (minus and -1 or 1)

	elseif W:match("^0/0") then
		if is_key then W:error(err_key_nan) end
		return 0/0
	end

	local s = W:match("^([0-9%.][^%s,;}]*)")
	if s then
		-- check for comment as delimiter
		local n = #s
		s = s:match("(.-)%-%-") or s
		n = n - #s
		W:step(-n)

		return tonumber((minus or "") .. s) or W:error(lang.err_num_conv)
	end
	W:seek(i)
end


local function _noExpressions(W)
	if W:match("^%(") then
		W:error(lang.err_no_expr)
	end
end


local function _name(W)
	local i = W.I
	local key_hash = keywords[_VERSION == "Lua 5.1" and jit and "Lua 5.2" or _VERSION]
	local s
	-- LuaJIT's name requirements are relaxed
	if jit then
		s = W:match("^[%a_\128-\255][%w_\128-\255]*")
	else
		s = W:match("^[%a_][%w_]*")
	end
	if s and not key_hash[s] then
		return s
	end
	W:seek(i)
end


local _value, _table


_value = function(W)
	local v
	if not _nil(W) then
		v = _bool(W) or _number(W) or _string(W) or _table(W) or W:error(lang.err_bad_val)
	end
	return v
end


_table = function(W)
	if W:match("^{") then
		local array_i = 1
		table.insert(W.stack, {})
		while true do
			local key
			_skipWS(W)
			_noExpressions(W)
			if W:match("^}") then
				break

			elseif W:match("^%[[^%[=]") then -- disambiguate bracketed keys from long bracket strings
				W:step(-1)
				_skipWS(W)
				_noExpressions(W)
				key = _bool(W) or _number(W) or _string(W) or _table(W) or W:error(lang.err_bad_brk)
				_skipWS(W)
				W:matchReq("^%]", lang.err_close_brk)
				_skipWS(W)
				W:matchReq("^=", lang.err_kv_no_eq)
				_skipWS(W)
			else
				_noExpressions(W)
				key = _name(W)
				if key then
					_skipWS(W)
					W:matchReq("^=", lang.err_kv_no_eq)
					_skipWS(W)
				end
			end

			_noExpressions(W)
			local v = _value(W)
			if key then
				W.stack[#W.stack][key] = v
			else
				W.stack[#W.stack][array_i] = v
				array_i = array_i + 1
			end
			_skipWS(W)
			if not W:match("^[,;]") then
				if not W.S:find("%s*}", W.I) then
					W:error(lang.err_bad_sep)
				end
			end
			if W:isEOS() then W:error(lang.err_tbl_unbal) end
		end
		return table.remove(W.stack)
	end
end


function ct.deserialize(s)
	local W = stringWalk.new(s) -- type-checks arg #1

	W.stack = {}

	-- skip the first line if it begins with '#'
	_ignoreLine(W)
	_skipWS(W)
	W:matchReq("^return", lang.err_no_return)
	_skipWS(W)
	_noExpressions(W) -- catch 'return ({…})'

	W.t = _table(W) or W:error(lang.err_no_tbl)
	_skipWS(W)
	if not W:isEOS() then
		W:error(lang.err_trailing)
	end
	return W.t
end


return ct
