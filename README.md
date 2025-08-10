[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>
[![BuyMeACoffee](https://img.shields.io/badge/BuyMeA-Coffee-tan.svg)](https://buymeacoffee.com/thenumbernine)<br>

# Python in LuaJIT!

This is LuaJIT bindings and helper files to invoke Python.

# Requirements
Linux:
```
apt install python3
```

# Example:
```
luajit run.lua test.py
```

# TODO
- interpeter
- Lua <-> Python interface

goal / target use case:
``` Lua
local python = require 'python'
-- TODO implicit interpreter state construction, or explicit?

-- generate a function to load the python code
loader = python[[
print("2 + 2 =", 2 + 2)
]]
-- and load it
loader()

-- get stuff from python imports
local test = python[[
def Test:
	return 42
]]()
assert(test.Test() == 42)
```
