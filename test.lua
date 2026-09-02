#!/usr/bin/env luajit
local python = require 'python'

print(python[[
x = 2
]])
print(python.dict.x)
print('setting x = 3 via lua->libpython')
python.dict.x = 3
print(python.dict.x)

--[[ TODO
print'can I enumerate keys?'
for k,v in pairs(python.dict) do
	print(k, v)
end
--]]

--[[ hmm is there a way to get python to "return" / "eval" code?  or does everything need to be assigned at global scope?
print(python'return 2')
--]]
