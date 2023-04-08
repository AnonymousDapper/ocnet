-- Copyright (c) 2022 AnonymousDapper
local event = require "event"

local link = require "net/link"
local fmt = require "net/pack"
local ip = require "net/ip"

local iface = require "net/iface"

local MAGIC = fmt.proto.arp.magic
local REQUEST = fmt.proto.arp.request
local RESPONSE = fmt.proto.arp.response
local FMT = fmt.proto.arp.body
local PORT = fmt.proto.arp.port

local MAC_FORMAT = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

local function checkMacFormat(mac)
    return mac:match(MAC_FORMAT) and true or false
end

local listener_active = false

local arpCache = {}

local arpCacheTimers = {}

local lib = {}

local function createCacheTimer(address, mac, age)
    local time = (age or 10) * 60
    local timerId = event.timer(time, function()
        event.push("arp_cache_timeout", address)
        table.remove(arpCache, address)
    end)
    arpCacheTimers[address] = timerId
end

function lib.writeFrame(kind, spa, tpa)
    return FMT:pack(MAGIC, kind, ip.addrToBytes(spa), ip.addrToBytes(tpa))
end

function lib.readFrame(frame) -- table or (nil, err)
    local magic, kind, spa, tpa, rest = FMT:unpack(frame)

    if magic ~= MAGIC then return nil, "bad magic" end

    if kind ~= REQUEST and kind ~= RESPONSE then return nil, "bad method" end

    return {type=kind, sender=ip.bytesToAddr(spa), target=ip.bytesToAddr(tpa)}
end

-- TODO: tie in to routing lib
function lib.resolve(address, localAddr) -- string or (nil, err)
    if arpCache[address] then return arpCache[address] end

    lib.sendRequest(address, localAddr)

    local _, addr, mac = event.pull(30, "arp_resolve", address)

    if not addr then return nil, "no answer" end

    return mac
end

function lib.addAddress(address, mac, overwrite)
    if not ip.checkAddrFormat(address) then error("Invalid address format") end
    if not checkMacFormat(mac) then error("Invalid mac format") end

    if arpCache[address] and not overwrite then
        error(("Address exists: %s -> %s"):format(address, arpCache[address]))
    end

    arpCache[address] = mac
end

function lib.sendRequest(address, localAddr)
    if not listener_active then io.stderr:write("ARP listener not running, responses will not be processed\n") end

    local spa = localAddr or "0.0.0.0"
    local tpa = address

    for _, link in next, iface.getAllIfaces() do
        if link.broadcast then
            local packet = lib.writeFrame(REQUEST, spa, tpa)
            link.broadcast(PORT, packet)
        end
    end
end

function lib.init()
    if listener_active then return end

    for _, link in next, iface.getAllIfaces() do
        if link.broadcast then
            link.up()
            link.open(PORT)
        end
    end

    listener_active = true

    event.listen("arp_packet", function(_, dst, src, port, frame)
        if not listener_active then return false end

        local data, why = lib.readFrame(frame)

        if not data then
            event.push("syslog", "arp", "dropping packet", why)
            return
        end

        if data.type == RESPONSE then
            if arpCacheTimers[data.sender] then
                event.cancel(arpCacheTimers[data.sender])
                createCacheTimer(data.sender, src)
            end

            if arpCache[data.sender] then return end
            lib.addAddress(data.sender, src)
            event.push("arp_resolve", data.sender, src)
        else

            if dst == link.BROADCAST_MAC then
                for _, iface in next, iface.getAllIfaces() do
                    if iface.broadcast then
                        for _, addr in next, iface.listAddresses() do
                            if addr == data.target then
                                local packet = lib.writeFrame(RESPONSE, addr, data.sender)
                                iface.send(src, PORT, packet)
                            end
                        end
                    end
                end
            else
                event.push("syslog", "arp", "ignoring non-broadcast request", data.target)
            end

            if data.sender ~= "0.0.0.0" then
                if arpCacheTimers[data.sender] then
                    event.cancel(arpCacheTimers[data.sender])
                    createCacheTimer(data.sender, src)
                end

                lib.addAddress(data.sender, src)
            end
        end
    end)
end

function lib.stop()
    listener_active = false
end

return lib