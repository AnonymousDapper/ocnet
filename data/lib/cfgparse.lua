-- Copyright (c) Stephan Henrichs (Kilobyte22)
-- Original library from Kilobyte22, I expanded it a bit
local configparse = {}

local ParseMode = {
    NONE = 0,
    TOKEN = 1,
    ESCAPED_STRING = 2,
    STRING = 3,
    COMMENT = 4,
    MULTI_COMMENT = 5
}

local Options = {}
Options.__index = Options

function Options.new()
    return setmetatable({byName = {}, all = {}}, Options)
end

function Options:add(value)
    table.insert(self.all, value)
    self.byName[value.name] = self.byName[value.name] or {}
    table.insert(self.byName[value.name], value)
end

local function makeiter(t)
    local i = 0
    local n = #t
    return function ()
        i = i + 1
        if i <= n then return t[i] end
    end
end

function Options:each(filter)
    if filter then
        if self.byName[filter] then
            return makeiter(self.byName[filter])
        else
            return function () end
        end
    else
        return makeiter(self.all)
    end
end

local function tokenize(data)
    local tokens = {}
    local pos = 1
    local line = 1
    local col = 1
    local mode = ParseMode.NONE
    local tmp

    local function next()
        local c = data:sub(pos, pos)
        pos = pos + 1
        if c == '\n' then
            line = line + 1
            col = 1
        else
            col = col + 1
        end
        return c
    end

    local function startToken(m)
        mode = m
        tmp = ""
    end

    local function finishToken()
        if mode == ParseMode.NONE then
            return
        end
        local t = {}
        if mode == ParseMode.TOKEN then
            if #tmp == 1 and (";{}"):match(tmp) then
                t.type = "syntax"
                t.value = tmp
            else
                local n = tonumber(tmp)
                if n then
                    t.type = "number"
                    t.value = n
                else
                    t.type = "token"
                    t.value = tmp
                end
            end

        else
            t.type = "string"
            t.value = tmp
        end
        tmp = nil
        mode = ParseMode.NONE
        t.line = line
        table.insert(tokens, t)
    end

    while pos <= #data do
        local c = next()
        if mode == ParseMode.STRING then
            if c == '"' then
                finishToken()
            elseif c == '\\' then
                mode = ParseMode.ESCAPED_STRING
            else
                tmp = tmp .. c
            end
        elseif mode == ParseMode.ESCAPED_STRING then
            if c == 'n' then
                tmp = tmp .. '\n'
            elseif c == 't' then
                tmp = tmp .. '\t'
            else
                tmp = tmp .. c
            end
            mode = ParseMode.STRING
        elseif mode == ParseMode.COMMENT then
            if c == '\n' then
                mode = ParseMode.NONE
            end
        else
            -- other modes

            if c == ' ' or c == '\n' or c == '\t' then
                finishToken()
            elseif c == ';' or c == '}' or c == '{' then
                finishToken()
                startToken(ParseMode.TOKEN)
                tmp = c
                finishToken()
            elseif c == '"' then
                -- string
                finishToken()
                startToken(ParseMode.STRING)
            elseif c == '#' then
                finishToken()
                mode = ParseMode.COMMENT
            else
                if mode == ParseMode.NONE then
                    startToken(ParseMode.TOKEN)
                end
                tmp = tmp .. c
            end
        end
    end
    return tokens
end

local function parse(tokens)
    local pos = 1
    local e = error

    local function error(msg)
        e("line "..tokens[pos - 1].line..": "..msg, 2)
    end

    local function next()
        local ret = tokens[pos]
        pos = pos + 1
        return ret
    end

    local function parseScope(root)
        local options = Options.new()
        while true do
            ::mainloop::
            if root and pos > #tokens then
                break
            end
            local t = next()
            if t.type == "syntax" then
                if t.value == "{" then
                    error("Unexpected '{'")
                elseif t.value == ';' then
                    goto mainloop
                elseif t.value == '}' then
                    break
                end
            else 
                local option = {name = t.value, args = {}}
                while true do
                    t = next()
                    if t.type == "syntax" then
                        if t.value == ';' then
                            break
                        elseif t.value == '{' then
                            option.sub = parseScope(false)
                            break
                        elseif t.value == '}' then
                            error("Unexpected '}'")
                        end
                    else 
                        table.insert(option.args, t.value)
                    end

                end
                options:add(option)
            end
        end
        return options
    end
    return parseScope(true)
end

function configparse.parse(data)
    local tokens = tokenize(data)
    return parse(tokens)
end

-- (c) AnonyousDapper
function configparse.unparse(conf)
    local buf = {}
    local function dump(node, indent)
        for opt in node:each() do
            table.insert(buf, ("%s%s %s%s"):format(indent, opt.name, table.concat(opt.args, " "), opt.sub and " {" or ""))
            if opt.sub then
                dump(opt.sub, indent .. "  ")
                table.insert(buf, indent .. "}")
            end
        end
    end

    dump(conf, "")
    return table.concat(buf, "\n")
end

return configparse