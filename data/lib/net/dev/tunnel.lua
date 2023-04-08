-- Copyright (c) 2022 AnonymousDapper
local component = require "component"

local link = require "net/link"
local ether = require "net/layer/ether"

local invoke = component.invoke

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
    local packet = ether.writeFrame(dst, self.mac) .. data
    self.__updateStats(false, #packet)

    return invoke(self.mac, "send", packet)
end

function methods:broadcast(port, data)
    local packet = ether.writeFrame(ether.BROADCAST_MAC, self.mac) .. data
    self.__updateStats(false, #packet)

    return invoke(self.mac, "send", packet)
end

function methods:getStrength()
    error(self.name .. ": operation not supported")
end

function methods:setStrength(val)
    error(self.name .. ": operation not supported")
end

function methods:getWakeMessage()
    return invoke(self.mac, "getWakeMessage")
end

function methods:setWakeMessage(msg, fuzz)
    return invoke(self.mac, "setWakeMessage", msg, fuzz)
end

local idx = 0

---@param address string
---@param opts table?
---@return Interface
function driver.init(address, opts)
    if component.type(address) ~= "tunnel" then
        error("Attempt to load tunnel driver for non-tunnel component: " .. address)
    end

    local mtu
    local meths = component.methods(address)
    if meths["maxPacketSize"] then
        mtu = invoke(address, "maxPacketSize")
    else
        mtu = 8192
    end

    local ifaceName = opts and opts.name
    if not ifaceName then
        ifaceName = "tun" .. tostring(idx)
        idx = idx + 1
    end

    local iface = link.new(address, ifaceName, "ipip", mtu, methods, {__index={__ports={}}})

    return iface
end


return driver