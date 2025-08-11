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

python[[
print("2 + 2 =", 2 + 2)
]]

python[[
def Test:
	return 42
]]()
assert(python.dict.Test() == 42)
```
