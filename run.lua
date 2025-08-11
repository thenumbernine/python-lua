#!/usr/bin/env luajit
local python = require 'python'
local path = require 'ext.path'
local fn = assert(..., "expected filename")
python( (assert(path(fn):read())) )
