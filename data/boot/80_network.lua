-- Copyright (c) 2022 AnonymousDapper
local component = require "component"
local event = require "event"
local uuid = require "uuid"

local cfg = require "cfgparse"
local syslog = require "syslog"
local iface = require "net/iface"

local log = syslog.getLogger("net_init")

local function contains(arr, v)
    for _, k in next, arr do
        if k == v then return true end
    end
    return false
end

local function parseHwConfig(path)
    local ruleset = {
        modem = {},
        tunnel = {},
        loop = {}
    }

    local f, why = io.open(path)
    if not f then log:error("config read failed: ", why) error(why) end

    local src = f:read("*a")
    f:close()

    local conf = cfg.parse(src)
    for opt in conf:each() do
        if opt.name ~= "class" then log:warn("Unknown rule, skipping: ", opt.name) goto endl end
        if #opt.args < 1 then log:warn("Illformed rule, skipping: ", opt.name) goto endl end
        if not ruleset[opt.args[1]] then log:warn("Unknown hw class, skipping: ", opt.args[1]) goto endl end

        local rule = {class=opt.args[1], auto=false, opts={}}
        if opt.args[2] == "auto" then rule.auto = true end
        if rule.auto and opt.args[3] then rule.opts.name = opt.args[3] end

        if opt.sub and not rule.auto then
            for sub in opt.sub:each() do
                if #sub.args == 0 then
                    rule.opts[sub.name] = true
                elseif #sub.args == 1 then
                    rule.opts[sub.name] = sub.args[1]
                else
                    log:warn("Bad options, ignoring: ", sub.name)
                end
            end
        end

        if not rule.auto and not rule.opts.hardware then log:warn("auto not declared but no MAC provided, skipping: ", rule.class) goto endl end

        table.insert(ruleset[rule.class], rule)
        ::endl::
    end

    return ruleset
end


local function start()
    local addrs = {}
    local manualLinks = {}
    local autoLinks = {}
    local devRules = parseHwConfig("/etc/net/hw.cfg")
    iface.autoloadDrivers()
    iface.initDevFs()

    for addr, type in next, component.list() do
        if devRules[type] then
            if not addrs[type] then addrs[type] = {} end
            addrs[type][addr] = type
        end
    end

    for class, ruleset in next, devRules do
        for _, rule in next, ruleset do
            if not rule.auto then
                local addr = rule.opts.hardware
                rule.opts.hardware = nil
                local type, err = component.type(addr)
                if not type then log:error("no hardware found: ", err) goto endi end
                if type ~= rule.class then log:warn("rule class does not match component class: ", rule.class, type) goto endi end
                table.insert(manualLinks, {class=rule.class, addr=addr, args=rule.opts})
                addrs[rule.class][addr] = nil
            else
                table.insert(autoLinks, {class=rule.class, args={name=rule.opts.name}})
            end
            ::endi::
        end
    end
    devRules = nil

    for _, linkRule in next, manualLinks do
        log:log("create device", linkRule.class, linkRule.addr, table.unpack(linkRule.args))
        iface.createDevice(linkRule.class, linkRule.addr, linkRule.args)
    end
    manualLinks = nil

    for _, linkRule in next, autoLinks do
        local address
        if linkRule.class == "loop" then
            address = uuid.next()
        else
            address = next(addrs[linkRule.class])
            addrs[linkRule.class][address] = nil
        end

        log:log("auto device", linkRule.class, linkRule.args.name)
        iface.createDevice(linkRule.class, address, linkRule.args)

    end
    autoLinks = nil
    addrs = nil

end

event.listen("init", start)