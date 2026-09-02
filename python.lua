require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local py = require 'python.ffi.python'
local class = require 'ext.class'

-- for gc dtor vs singleton dtor
local finalized

-- TODO wrap these and gc them when done?
local function luaToPython(v)
	local t = type(v)
	if t == 'nil' then
		--return py.Py_GetConstant(py.Py_CONSTANT_NOT_IMPLEMENTED)
		return py.Py_GetConstant(py.Py_CONSTANT_NONE)
	elseif t == 'boolean' then
		return py.Py_GetConstant(v and py.Py_CONSTANT_TRUE or py.Py_CONSTANT_FALSE)
	elseif t == 'number' then
		return py.PyFloat_FromDouble(v)
	elseif t == 'string' then
		-- should Lua strings be Python bytes or unicodes?
		return py.PyUnicode_FromString(v, #v)
		--return py.PyBytes_FromStringAndSize(v, #v)
	elseif t == 'table' then
		error'TODO'
	elseif t == 'function' then
		error'TODO'
	elseif t == 'thread' then
		error'TODO'
	else
		error("unknown type: "..tostring(t))
	end
end

-- for python tables,
-- should I do lua behavior and have missing references return nil?
-- or should I do python behavior and have missing references produce errors?
local noneObj = {}

local function pythonToLua(v)
	if 0 ~= py.PyLong_Check(v) then
--print('pythonToLua', v, 'is long')
		return py.PyLong_AsLong(v)
	elseif 0 ~= py.PyString_Check(v) then
--print('pythonToLua', v, 'is string')
		return ffi.string(py.PyUnicode_AsUTF8(v))
	elseif 0 ~= py.PyFloat_Check(v) then
--print('pythonToLua', v, 'is float')
		return py.PyFloat_AsDouble(v)
	elseif 0 ~= py.PyNumber_Check(v) then
--print('pythonToLua', v, 'is number')
		return py.PyNumber_AsSsize(o, ffi.null)
	-- TODO PyDict_Check
	-- TODO PyList_Check

	elseif 0 ~= py.Py_IsTrue(v) then
--print('pythonToLua', v, 'is true')
		return true
	elseif 0 ~= py.Py_IsFalse(v) then
--print('pythonToLua', v, 'is false')
		return false
	elseif 0 ~= py.Py_IsNone(v) then
--print('pythonToLua', v, 'is none')
		--return noneObj
		return nil
	else
--print('pythonToLua', v, 'is idk')
		error'TODO'
	end
end

local function PythonDict(module)
	local obj = py.PyModule_GetDict(module)
	return setmetatable({}, {
		obj = obj,
		__index = function(self, k)
--print('getting index', k, 'from dict', obj)
			k = tostring(k)
			local v = py.PyDict_GetItemString(obj, k)
--print('got value', v)
			-- what's the difference?
			return pythonToLua(v)
			--return pythonToLua(py.PyMapping_GetItemString(obj, tostring(k)))
			-- and how come my object always comes back nil?
		end,
		__newindex = function(self, k, v)
			k = tostring(k)
			py.PyDict_SetItemString(obj, k, luaToPython(v))
		end,
		--[[ TODO
		__gc = function(self)
			if finalized then return end
			py.Py_XDECREF(getmetatable(self).obj)
			getmetatable(self).obj = ffi.null
			obj = ffi.null
		end,
		--]]
		--[[ TODO
		__pairs = function(self)
		end,
		__ipairs = function(self)
		end,
		--]]
	})
end


local PythonEnv = class()
PythonEnv.none = noneObj

-- https://docs.python.org/3/extending/embedding.html
-- is there no separate states?  only one python state per process?
function PythonEnv:init()
	-- [[ simple
	py.Py_Initialize()
	--]]
	--[[ complex with config
	local config = ffi.new('PyConfig[1]')
	py.PyConfig_InitPythonConfig(config);
	status = PyConfig_SetBytesString(config, config[0].program_name, argv[0]);
	if (PyStatus_Exception(status)) {
		PyConfig_Clear(config);
		Py_ExitStatusException(status);
		os.exit(1)	-- or return or error() ?
	}

	status = Py_InitializeFromConfig(config);
	if (PyStatus_Exception(status)) {
		PyConfig_Clear(config);
		Py_ExitStatusException(status);
		os.exit(1)	-- or return or error() ?
	}
	PyConfig_Clear(config);
	--]]

	-- [[  https://wiki.python.org/moin/EmbeddingPythonTutorial
	--self.module = py.PyImport_ImportModule'__main__'
	-- reading that using PyImport_ImportModule'__main__' is prone to memory leaks...
	self.module = py.PyImport_AddModule'__main__'
print('__main__ module', self.module)
	self.dict = PythonDict(self.module)
print('__main__ dict', getmetatable(self.dict).obj)

	self.sys_module = py.PyImport_ImportModule'sys'
	self.sys_dict = PythonDict(self.sys_module)
	py.PyDict_SetItemString(getmetatable(self.dict).obj, 'sys', self.sys_module)
	--]]
end

-- is there no separate load/compile vs run? all at once?
function PythonEnv:runFile(file)	-- struct _IO_FILE *
	py.PyRun_SimpleFile(file)
end
function PythonEnv:runString(s)
--print('running', s)
	-- [[ run and done
	return py.PyRun_SimpleString(s)
	-- but then how do you access its contents?
	--]]
	--[[ https://docs.python.org/3/extending/embedding.html
	local name = py.PyUnicode_Decode(s, #s, ffi.null, ffi.null)
	local module = py.PyImport_Import(name)
	py.Py_DECREF(name)

	if module == ffi.null then
		-- TODO don't print, instead serialize to string
		py.PyErr_Print()
		error'python error'
	end

	-- get a variable from the module
	--local func = py.PyObject_GetAttrString(module, 'greet')
	--]]
	--[[ Google AI's suggestion
	-- returns a PyObject
	local dictObj = getmetatable(self.dict).obj
	-- Py_eval_input can evaluate and return expressions .... only.  no statements, functions, etc.
	-- Py_file_input can handle statements and functions, but cannot return *anything* apart from assigning it. smh python.
	-- ... and it looks like Py_CompileString will return values, but then doesn't write anything to the dict.
	-- so there's no way to run code that can handle both expressions and statements, and be able to write to global/module scope, and return/export values...
	--local result = py.PyRun_String(s, py.Py_eval_input, dictObj, dictObj)
	local result = py.PyRun_String(s, py.Py_file_input, dictObj, dictObj)
	if result == nil then	-- include in pythonToLua?
		return false, 'PyRun_String returned NULL\n'..s
	end
	-- what does Py_file_input return anyways?  what even can it return?
	return true
	--return pythonToLua(result)
	--]]
end
PythonEnv.__call = PythonEnv.runString

function PythonEnv:finalize()
	if py.Py_FinalizeEx() < 0 then
		error'Py_FinalizeEx failed'
	end
	finalized = true
end
PythonEnv.__gc = PythonEnv.finalize

-- singleton because that's what the C interface gives us so *shrug*
-- and because I don't want two dtors <-> two finalize's
return PythonEnv()
