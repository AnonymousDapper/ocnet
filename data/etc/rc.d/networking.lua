-- Copyright (c) 2022 AnonymousDapper
-- Network init service
local event = require "event"
local filesystem = require "filesystem"

local ether = require "net/layer/ether"
local iface = require "net/iface"
local fmt = require "net/fmt"
local syslog = require "syslog"

local log = syslog.getLogger("net")

local listenerActive = false

local listenerID

local links = {}

local function modemListener(_, dstMac, srcMac, port, _, data)
    if not listenerActive then return false end

    if not links[dstMac] then return end

    local link = links[dstMac]

    if not link.state then return end

    if not link.isOpen(port) then return end

    link.__updateStats(true, #data)

    local res, why = ether.readFrame(data)

    if not res then log:warn("dropping link packet: ", why) end

    if res.dst ~= link.mac and res.dst ~= ether.BROADCAST_MAC then log:error("mismatched link dst: ", res.dst) end

    if res.src ~= srcMac then log:error("mismatched link src: ", res.src) end

    local frameType = fmt.getFrameType(res.data)

    event.push(frameType .. "_packet", res.dst, res.src, port, res.data)
end

function start()
    for _,ifname in next,iface.listDevices() do
        local link = iface.getDevice(ifname)
        links[link.mac] = link
    end

    listenerActive = true

    listenerID = event.listen("modem_message", modemListener)
end

function stop()
    for _, link in next, links do
        link.down()
    end

    listenerActive = false
    links = {}

    event.cancel(listenerID)
end