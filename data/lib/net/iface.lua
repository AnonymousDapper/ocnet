-- Copyright (c) 2022 AnonymousDapper
local filesystem = require "filesystem"
local devfs = require "devfs"
local text = require "text"

local lib = {}

local drivers = {}

local devFsTree = {}

local LIB_PATH = "/lib/net/dev"

local function createToggle(read, write, switch)
    return {
        read = read and function() return tostring(read()) end,
        write = write and function(val)
            val = text.trim(tostring(val))
            local on = val == "1" or val == "true"
            local off = val == "0" or val == "false"
            if not on and not off then return nil, "bad value" end
            if switch then
                (off and switch or write)()
            else
                write(on)
            end
        end
    }
end

local function makeProxy(link)
    local proxy = {
        device = {device = link},
        mac = {read = function() return link.mac end},
        name = {read = function() return link.name end},
        type = {read = function() return link.type end},
        mtu = {read = function() return tostring(link.mtu) end},
        state = createToggle(function() return link.state and "1" or "0" end, link.up, link.down),
        traffic = {link.stats.packetIn, link.stats.packetOut, link.stats.byteIn, link.stats.byteOut},
    }

    return {list = proxy}
end

---@param name string
---@param path string?
---@return {init: fun(...): Interface}
function lib.loadDriver(name, path)
    local libPath = path or LIB_PATH
    local modPath = ("%s/%s.lua"):format(libPath, name)
    local mod, err = loadfile(modPath, "t")

    if not mod then
        error(("Failed loading net driver `%s` from %s: %s"):format(name, libPath, err))
    end

    local driver = mod()

    drivers[name] = driver
    return driver
end

---@param name string
---@return boolean
function lib.unloadDriver(name)
    if not drivers[name] then return false end

    drivers[name] = nil

    return true
end

function lib.autoloadDrivers()
    for file in filesystem.list(LIB_PATH) do
        lib.loadDriver(file:sub(1, -5))
    end
end

---@param type string
---@param ... any
---@return Interface
function lib.createDevice(type, ...)
    if not drivers[type] then error("No driver for device: " .. type) end

    local link = drivers[type].init(...)

    if devFsTree[link.name] then io.stderr:write("Device already exists in devfs: ", link.name, "\n") end

    devFsTree[link.name] = makeProxy(link)

    return link
end

---@param name string
---@return boolean
function lib.removeDevice(name)
    if not devFsTree[name] then return false end
    devFsTree[name] = nil
    return true
end

---@param name string
---@return Interface?
function lib.getDevice(name)
    if not devFsTree[name] then return end
    return devFsTree[name].list.device.device
end

---@return string[]
function lib.listDevices()
    local names = {}
    for name in next, devFsTree do
        table.insert(names, name)
    end
    return names
end

function lib.initDevFs()
    devfs.create("net", {list = devFsTree})
end

return lib