--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    ["\\"] = "\\",
    ["\""] = "\"",
    ["\b"] = "b",
    ["\f"] = "f",
    ["\n"] = "n",
    ["\r"] = "r",
    ["\t"] = "t",
}

local escape_char_map_inv = { ["/"] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
    return "null"
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
            if type(k) ~= "number" then
                error("invalid table: mixed or invalid key types")
            end
            n = n + 1
        end
        if n ~= #val then
            error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"
    else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end


local type_func_map = {
    ["nil"] = encode_nil,
    ["table"] = encode_table,
    ["string"] = encode_string,
    ["number"] = encode_number,
    ["boolean"] = tostring,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


function json.encode(val)
    return (encode(val))
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[select(i, ...)] = true
    end
    return res
end

local space_chars  = create_set(" ", "\t", "\r", "\n")
local delim_chars  = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals     = create_set("true", "false", "null")

local literal_map  = {
    ["true"] = true,
    ["false"] = false,
    ["null"] = nil,
}


local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error(string.format("%s at line %d col %d", msg, line_count, col_count))
end


local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
            f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error(string.format("invalid unicode codepoint '%x'", n))
end


local function parse_unicode_escape(s)
    local n1 = tonumber(s:sub(1, 4), 16)
    local n2 = tonumber(s:sub(7, 10), 16)
    -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepoint_to_utf8(n1)
    end
end


local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
        local x = str:byte(j)

        if x < 32 then
            decode_error(str, j, "control character in string")
        elseif x == 92 then -- `\`: Escape
            res = res .. str:sub(k, j - 1)
            j = j + 1
            local c = str:sub(j, j)
            if c == "u" then
                local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                    or str:match("^%x%x%x%x", j + 1)
                    or decode_error(str, j - 1, "invalid unicode escape in string")
                res = res .. parse_unicode_escape(hex)
                j = j + #hex
            else
                if not escape_chars[c] then
                    decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                end
                res = res .. escape_char_map_inv[c]
            end
            k = j + 1
        elseif x == 34 then -- `"`: End of string
            res = res .. str:sub(k, j - 1)
            return res, j + 1
        end

        j = j + 1
    end

    decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end


local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end


local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
        local x
        i = next_char(str, i, space_chars, true)
        -- Empty / end of array?
        if str:sub(i, i) == "]" then
            i = i + 1
            break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end


local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
        local key, val
        i = next_char(str, i, space_chars, true)
        -- Empty / end of object?
        if str:sub(i, i) == "}" then
            i = i + 1
            break
        end
        -- Read key
        if str:sub(i, i) ~= '"' then
            decode_error(str, i, "expected string for key")
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
            decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        -- Read value
        val, i = parse(str, i)
        -- Set
        res[key] = val
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end


local char_func_map = {
    ['"'] = parse_string,
    ["0"] = parse_number,
    ["1"] = parse_number,
    ["2"] = parse_number,
    ["3"] = parse_number,
    ["4"] = parse_number,
    ["5"] = parse_number,
    ["6"] = parse_number,
    ["7"] = parse_number,
    ["8"] = parse_number,
    ["9"] = parse_number,
    ["-"] = parse_number,
    ["t"] = parse_literal,
    ["f"] = parse_literal,
    ["n"] = parse_literal,
    ["["] = parse_array,
    ["{"] = parse_object,
}


parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

-------------------------------------------------------------------------------
-- json.lua
-------------------------------------------------------------------------------

local SUPPORTED_KEYS_MAP = {
    ["0"] = 1,
    ["1"] = 2,
    ["2"] = 3,
    ["3"] = 4,
    ["4"] = 5,
    ["5"] = 6,
    ["6"] = 7,
    ["7"] = 8,
    ["8"] = 9,
    ["9"] = 10,
    ["A"] = 11,
    ["B"] = 12,
    ["C"] = 13,
    ["D"] = 14,
    ["E"] = 15,
    ["F"] = 16,
    ["G"] = 17,
    ["H"] = 18,
    ["I"] = 19,
    ["J"] = 20,
    ["K"] = 21,
    ["L"] = 22,
    ["M"] = 23,
    ["N"] = 24,
    ["O"] = 25,
    ["P"] = 26,
    ["Q"] = 27,
    ["R"] = 28,
    ["S"] = 29,
    ["T"] = 30,
    ["U"] = 31,
    ["V"] = 32,
    ["W"] = 33,
    ["X"] = 34,
    ["Y"] = 35,
    ["Z"] = 36,
    ["a"] = 37,
    ["b"] = 38,
    ["c"] = 39,
    ["d"] = 40,
    ["e"] = 41,
    ["f"] = 42,
    ["g"] = 43,
    ["h"] = 44,
    ["i"] = 45,
    ["j"] = 46,
    ["k"] = 47,
    ["l"] = 48,
    ["m"] = 49,
    ["n"] = 50,
    ["o"] = 51,
    ["p"] = 52,
    ["q"] = 53,
    ["r"] = 54,
    ["s"] = 55,
    ["t"] = 56,
    ["u"] = 57,
    ["v"] = 58,
    ["w"] = 59,
    ["x"] = 60,
    ["y"] = 61,
    ["z"] = 62,
}

local SUPPORTED_KEYS = {
    { on = "0" },
    { on = "1" },
    { on = "2" },
    { on = "3" },
    { on = "4" },
    { on = "5" },
    { on = "6" },
    { on = "7" },
    { on = "8" },
    { on = "9" },
    { on = "A" },
    { on = "B" },
    { on = "C" },
    { on = "D" },
    { on = "E" },
    { on = "F" },
    { on = "G" },
    { on = "H" },
    { on = "I" },
    { on = "J" },
    { on = "K" },
    { on = "L" },
    { on = "M" },
    { on = "N" },
    { on = "O" },
    { on = "P" },
    { on = "Q" },
    { on = "R" },
    { on = "S" },
    { on = "T" },
    { on = "U" },
    { on = "V" },
    { on = "W" },
    { on = "X" },
    { on = "Y" },
    { on = "Z" },
    { on = "a" },
    { on = "b" },
    { on = "c" },
    { on = "d" },
    { on = "e" },
    { on = "f" },
    { on = "g" },
    { on = "h" },
    { on = "i" },
    { on = "j" },
    { on = "k" },
    { on = "l" },
    { on = "m" },
    { on = "n" },
    { on = "o" },
    { on = "p" },
    { on = "q" },
    { on = "r" },
    { on = "s" },
    { on = "t" },
    { on = "u" },
    { on = "v" },
    { on = "w" },
    { on = "x" },
    { on = "y" },
    { on = "z" },
}

local _load_config = ya.sync(function(state, opts)
    state.save = {
        method = "yazi",
        yazi_load_event = "@projects-load",
        lua_save_path = "",
    }
    if type(opts.save) == "table" then
        if type(opts.save.method) == "string" then
            state.save.method = opts.save.method
        end
        if type(opts.save.yazi_load_event) == "string" then
            state.save.yazi_load_event = opts.save.yazi_load_event
        end
        if type(opts.save.lua_save_path) == "string" then
            state.save.lua_save_path = opts.save.lua_save_path
        else
            local lua_save_path
            local appdata = os.getenv("APPDATA")
            if appdata then
                lua_save_path = appdata:gsub("\\", "/") .. "/yazi/state/projects.json"
            else
                lua_save_path = os.getenv("HOME") .. "/.local/state/yazi/projects.json"
            end

            state.save.lua_save_path = lua_save_path
        end
    end

    state.last = {
        update_after_save = true,
        update_after_load = true,
        load_after_start = false,
    }
    if type(opts.last) == "table" then
        if type(opts.last.update_after_save) == "boolean" then
            state.last.update_after_save = opts.last.update_after_save
        end
        if type(opts.last.update_after_load) == "boolean" then
            state.last.update_after_load = opts.last.update_after_load
        end
        if type(opts.last.load_after_start) == "boolean" then
            state.last.load_after_start = opts.last.load_after_start
        end
    end

    state.merge = {
        event = "projects-merge",
        quit_after_merge = false,
    }
    if type(opts.merge) == "table" then
        if type(opts.merge.event) == "string" then
            state.merge.event = opts.merge.event
        end
        if type(opts.merge.quit_after_merge) == "boolean" then
            state.merge.quit_after_merge = opts.merge.quit_after_merge
        end
    end

    state.event = {
        save = {
            enable = true,
            name = "project-saved",
        },
        load = {
            enable = true,
            name = "project-loaded",
        },
        delete = {
            enable = true,
            name = "project-deleted",
        },
        delete_all = {
            enable = true,
            name = "project-deleted-all",
        },
        merge = {
            enable = true,
            name = "project-merged",
        },
    }
    if type(opts.event) == "table" then
        if type(opts.event.save) == "table" then
            if type(opts.event.save.enable) == "boolean" then
                state.event.save.enable = opts.event.save.enable
            end
            if type(opts.event.save.name) == "string" then
                state.event.save.name = opts.event.save.name
            end
        elseif type(opts.event.save) == "boolean" then
            state.event.save.enable = opts.event.save
        end
        if type(opts.event.load) == "table" then
            if type(opts.event.load.enable) == "boolean" then
                state.event.load.enable = opts.event.load.enable
            end
            if type(opts.event.load.name) == "string" then
                state.event.load.name = opts.event.load.name
            end
        elseif type(opts.event.load) == "boolean" then
            state.event.load.enable = opts.event.load
        end
        if type(opts.event.delete) == "table" then
            if type(opts.event.delete.enable) == "boolean" then
                state.event.delete.enable = opts.event.delete.enable
            end
            if type(opts.event.delete.name) == "string" then
                state.event.delete.name = opts.event.delete.name
            end
        elseif type(opts.event.delete) == "boolean" then
            state.event.delete.enable = opts.event.delete
        end
        if type(opts.event.delete_all) == "table" then
            if type(opts.event.delete_all.enable) == "boolean" then
                state.event.delete_all.enable = opts.event.delete_all.enable
            end
            if type(opts.event.delete_all.name) == "string" then
                state.event.delete_all.name = opts.event.delete_all.name
            end
        elseif type(opts.event.delete_all) == "boolean" then
            state.event.delete_all.enable = opts.event.delete_all
        end
        if type(opts.event.merge) == "table" then
            if type(opts.event.merge.enable) == "boolean" then
                state.event.merge.enable = opts.event.merge.enable
            end
            if type(opts.event.merge.name) == "string" then
                state.event.merge.name = opts.event.merge.name
            end
        elseif type(opts.event.merge) == "boolean" then
            state.event.merge.enable = opts.event.merge
        end
    end

    state.notify = {
        enable = true,
        title = "Projects",
        timeout = 3,
        level = "info",
    }
    if type(opts.notify) == "table" then
        if type(opts.notify.enable) == "boolean" then
            state.notify.enable = opts.notify.enable
        end
        if type(opts.notify.title) == "string" then
            state.notify.title = opts.notify.title
        end
        if type(opts.notify.timeout) == "number" then
            state.notify.timeout = opts.notify.timeout
        end
        if type(opts.notify.level) == "string" then
            state.notify.level = opts.notify.level
        end
    end
end)

local _notify = ya.sync(function(state, message)
    ya.notify({
        title = state.notify.title,
        content = message,
        timeout = state.notify.timeout,
        level = state.notify.level,
    })
end)

local _get_default_projects = ya.sync(function(state)
    return {
        list = {},
        last = nil,
    }
end)

local _get_projects = ya.sync(function(state)
    return not state.projects and _get_default_projects() or state.projects
end)

local _get_real_idx = ya.sync(function(state, idx)
    for real_idx, value in ipairs(_get_projects().list) do
        if value.on == SUPPORTED_KEYS[idx].on then
            return real_idx
        end
    end

    return nil
end)

local _get_current_project = ya.sync(function(state)
    local tabs = cx.tabs

    -- TODO: add more tab properties
    local project = {
        active_idx = tonumber(tabs.idx),
        tabs = {},
    }

    for index, tab in ipairs(tabs) do
        project.tabs[#project.tabs + 1] = {
            idx = index,
            cwd = tostring(tab.current.cwd):gsub("\\", "/"),
        }
    end

    return project
end)

local _save_projects = ya.sync(function(state, projects)
    state.projects = projects

    if state.save.method == "yazi" then
        ps.pub_to(0, state.save.yazi_load_event, projects)
    elseif state.save.method == "lua" then
        local f = io.open(state.save.lua_save_path, "w")
        if not f then
            return
        end
        f:write(json.encode(projects))
        io.close(f)
    end
end)

local save_project = ya.sync(function(state, idx, desc)
    local projects = _get_projects()

    local real_idx = _get_real_idx(idx)
    if not real_idx then
        real_idx = #projects.list + 1
    end

    local project = _get_current_project()
    projects.list[real_idx] = {
        on = SUPPORTED_KEYS[idx].on,
        desc = desc,
        project = project,
    }

    if state.last.update_after_save then
        projects.last = project
    end

    _save_projects(projects)

    if state.event.save.enable then
        ps.pub_to(0, state.event.save.name, project)
    end

    if state.notify.enable then
        local message = string.format("Project saved to %s", state.projects.list[real_idx].on)
        _notify(message)
    end
end)

local load_project = ya.sync(function(state, project, desc)
    -- TODO: add more tab properties to restore

    -- when cx is nil, it is called in setup
    if cx then
        for _ = 1, #cx.tabs - 1 do
            ya.emit("tab_close", { 0 })
        end
    end

    local sorted_tabs = {}
    for _, tab in pairs(project.tabs) do
        sorted_tabs[tonumber(tab.idx)] = tab
    end
    for _, tab in pairs(sorted_tabs) do
        ya.emit("tab_create", { tab.cwd })
    end

    ya.emit("tab_close", { 0 })
    ya.emit("tab_switch", { project.active_idx - 1 })

    if state.last.update_after_load then
        local projects = _get_projects()
        projects.last = project
        _save_projects(projects)
    end

    if state.event.load.enable then
        ps.pub_to(0, state.event.load.name, project)
    end

    if state.notify.enable then
        local message
        if desc then
            message = string.format([["%s" loaded]], desc)
        else
            message = string.format([[Last project loaded]], desc)
        end
        _notify(message)
    end
end)

local _load_projects = ya.sync(function(state)
    if state.save.method == "yazi" then
        ps.sub_remote(state.save.yazi_load_event, function(body)
            state.projects = body
        end)
    elseif state.save.method == "lua" then
        local f = io.open(state.save.lua_save_path, "r")
        if f then
            state.projects = json.decode(f:read("*a"))
            io.close(f)
        end
    end

    if not state.projects then
        state.projects = _get_default_projects()
    end

    if state.last.load_after_start then
        local last_project = _get_projects().last
        if last_project then
            load_project(last_project)
        end
    end
end)

local delete_all_projects = ya.sync(function(state)
    _save_projects(_get_default_projects())

    local msg = "All projects deleted"

    if state.event.delete_all.enable then
        ps.pub_to(0, state.event.delete_all.name, msg)
    end

    if state.notify.enable then
        _notify(msg)
    end
end)

local delete_project = ya.sync(function(state, idx)
    local projects = _get_projects()

    local message = string.format([["%s" deleted]], tostring(projects.list[idx].desc))

    local deleted_project = projects.list[idx]
    table.remove(projects.list, idx)
    _save_projects(projects)

    if state.event.delete.enable then
        ps.pub_to(0, state.event.delete.name, deleted_project)
    end

    if state.notify.enable then
        _notify(message)
    end
end)

local save_last_and_quit = ya.sync(function(state)
    local projects = _get_projects()
    local current_project = _get_current_project()
    projects.last = current_project

    _save_projects(projects)

    if state.event.save.enable then
        ps.pub_to(0, state.event.save.name, current_project)
    end

    ya.emit("quit", {})
end)

local merge_project = ya.sync(function(state, opt)
    local project = _get_current_project()
    project.opt = opt or "all"
    ps.pub_to(0, state.merge.event, project)

    if state.event.merge.enable then
        ps.pub_to(0, state.event.merge.name, project)
    end

    if state.merge.quit_after_merge then
        ya.emit("quit", {})
    end
end)

local _merge_tab = ya.sync(function(state, tab)
    ya.emit("tab_create", { tab.cwd })
end)

local _merge_event = ya.sync(function(state)
    ps.sub_remote(state.merge.event, function(body)
        if body then
            local active_idx = tonumber(cx.tabs.idx)

            local opt = body.opt
            if opt == "all" then
                local sorted_tabs = {}
                for _, tab in pairs(body.tabs) do
                    sorted_tabs[tonumber(tab.idx)] = tab
                end

                for _, tab in ipairs(sorted_tabs) do
                    _merge_tab(tab)
                end

                if state.notify.enable then
                    local message = "A project is merged"
                    _notify(message)
                end
            elseif opt == "current" then
                local tab = body.tabs[tonumber(body.active_idx)]
                _merge_tab(tab)

                if state.notify.enable then
                    local message = "A tab is merged"
                    _notify(message)
                end
            end

            ya.emit("tab_switch", { active_idx - 1 })
        end
    end)
end)

local _find_project_index = ya.sync(function(state, list, search_term)
    if not search_term then
        return nil
    end

    for i, project in ipairs(list) do
        -- Match the project by the "on" key or by "desc"
        if project.on == search_term or project.desc == search_term then
            return i
        end
    end

    return nil
end)

return {
    setup = function(_, opts)
        _load_config(opts)
        _load_projects()
        _merge_event()
    end,
    entry = function(_, job)
        local action = job.args[1]
        if not action then
            return
        end

        if action == "quit" then
            save_last_and_quit()
            return
        end

        if action == "delete_all" then
            delete_all_projects()
            return
        end

        if action == "merge" then
            local opt = job.args[2]
            merge_project(opt)
            return
        end

        local projects = _get_projects()

        if action == "load_last" then
            local last_project = projects.last
            if last_project then
                load_project(last_project)
            end
            return
        end

        local list = projects.list

        if action == "save" then
            -- load the desc of saved projects
            for _, value in pairs(list) do
                local idx = SUPPORTED_KEYS_MAP[value.on]
                if idx then
                    SUPPORTED_KEYS[idx].desc = value.desc
                end
            end

            local idx = ya.which({ cands = SUPPORTED_KEYS, silent = false })
            if not idx then
                return
            end

            -- if target is not empty, use the saved desc as default desc
            local default_desc
            if SUPPORTED_KEYS[idx].desc then
                default_desc = SUPPORTED_KEYS[idx].desc
            else
                default_desc = string.format("Project %s", SUPPORTED_KEYS[idx].on)
            end

            local value, event = ya.input({
                title = "Project name:",
                value = default_desc,
                position = { "center", w = 40 },
            })
            if event ~= 1 then
                return
            end

            local desc
            if value ~= "" then
                desc = value
            else
                desc = default_desc
            end

            save_project(idx, desc)
            return
        end

        local selected_idx = (
            -- Search for the project, if an argument was given
            _find_project_index(list, job.args[2])
            -- Ask interactively
            or ya.which({ cands = list, silent = false })
        )
        if not selected_idx then
            return
        end

        if action == "load" then
            local selected = list[selected_idx]
            load_project(selected.project, selected.desc)
        elseif action == "delete" then
            delete_project(selected_idx)
        end
    end,
}
