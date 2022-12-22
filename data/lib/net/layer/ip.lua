-- Copyright (c) 2022 AnonymousDapper
local fmt = require "net/fmt"

local lib = {}

local MAGIC = fmt.proto.ip.magic
local VERSION = fmt.proto.ip.version
local HEADER = fmt.proto.ip.header

local ADDR_FORMAT = "(%x)%.(%x)%.(%x)%.(%x)"

lib.protocols = {
    icmp = 1,
    tcp = 6,
    udp = 17,
    rip = 250,
    raw = 255
}

function lib.checkAddrFormat(address) -- bool
    local result = address:match(ADDR_FORMAT)

    return result and true or false
end

function lib.unpackAddr(address) -- (str, str, str, str)
    local unpacked = {address:match(ADDR_FORMAT)}
    if #unpacked ~= 4 then
        error("Invalid format")
    end

    return unpacked
end

function lib.addrToBytes(address)
    local unpacked = lib.unpackAddr(address)
    local high = (tonumber(unpacked[1], 16) << 4) | tonumber(unpacked[2], 16)
    local low = (tonumber(unpacked[3], 16) << 4) | tonumber(unpacked[4], 16)

    return (high << 8) | low
end

function lib.bytesToAddr(bytes)
    local data = bytes

    local a = (data >> 12) & 0xF
    local b = (data >> 8) & 0xF
    local c = (data >> 4) & 0xF
    local d = data & 0xF

    return string.format("%x.%x.%x.%x", a, b, c,d)
end


function lib.writeFrame(ttl, protocol, src, dst)
    local checksum = MAGIC + VERSION + ttl + protocol

    return HEADER:pack(MAGIC, VERSION, ttl, protocol, checksum, src, dst)
end

function lib.readFrame(data) -- table or (nil, err)
    local magic, ver, ttl, proto, check, src, dst, rest = HEADER:unpack(data)

    if (magic + ver + ttl + proto) ~= check then
        return nil, "bad checksum"
    end

    if magic ~= MAGIC then
        return nil, "bad magic"
    end

    if ver ~= VERSION then
        return nil, "version mismatch"
    end

    return {ttl=ttl, protocol=proto, source=lib.bytesToAddr(src), destination=lib.bytesToAddr(src), data=data:sub(rest)}
end

return lib