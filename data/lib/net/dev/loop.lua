-- Copyright (c) 2022 AnonymousDapper
local event = require "event"

local link = require "net/link"
local ether = require "net/layer/ether"

local driver = {}

local methods = {}

function methods:isOpen(port)
    return self.__ports[port] or false
end

function methods:open(port)
    if self.__ports[port] then
        return false
    end

    self.__ports[port] = true

    return true
end

function methods:close(port)
    if not port then
        self.__ports = {}
        return true
    end

    if self.__ports[port] then
        table.remove(self.__ports, port)
        return true
    end

    return false
end

function methods:send(dst, port, data)
    if dst ~= self.mac then
        error(self.name .. ": invalid destination MAC")
    end

    local packet = ether.writeFrame(self.mac, self.mac) .. data
    self.__updateStats(false, #packet)

    if self.__ports[port] then
        event.push("modem_message", self.mac, self.mac, port, 0, packet)
    end

    return true
end

function methods:broadcast(port, data)
    local packet = ether.writeFrame(ether.BROADCAST_MAC, self.mac) .. data
    self.__updateStats(false, #packet)

    if self.__ports[port] then
        event.push("modem_message", self.mac, self.mac, port, 0, packet)
    end

    return true
end

function methods:getStrength()
    error(self.name .. ": operation not supported")
end

function methods:setStrength(val)
    error(self.name .. ": operation not supported")
end

function methods:getWakeMessage()
    error(self.name .. ": operation not supported")
end

function methods:setWakeMessage(msg, fuzz)
    error(self.name .. ": operation not supported")
end

local idx = 0

---@param address string
---@param opts table?
---@return Interface
function driver.init(address, opts)
    local ifaceName = opts and opts.name

    if not ifaceName then
        if idx == 0 then
            ifaceName = "lo"
        else
            ifaceName = "lo" .. tostring(idx)
        end
    end

    idx = idx + 1

    local iface = link.new(address, ifaceName, "loopback", 65536, methods, {__index={__ports={}}})
    return iface
end

return driver