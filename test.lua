#!/usr/bin/env luajit
local python = require 'python'

python[[
x = 2
]]

print(python.dict.x)
