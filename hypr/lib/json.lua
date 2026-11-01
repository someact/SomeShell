-- A small JSON reader for the settings file. Objects become tables, arrays
-- become lists, null becomes nil. Errors come back as a message, never thrown.
local M = {}

local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function utf8_char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 | (cp >> 6), 0x80 | (cp & 0x3F)) end
    if cp < 0x10000 then return string.char(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F)) end
    return string.char(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3F), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F))
end

function M.decode(s)
    local i = 1

    local function fail(msg) error({ json = msg .. " at character " .. i }) end
    local function skip() i = s:find("[^ \t\r\n]", i) or #s + 1 end

    local value

    local function str()
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == "" then fail("unterminated string") end
            if c == '"' then i = i + 1 break end
            if c == "\\" then
                local e = s:sub(i + 1, i + 1)
                if e == "u" then
                    local cp = tonumber(s:sub(i + 2, i + 5), 16) or fail("bad \\u escape")
                    if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i + 6, i + 7) == "\\u" then
                        local lo = tonumber(s:sub(i + 8, i + 11), 16)
                        if lo then cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00) i = i + 6 end
                    end
                    out[#out + 1] = utf8_char(cp)
                    i = i + 6
                else
                    out[#out + 1] = escapes[e] or fail("bad escape")
                    i = i + 2
                end
            else
                local j = s:find('["\\]', i) or #s + 1
                out[#out + 1] = s:sub(i, j - 1)
                i = j
            end
        end
        return table.concat(out)
    end

    local function list()
        i = i + 1
        local t = {}
        skip()
        if s:sub(i, i) == "]" then i = i + 1 return t end
        while true do
            t[#t + 1] = value()
            skip()
            local c = s:sub(i, i)
            i = i + 1
            if c == "]" then return t end
            if c ~= "," then fail("expected , or ]") end
        end
    end

    local function object()
        i = i + 1
        local t = {}
        skip()
        if s:sub(i, i) == "}" then i = i + 1 return t end
        while true do
            skip()
            if s:sub(i, i) ~= '"' then fail("expected a key") end
            local k = str()
            skip()
            if s:sub(i, i) ~= ":" then fail("expected :") end
            i = i + 1
            t[k] = value()
            skip()
            local c = s:sub(i, i)
            i = i + 1
            if c == "}" then return t end
            if c ~= "," then fail("expected , or }") end
        end
    end

    value = function()
        skip()
        local c = s:sub(i, i)
        if c == "{" then return object() end
        if c == "[" then return list() end
        if c == '"' then return str() end
        for word, v in pairs({ ["true"] = true, ["false"] = false, ["null"] = M.null }) do
            if s:sub(i, i + #word - 1) == word then i = i + #word return v end
        end
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
        if num and num ~= "" then i = i + #num return tonumber(num) end
        fail("unexpected character")
    end

    local ok, result = pcall(function()
        local v = value()
        skip()
        if i <= #s then fail("trailing characters") end
        return v
    end)
    if ok then return M.strip(result) end
    return nil, type(result) == "table" and result.json or tostring(result)
end

-- null as a sentinel while parsing, nil in the result
M.null = setmetatable({}, { __tostring = function() return "null" end })
function M.strip(v)
    if v == M.null then return nil end
    if type(v) == "table" then
        for k, x in pairs(v) do v[k] = M.strip(x) end
    end
    return v
end

-- Read and decode a file: value, or nil and "missing" / an error message.
function M.read(path)
    local f = io.open(path, "r")
    if not f then return nil, "missing" end
    local text = f:read("a")
    f:close()
    if not text:find("%S") then return {}, nil end
    return M.decode(text)
end

return M
