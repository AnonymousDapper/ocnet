-- Copyright (c) 2022 AnomymousDapper
local event = require "event"

local lib = {}

---@param mac string
---@param name string
---@param type string
---@param mtu number
---@param methods table<string, fun(iface: Interface, ...): any>
---@param mt table | nil
---@return Interface
function lib.new(mac, name, type, mtu, methods, mt)
	---@class Interface
	---@field mac string
	---@field name string
	---@field type string
	---@field mtu number
	---@field state boolean
	---@field stats { packetIn: number, packetOut: number, byteIn: number, byteOut: number }
	local iface = {
		mac = mac,
		name = name,
		type = type,
		mtu = mtu,
		state = false,
		stats = {packetIn = 0, packetOut = 0, byteIn = 0, byteOut = 0}
	}

	local function ifUp()
		if not iface.state then
			error(iface.name .. ": device is down")
		end
	end

	---@param port number
	---@return boolean
	function iface.isOpen(port)
		checkArg(1, port, "number")
		ifUp()

		return methods.isOpen(iface, port)
	end

	---@param port number
	---@return boolean
	function iface.open(port)
		checkArg(1, port, "number")
		ifUp()
		if port ~= nil and port < 0 or port > 65535 then
			error(iface.name .. ": bad port: " .. tostring(port))
		end

		return methods.open(iface, port)
	end

	---@param port number | nil
	---@return boolean
	function iface.close(port)
		checkArg(1, port, "number", "nil")
		ifUp()
		if port ~= nil and port < 0 or port > 65535 then
			error(iface.name .. ": bad port: " .. tostring(port))
		end

		return methods.close(iface, port)
	end

	---@param dst string
	---@param port number
	---@param data string
	function iface.send(dst, port, data)
		checkArg(1, dst, "string")
		checkArg(2, port, "number")
		checkArg(3, data, "string")
		ifUp()

		return methods.send(iface, dst, port, data)
	end

	---@param port number
	---@param data string
	function iface.broadcast(port, data)
		checkArg(1, port, "number")
		checkArg(2, data, "string")
		ifUp()

		return methods.broadcast(iface, port, data)
	end

	---@return number
	function iface.getStrength()
		ifUp()

		return methods.getStrength(iface)
	end

	---@param val number
	function iface.setStrength(val)
		checkArg(1, val, "number")
		ifUp()

		return methods.setStrength(iface, val)
	end

	---@return string
	function iface.getWakeMessage()
		ifUp()

		return methods.getWakeMessage(iface)
	end

	---@param message string
	---@param fuzzy boolean
	function iface.setWakeMessage(message, fuzzy)
		checkArg(1, message, "string")
		checkArg(2, fuzzy, "boolean")
		ifUp()

		return methods.setWakeMessage(iface, message, fuzzy)
	end

	---@return boolean
	function iface.up()
		if iface.state then return false end
		iface.state = true

		event.push("ifup", iface.name)
		return true
	end

	---@return boolean
	function iface.down()
		if not iface.state then return false end
		iface.close()
		iface.state = false

		event.push("ifdown", iface.name)
		return true
	end

	function iface.__updateStats(inbound, dataSize)
		local stats = iface.stats
		if inbound then
			stats.packetIn = stats.packetIn + 1
			stats.byteIn = stats.byteIn + dataSize
		else
			stats.packetOut = stats.packetOut + 1
			stats.byteOut = stats.byteOut + dataSize
		end
	end

	if mt then
		return setmetatable(iface, mt)
	else
		return iface
	end
end

return lib