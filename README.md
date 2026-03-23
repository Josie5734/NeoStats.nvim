# NeoStats.nvim

---

### Still in Development

This plugin is in development

It is functional but with very minimal features

Currently, there is a functioning (but barebones) XP tracker and level system, which have not been tested for any kind of balancing

---

NeoStats is a small and simple tracker for cool and interesting statistics in NeoVim

NeoStats tracks things like:

- a cool arbitrary xp bar and level system

- total number of characters written

- number of each individual character written

- many more things that i have not thought of and/or got round to making yet 👍

Stats will be tracked per project and potentially globally depending on how things turn out, with as much customisability as possible

---

### Installing:

#### Lazy:

```
return {
    "Josie5734/NeoStats.nvim"
    config = function()
        require("neostats").setup()
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
- `:NeoStats reset` - resets the stats for the current project

---

### Features:

- cool XP and level system :0
- little window in the corner for seeing your xp and level in real time
- Track lots of stats like:
  - Total Characers Typed
  - How many of each individual character typed
  - The same but for deletions (coming soon)
  - Total time spent in project
  - Other cool stuff (coming soon)
- autosaving
- stats stored in a JSON file so you can do things like back-ups and cheating
  - unix - `~/.local/share/nvim/neostats/neostats.json`
  - windows - `\AppData\Local\nvim-data\neostats\neostats.json`

- Note: does not currently support having multiple instances of neovim open in the same project

---

### Notes

The idea behind the level and xp system part of this plugin is inspired by the Godot plugin [Ridiculous Coding](https://github.com/jotson/ridiculous_coding)
