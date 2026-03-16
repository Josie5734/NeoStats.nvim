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

- total number characters written

- number of each individual character written

- many more things that i have not thought of yet 👍

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

- `:NeoStats` - currently does nothing on its own but will be the way to open the main window once implemented
- ` NeoStats reset` - resets the stats for the current project

---

### Notes

The idea behind the level and xp system part of this plugin is inspired by the Godot plugin [Ridiculous Coding](https://github.com/jotson/ridiculous_coding)
