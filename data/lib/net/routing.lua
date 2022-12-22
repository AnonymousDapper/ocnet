-- Copyright (c) 2022 AnonymousDapper


-- {address: number, interface: string}
local addressTable = {}

-- {address: number, mac: string}
local arpTable = {}

-- {network: number, netmask: number, gateway: number, device: number}[]
local routeTable = {
--[[	{
		network = "0.0.0.0",
		netmask = "0.0.0.0",
		gateway = "f.a.c.1",
		device  = "f.a.c.6"
	},
	{
		network = "a.0.0.0",
		netmask = "f.0.0.0",
		gateway = "a.0.0.1",
		device  = "a.0.0.1"
	},
	{
		network = "f.a.c.6",
		netmask = "f.f.f.f",
		gateway = "a.0.0.1",
		device  = "a.0.0.1"
	}--]]
}

local lib = {}

return lib