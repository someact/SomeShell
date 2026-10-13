-- Minimal JSON decoder for the settings files the shell writes
-- (~/.config/someshell/{hypr,keybinds}.json). Decode only; null becomes nil.

local json = {}

local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function fail(s, i, msg)
    error(string.format("json: %s at byte %d near '%s'", msg, i, s:sub(i, i + 10)), 0)
end

local function skip(s, i)
    return s:find("[^ \t\r\n]", i) or #s + 1
end

local function utf8char(code)
    return utf8.char(code)
end

local value

local function str(s, i)
    local out, j = {}, i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" then fail(s, i, "unterminated string") end
        if c == '"' then return table.concat(out), j + 1 end
        if c == "\\" then
            local e = s:sub(j + 1, j + 1)
            if e == "u" then
                local hex = s:sub(j + 2, j + 5)
                if not hex:match("^%x%x%x%x$") then fail(s, j, "bad \\u escape") end
                local code = tonumber(hex, 16)
                j = j + 6
                -- Surrogate pair
                if code >= 0xD800 and code <= 0xDBFF and s:sub(j, j + 1) == "\\u" then
                    local low = tonumber(s:sub(j + 2, j + 5), 16)
                    if low and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        j = j + 6
                    end
                end
                out[#out + 1] = utf8char(code)
            elseif escapes[e] then
                out[#out + 1] = escapes[e]
                j = j + 2
            else
                fail(s, j, "bad escape")
            end
        else
            local k = s:find('["\\]', j) or #s + 1
            out[#out + 1] = s:sub(j, k - 1)
            j = k
        end
    end
end

local function num(s, i)
    local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if not n or n == "" then fail(s, i, "bad number") end
    return tonumber(n), i + #n
end

local function arr(s, i)
    local out, n = {}, 0
    i = skip(s, i + 1)
    if s:sub(i, i) == "]" then return out, i + 1 end
    while true do
        local v
        v, i = value(s, i)
        n = n + 1
        out[n] = v
        i = skip(s, i)
        local c = s:sub(i, i)
        if c == "]" then return out, i + 1 end
        if c ~= "," then fail(s, i, "expected ',' or ']'") end
        i = skip(s, i + 1)
    end
end

local function obj(s, i)
    local out = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "}" then return out, i + 1 end
    while true do
        if s:sub(i, i) ~= '"' then fail(s, i, "expected key") end
        local k
        k, i = str(s, i)
        i = skip(s, i)
        if s:sub(i, i) ~= ":" then fail(s, i, "expected ':'") end
        local v
        v, i = value(s, skip(s, i + 1))
        out[k] = v
        i = skip(s, i)
        local c = s:sub(i, i)
        if c == "}" then return out, i + 1 end
        if c ~= "," then fail(s, i, "expected ',' or '}'") end
        i = skip(s, i + 1)
    end
end

value = function(s, i)
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == "{" then return obj(s, i) end
    if c == "[" then return arr(s, i) end
    if c == '"' then return str(s, i) end
    if c == "-" or c:match("%d") then return num(s, i) end
    if s:sub(i, i + 3) == "true" then return true, i + 4 end
    if s:sub(i, i + 4) == "false" then return false, i + 5 end
    if s:sub(i, i + 3) == "null" then return nil, i + 4 end
    fail(s, i, "unexpected character")
end

function json.decode(s)
    local v, i = value(s, 1)
    i = skip(s, i)
    if i <= #s then fail(s, i, "trailing data") end
    return v
end

-- Decode a file; nil (plus the reason) when it is missing or broken
function json.read(path)
    local f = io.open(path, "r")
    if not f then return nil, "missing" end
    local text = f:read("a")
    f:close()
    local ok, v = pcall(json.decode, text)
    if not ok then return nil, v end
    return v
end

return json
