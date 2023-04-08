-- Copyright (c) 2022 AnonymousDapper
local event = require "event"
local filesystem = require "filesystem"

local LOG_PATH = "/var/log/"
local LOG_FILE = "syslog"

event.listen("syslog", function(_, level, name, ...)
    local f, r = io.open(LOG_PATH .. LOG_FILE, "a")
    if not f then error(r) end
    local args = {...}

    f:write("[" .. os.date("%m/%d-%T") .. "] ")
    f:write(level .. string.rep(" ", 6 - #level))
    f:write(name .. string.rep(" ", 10 - #name))
    if #args ~= 0 then
        for _, item in next, args do
            f:write(" " .. tostring(item))
        end
    end
    f:write("\n")

    f:close()
end)

event.listen("init", function()
    if not filesystem.exists(LOG_PATH) then
        filesystem.makeDirectory(LOG_PATH)
    end

    event.push("syslog", "INFO", "kernel", "system started")
end)