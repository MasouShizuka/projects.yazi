# projects.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin that adds the functionality to save and load projects.
A project means all `tabs` and their status, including `cwd` and so on.

> [!NOTE]
> The latest main branch of Yazi is required at the moment.

https://github.com/MasouShizuka/projects.yazi/assets/44764707/79c3559a-7776-48cd-8317-dd1478314eed

## Features

 - Save/load projects
 - Load last project
 - Projects persistence

## Installation

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
run = "plugin projects --args=save"
desc = "Save current project"

[[manager.prepend_keymap]]
on = [ "P", "l" ]
run = "plugin projects --args=load"
desc = "Load project"

[[manager.prepend_keymap]]
on = [ "P", "P" ]
run = "plugin projects --args=load_last"
desc = "Load last project"

[[manager.prepend_keymap]]
on = [ "P", "d" ]
run = "plugin projects --args=delete"
desc = "Delete project"

[[manager.prepend_keymap]]
on = [ "P", "D" ]
run = "plugin projects --args=delete_all"
desc = "Delete all projects"
```

If you want to save the last project when exiting, map the default `quit` key to:

```toml
[[manager.prepend_keymap]]
on = [ "q" ]
run = "plugin projects --args=quit"
desc = "Save last project and exit the process"
```

---

Additionally there are configurations that can be done using the plugin's `setup` function in Yazi's `init.lua`, i.e. `~/.config/yazi/init.lua`.
The following are the default configurations:

```lua
require("projects"):setup({
    last = {
        update_after_save = true,
        update_after_load = true,
    },
    notify = {
        enable = true,
        title = "Projects",
        timeout = 3,
        level = "info",
    },
})
```

### `last`

The last project is loaded by `load_last` command.

When `update_after_save` enabled, the saved project will be saved to last project.
When `update_after_load` enabled, the loaded project will be saved to last project.

### `notify`

When enabled, notifications will be shown when the user saves/loads/deletes a project and deletes all projects.

`title`, `timeout`, `level` are the same as [ya.notify](https://yazi-rs.github.io/docs/plugins/utils/#ya.notify).
