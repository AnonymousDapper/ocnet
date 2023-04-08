-- Copyright (c) 2022 AnonymousDapper
local component = require "component"

local link = require "net/link"
local ether = require "net/layer/ether"

local invoke = component.invoke

local driver = {}

local methods = {}

function methods:isOpen(port)
    return invoke(self.mac, "isOpen", port)
end

function methods:open(port)
    return invoke(self.mac, "open", port)
end

function methods:close(port)
    return invoke(self.mac, "close", port)
end

function methods:send(dst, port, data)
    local packet = ether.writeFrame(dst, self.mac) .. data
    self.__updateStats(false, #packet)

    return invoke(self.mac, "send", dst, port, packet)
end

function methods:broadcast(port, data)
    local packet = ether.writeFrame(ether.BROADCAST_MAC, self.mac) .. data
    self.__updateStats(false, #packet)

    return invoke(self.mac, "broadcast", port, packet)
end

function methods:getWakeMessage()
    return invoke(self.mac, "getWakeMessage")
end

function methods:setWakeMessage(msg, fuzz)
    return invoke(self.mac, "setWakeMessage", msg, fuzz)
end

local wIdx = 0
local eIdx = 0

---@param address string
---@param opts table?
---@return Interface
function driver.init(address, opts)
    if component.type(address) ~= "modem" then
        error("Attempt to load modem driver for non-modem component: " .. address)
    end

    local ifaceName = opts and opts.name
    local wireless = false

    if invoke(address, "isWireless") then
        wireless = true
    end

    if not ifaceName then
        if wireless then
            ifaceName = "wlan" .. tostring(wIdx)
            wIdx = wIdx + 1
        else
            ifaceName = "eth" .. tostring(eIdx)
            eIdx = eIdx + 1
        end
    end

    local mtu
    local meths = component.methods(address)
    if meths["maxPacketSize"] then
        mtu = invoke(address, "maxPacketSize")
    else
        mtu = 8192
    end

    if wireless then
        function methods:getStrength()
            return invoke(self.mac, "getStrength")
        end

        function methods:setStrength(val)
            return invoke(self.mac, "setStrength", val)
        end
    else
        function methods:getStrength()
            error(self.name .. ": operation not supported")
        end

        function methods:setStrength(val)
            error(self.name .. ": operation not supported")
        end
    end

    local iface = link.new(address, ifaceName, "ether", mtu, methods)

    return iface
end


return driver