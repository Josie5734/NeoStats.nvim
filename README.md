# NeoStats.nvim

---

### Still in Development

This plugin is in development

It is functional but does not have all planned features implemented

---

NeoStats is a small and simple tracker for cool and interesting statistics in NeoVim

NeoStats tracks things like:

- a cool arbitrary xp bar and level system

- total number of characters written

- number of each individual character written

- time spent in a project

- words per minute

- potentially more things : )

Neostats autosaves every 30 seconds, or however many seconds you choose in the setup

The save file can be found at:

- linux: `~/.local/share/nvim/neostats/neostats.json`
- windows: `\AppData\Local\nvim-data\neostats\neostats.json`

Stats are tracked per project, using markers like .git to distinguish where projects are

---

### Installing:

#### Lazy:

```
return {
    "Josie5734/NeoStats.nvim"
    config = function()
        require("neostats").setup({
            --default opts, don't need to be included unless changing them
            markers = { --things to use as project markers
                ".git",
                "package.json",
                "pyproject.toml",
                "Cargo.toml",
                "go.mod",
                "Makefile",
                "stylua.toml",
                ".nvim.lua",
            },
            ignore = { --files/folders to ignore in counting
                [".git"] = true, --make sure string in [] and are = true
                ["node_modules"] = true,
                [".cache"] = true,
                ["dist"] = true,
                ["build"] = true,
            },
            autosave_interval = 30, --how often (in seconds) to save data to disk
            wpm = { --wpm counter
                cpw = 5, --characters per word
                countwin = 10, --seconds to count the wpm over
            },
        })
    end,
}
```

---

### Usage:

Keymaps:

- `<leader>ns` - toggles the mini XP window
- keymaps should be customisable in the future

Commands:

- `:NeoStats` - opens the main stats window
- `:NeoStats backup` - create a copy of `neostats.json` called `neostats_backup.json`
- `:NeoStats reset` - resets the stats for the current project

---

### Notes

The idea behind the level and xp system part of this plugin is inspired by the Godot plugin [Ridiculous Coding](https://github.com/jotson/ridiculous_coding)
