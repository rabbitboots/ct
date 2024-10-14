**Version:** 1.0.0

# CT

CT loads a subset of table constructors for Lua 5.1 - 5.4.

See **Notes** for a list of allowed features.


# API: ct.lua

## ct.deserialize

Creates a table from a Lua constructor string. Raises an error if the parser fails.

`local t = ct.deserialize(s)`

* `s`: The Lua table constructor (`"return {…}"`)

**Returns:** The Lua table.


# Notes

## Supported and Unsupported Constructor Features

Constructors may include:

* Any numbers that can be coverted with `tonumber()`
  * Additionally, the hardcoded strings `1/0` (infinity) and `0/0` (NaN)
* Strings
* Nested tables
* Booleans
* Nil (as a value only; does nothing)

Table constructors **may not** include:

* Operators, except for unary minus `-` before numbers
* Expressions, except for the hardcoded `1/0` and `0/0`
* Function definitions, function calls
* References to upvalues (ie `return {bignum=math.huge}`
* LuaJIT number suffixes `i`, `ll` and `ull` (`tonumber()` doesn't read them from strings)

Comments and whitespace are discarded. Statements (assignments, loops, function calls...) may not appear before or after the constructor.


## Why

CT was written as a proof of concept while experimenting with human-readable serialization options for Lua.


## License

See `LICENSE` for details.