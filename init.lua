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

local _save_projects = ya.sync(function(state, projects)
    state.projects = projects
    ps.pub_static(10, "projects", projects)
end)

local _load_projects = ya.sync(function(state)
    ps.sub_remote("projects", function(body)
        if not state.projects and body then
            state.projects = _get_default_projects()

            for _, value in pairs(body.list) do
                state.projects.list[#state.projects.list + 1] = value
            end

            state.projects.last = body.last
        end
    end)
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
            cwd = tostring(tab.current.cwd),
        }
    end

    return project
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

    if state.notify.enable then
        local message = string.format("Project saved to %s", state.projects.list[real_idx].on)
        _notify(message)
    end
end)

local load_project = ya.sync(function(state, project, desc)
    -- TODO: add more tab properties to restore

    for _ = 1, #cx.tabs - 1 do
        ya.manager_emit("tab_close", { 0 })
    end

    local sorted_tabs = {}
    for _, tab in pairs(project.tabs) do
        sorted_tabs[tonumber(tab.idx)] = tab
    end
    for _, tab in pairs(sorted_tabs) do
        ya.manager_emit("tab_create", { tab.cwd })
    end

    ya.manager_emit("tab_close", { 0 })
    ya.manager_emit("tab_switch", { project.active_idx - 1 })

    if state.last.update_after_load then
        local projects = _get_projects()
        projects.last = project
        _save_projects(projects)
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

local delete_all_projects = ya.sync(function(state)
    _save_projects(nil)

    if state.notify.enable then
        local message = "All projects deleted"
        _notify(message)
    end
end)

local delete_project = ya.sync(function(state, idx)
    local projects = _get_projects()

    local message = string.format([["%s" deleted]], tostring(projects.list[idx].desc))

    table.remove(projects.list, idx)
    _save_projects(projects)

    if state.notify.enable then
        _notify(message)
    end
end)

local save_last_and_quit = ya.sync(function(state)
    local projects = _get_projects()
    projects.last = _get_current_project()

    _save_projects(projects)

    ya.manager_emit("quit", {})
end)

local merge_project = ya.sync(function(state, opt)
    local project = _get_current_project()
    project.opt = opt or "all"
    ps.pub_to(0, "projects-merge", project)

    if state.merge.quit_after_merge then
        ya.manager_emit("quit", {})
    end
end)

local _merge_tab = ya.sync(function(state, tab)
    ya.manager_emit("tab_create", { tab.cwd })
end)

local _merge_event = ya.sync(function(state)
    ps.sub_remote("projects-merge", function(body)
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
                local tab = body.tabs[tostring(body.active_idx)]
                _merge_tab(tab)

                if state.notify.enable then
                    local message = "A tab is merged"
                    _notify(message)
                end
            end

            ya.manager_emit("tab_switch", { active_idx - 1 })
        end
    end)
end)

return {
    entry = function(_, args)
        local action = args[1]
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
            local opt = args[2]
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

        local selected_idx = ya.which({ cands = list, silent = false })
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
    setup = function(state, args)
        state.last = {
            update_after_save = true,
            update_after_load = true,
        }
        if type(args.last) == "table" then
            if type(args.last.update_after_save) == "boolean" then
                state.last.update_after_save = args.last.update_after_save
            end
            if type(args.last.update_after_load) == "boolean" then
                state.last.update_after_load = args.last.update_after_load
            end
        end

        state.merge = {
            quit_after_merge = false,
        }
        if type(args.merge) == "table" then
            if type(args.merge.quit_after_merge) == "boolean" then
                state.merge.quit_after_merge = args.merge.quit_after_merge
            end
        end

        state.notify = {
            enable = true,
            title = "Projects",
            timeout = 3,
            level = "info",
        }
        if type(args.notify) == "table" then
            if type(args.notify.enable) == "boolean" then
                state.notify.enable = args.notify.enable
            end
            if type(args.notify.title) == "string" then
                state.notify.title = args.notify.title
            end
            if type(args.notify.timeout) == "number" then
                state.notify.timeout = args.notify.timeout
            end
            if type(args.notify.level) == "string" then
                state.notify.level = args.notify.level
            end
        end

        _load_projects()
        _merge_event()
    end,
}
