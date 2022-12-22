-- Copyright (c) 2022 AnonymousDapper
-- event-based syslog service
local computer = require "computer"

local lib = {}

---@class Logger
---@field name string
local methods = {}

function methods:debug(...)
    computer.pushSignal("syslog", "DEBUG", self.name,  ...)
end

function methods:log(...)
    computer.pushSignal("syslog", "INFO", self.name,  ...)
end

function methods:warn(...)
    computer.pushSignal("syslog", "WARN", self.name,  ...)
end

function methods:error(...)
    computer.pushSignal("syslog", "ERROR", self.name,  ...)
end

---@param name string
---@return Logger
function lib.getLogger(name)
    return setmetatable(methods, {__index={name = name}})
end

return lib