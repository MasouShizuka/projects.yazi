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
ya pkg add MasouShizuka/projects
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
[[mgr.prepend_keymap]]
on = [ "P", "s" ]
run = "plugin projects save"
desc = "Save current project"

[[mgr.prepend_keymap]]
on = [ "P", "l" ]
run = "plugin projects load"
desc = "Load project"

[[mgr.prepend_keymap]]
on = [ "P", "P" ]
run = "plugin projects load_last"
desc = "Load last project"

[[mgr.prepend_keymap]]
on = [ "P", "d" ]
run = "plugin projects delete"
desc = "Delete project"

[[mgr.prepend_keymap]]
on = [ "P", "D" ]
run = "plugin projects delete_all"
desc = "Delete all projects"

[[mgr.prepend_keymap]]
on = [ "P", "m" ]
run = "plugin projects 'merge current'"
desc = "Merge current tab to other projects"

[[mgr.prepend_keymap]]
on = [ "P", "M" ]
run = "plugin projects 'merge all'"
desc = "Merge current project to other projects"
```

If you want to save the last project when exiting, map the default `quit` key to:

```toml
[[mgr.prepend_keymap]]
on = [ "q" ]
run = "plugin projects quit"
desc = "Save last project and exit the process"
```

---

Don't forget to add the plugin's `setup` function in Yazi's `init.lua`, i.e. `~/.config/yazi/init.lua`.
The following are the default configurations:

```lua
require("projects"):setup({
    save = {
        method = "yazi", -- yazi | lua
        yazi_load_event = "@projects-load", -- event name when loading projects in `yazi` method
        lua_save_path = "", -- path of saved file in `lua` method, comment out or assign explicitly
                            -- default value:
                            -- windows: "%APPDATA%/yazi/state/projects.json"
                            -- unix: "~/.local/state/yazi/projects.json"
    },
    last = {
        update_after_save = true,
        update_after_load = true,
        load_after_start = false,
    },
    merge = {
        event = "projects-merge",
        quit_after_merge = false,
    },
    event = {
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
    },
    notify = {
        enable = true,
        title = "Projects",
        timeout = 3,
        level = "info",
    },
})
```

> [!NOTE]
> Settings that are not set will use the default value.

### `save`

> [!NOTE]
> Yazi's api sometimes doesn't work on Windows, which is why the `lua` method is proposed

`method`: the method of saving projects:
- `yazi`: using `yazi` api to save to `.dds` file
- `lua`: using `lua` api to save

`yazi_load_event`: event name when loading projects in `yazi` method

`lua_save_path`: path of saved file in `lua` method, the defalut value is
- `Windows`: `%APPDATA%/yazi/state/projects.json`
- `Unix`: `~/.local/state/yazi/projects.json`

### `last`

The last project is loaded by `load_last` command.

`update_after_save`: the saved project will be saved to last project.

`update_after_load`: the loaded project will be saved to last project.

`load_after_start`: the last project will be loaded after starting.
- Only work with `lua` method, please refer to [#2](https://github.com/MasouShizuka/projects.yazi/issues/2)

### `merge`

`event`: the name of event used by merge feature.

`quit_after_merge`: the merged project will be exited after merging.

### `event`

The corresponding event will be sent when the corresponding function is executed.

For specific usage, please refer to [#5](https://github.com/MasouShizuka/projects.yazi/issues/5) and [#12](https://github.com/MasouShizuka/projects.yazi/issues/12).

### `notify`

When enabled, notifications are displayed when actions are performed.

`title`, `timeout`, `level` are the same as [ya.notify](https://yazi-rs.github.io/docs/plugins/utils/#ya.notify).

### Optional configuration

If you want to load a specific project with a keybinding (you can use either the key or the name of the project):

```toml
[[mgr.prepend_keymap]]
on = [ "P", "p" ]
run = "plugin projects 'load SomeProject'"
desc = "Load the 'SomeProject' project"
```

You can also load a specific project by using the below Bash/Zsh function (uses the "official" [shell wrapper](https://yazi-rs.github.io/docs/quick-start/#shell-wrapper), but you can also replace `y` with `yazi`):

```bash
function yap() {
    local yaziProject="$1"
    shift
    if [ -z "$yaziProject" ]; then
        >&2 echo "ERROR: The first argument must be a project"
        return 64
    fi
    
    # Generate random Yazi client ID (DDS / `ya emit` uses `YAZI_ID`)
    local yaziId=$RANDOM
    
    # Use Yazi's DDS to run a plugin command after Yazi has started
    # (the nested subshell is only to suppress "Done" output for the job)
    ( (sleep 0.1; YAZI_ID=$yaziId ya emit plugin projects "load $yaziProject") &)
    
    # Run Yazi with the generated client ID
    y --client-id $yaziId "$@" || return $?
}
```

With the above function you can open a specific project by running e.g. `yap SomeProject`
