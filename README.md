# projects.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin that adds the functionality to save, load and merge projects.
A project means all `tabs` and their status, including `cwd` and so on.

> [!NOTE]
> The latest release of Yazi is required at the moment.

https://github.com/MasouShizuka/projects.yazi/assets/44764707/79c3559a-7776-48cd-8317-dd1478314eed

## Features

 - Save/load projects
 - Load last project
 - Projects persistence
 - Merge a project or its current tab to other projects

## Installation

```sh
ya pack -a MasouShizuka/projects
```

or

```sh
# Windows
git clone https://github.com/MasouShizuka/projects.yazi.git %AppData%\yazi\config\plugins\projects.yazi

# Linux/macOS
git clone https://github.com/MasouShizuka/projects.yazi.git ~/.config/yazi/plugins/projects.yazi
```

## Configuration

Add this to your `keymap.toml`:

```toml
[[manager.prepend_keymap]]
on = [ "P", "s" ]
run = "plugin projects save"
desc = "Save current project"

[[manager.prepend_keymap]]
on = [ "P", "l" ]
run = "plugin projects load"
desc = "Load project"

[[manager.prepend_keymap]]
on = [ "P", "P" ]
run = "plugin projects load_last"
desc = "Load last project"

[[manager.prepend_keymap]]
on = [ "P", "d" ]
run = "plugin projects delete"
desc = "Delete project"

[[manager.prepend_keymap]]
on = [ "P", "D" ]
run = "plugin projects delete_all"
desc = "Delete all projects"

[[manager.prepend_keymap]]
on = [ "P", "m" ]
run = "plugin projects 'merge current'"
desc = "Merge current tab to other projects"

[[manager.prepend_keymap]]
on = [ "P", "M" ]
run = "plugin projects 'merge all'"
desc = "Merge current project to other projects"
```

If you want to save the last project when exiting, map the default `quit` key to:

```toml
[[manager.prepend_keymap]]
on = [ "q" ]
run = "plugin projects quit"
desc = "Save last project and exit the process"
```

---

Additionally there are configurations that can be done using the plugin's `setup` function in Yazi's `init.lua`, i.e. `~/.config/yazi/init.lua`.
The following are the default configurations:

```lua
require("projects"):setup({
    save = {
        method = "yazi", -- yazi | lua
        lua_save_path = "", -- comment out to get the default value
                            -- windows: "%APPDATA%/yazi/state/projects.json"
                            -- unix: "~/.local/state/yazi/projects.json"
    },
    last = {
        update_after_save = true,
        update_after_load = true,
        load_after_start = false,
    },
    merge = {
        quit_after_merge = false,
    },
    notify = {
        enable = true,
        title = "Projects",
        timeout = 3,
        level = "info",
    },
})
```

### `save`

> [!NOTE]
> Yazi's api sometimes doesn't work on Windows, which is why the `lua` method is proposed

`method`: the method of saving projects:
- `yazi`: using `yazi` api to save to `.dds` file
- `lua`: using `lua` api to save

`lua_save_path`: the path of saved file with lua api, the defalut is
- `Windows`: `%APPDATA%/yazi/state/projects.json`
- `Unix`: `~/.local/state/yazi/projects.json`

### `last`

The last project is loaded by `load_last` command.

`update_after_save`: the saved project will be saved to last project.

`update_after_load`: the loaded project will be saved to last project.

`load_after_start`: the last project will be loaded after starting.
- Only work with `lua` method, please refer to [#2](https://github.com/MasouShizuka/projects.yazi/issues/2)

### `merge`

`quit_after_merge`: the merged project will be exited after merging.

### `notify`

When enabled, notifications are displayed when actions are performed.

`title`, `timeout`, `level` are the same as [ya.notify](https://yazi-rs.github.io/docs/plugins/utils/#ya.notify).
