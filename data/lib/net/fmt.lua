-- Copyright (c) 2022 AnonymousDapper
local lib = {
    magic_header = ">B",

    proto = {
        ip = {
            magic = 73,
            version = 1,
            header = ">BBBBI2I2I2"
        },

        ether = {
            magic = 69,
            header = ">Bc36c36"
        },

        arp = {
            magic = 65,
            request = 1,
            response = 2,
            body = ">BBI2I2",
            port = 1
        }
    }
}

function lib.getFrameType(frame)
    local magic, rest = lib.magic_header:unpack(frame)

    for proto, entry in next, lib.proto do
        if entry.magic == magic then
            return proto
        end
    end

    return "unknown"
end

return lib