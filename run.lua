#!/usr/bin/env luajit
local py = require 'python'
local path = require 'ext.path'
local fn = assert(..., "expected filename")
py.Py_Initialize()
py.PyRun_SimpleString( (assert(path(fn):read())) )
py.Py_Finalize()
