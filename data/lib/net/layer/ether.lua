-- Copyright (c) 2022 AnonymousDapper
local fmt = require "net/fmt"

local lib = {}

local MAGIC = fmt.proto.ether.magic
local HEADER = fmt.proto.ether.header

lib.BROADCAST_MAC = "ffffffff-ffff-ffff-ffff-ffffffffffff"
lib.NULL_MAC = "00000000-0000-0000-0000-000000000000"

function lib.writeFrame(dst, src) -- string
    if #src ~= 36 then error("invalid source MAC") end
    if #dst ~= 36 then error("invalid destination MAC") end

    return HEADER:pack(MAGIC, dst, src)

end

function lib.readFrame(data) -- table or (nil, err)
    local magic, dst, src, rest = HEADER:unpack(data)

    if magic ~= MAGIC then return nil, "bad magic" end

    return {src=src, dst=dst, data=data:sub(rest)}
end

return lib