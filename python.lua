require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local py = require 'python.lib'
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
print('pythonToLua', v)	
	if py.Py_IsNone(v) then
print'none'		
		--return noneObj
		return nil
	elseif py.PyObject_IsTrue(v) then
print'true'		
		return true
	elseif py.PyObject_IsFalse(v) then
print'fale'
		return false
	elseif py.PyFloat_Check(v) then
print'float'
		return py.PyFloat_AsDouble(v)
	elseif py.PyNumber_Check(v) then
print'number'		
		return py.PyNumber_AsSsize(o, ffi.null)
	elseif py.PyLong_Check(v) then
print'long'
		return py.PyLong_AsLong(v)
	elseif py.PyString_Check(v) then
print'string'
		return ffi.string(py.PyUnicode_AsUTF8(v))
	else
		error'TODO'
	end
end

local function PythonDict(module)
	local obj = py.PyModule_GetDict(module)
	return setmetatable({}, {
		obj = obj,
		__index = function(self, k)
			-- what's the difference?
			--return pythonToLua(py.PyDict_GetItemString(obj, tostring(k)))
			return pythonToLua(py.PyMapping_GetItemString(obj, tostring(k)))
			-- and how come my object always comes back nil?
		end,
		__newindex = function(self, k, v)
			py.PyDict_SetItemString(obj, tostring(k), luaToPython(v))
		end,
		--[[ TODO
		__gc = function(self)
			if finalized then return end
			py.Py_XDECREF(getmetatable(self).obj)
			getmetatable(self).obj = ffi.null
			obj = ffi.null
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
	self.module = py.PyImport_ImportModule'__main__'
	self.dict = PythonDict(self.module)

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
	-- [[ run and done
	py.PyRun_SimpleString(s)
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
