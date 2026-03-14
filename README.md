<div align="center">

```
                                           _
  __ _  __ _ _ __ _ __ _   _ ___   _ __  (_)_   ___ __ ___
 / _` |/ _` | '__| '__| | | / __| | '_ \ | \ \ / / '_ ` _ \
| (_| | (_| | |  | |  | |_| \__ \ | | | | |\ V /| | | | | |
 \__, |\__,_|_|  |_|   \__, |___/ |_| |_|_| \_/ |_| |_| |_|
 |___/                  |___/
```

**stop configuring neovim. write some code.**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1-blue?style=flat-square&logo=lua&logoColor=white)](https://lua.org)
[![License](https://img.shields.io/badge/License-MIT-orange?style=flat-square)](LICENSE)
[![Git](https://img.shields.io/badge/Git-2.19+-red?style=flat-square&logo=git&logoColor=white)](https://git-scm.com)

</div>

---

> *Garry's Mod shipped with everything. You spawned in and it just worked.*
> *Then you broke it. Then you fixed it. Then you made something nobody expected.*
>
> **garrys.nvim is that.**

---

## What it is

A plugin manager for Neovim that does the job and shuts up about it.

No framework. No abstraction maze. No config surface bigger than your actual project.
You give it a list of plugins. It installs them, loads them, and gets out of your way.

lazy.nvim is brilliant. It's also the size of a small country.
garrys.nvim fits in your head.

---

## Requirements

- **Neovim** `>= 0.10.0` - built with LuaJIT, uses `vim.system()` and `vim.uv` directly
- **Git** `>= 2.19.0` - for partial clones
- That's it

---

## Install

Drop this at the top of your `init.lua`:

```lua
vim.opt.rtp:prepend(vim.fn.expand("~/projects/garrys.nvim"))

require("garrys").setup({
  { "nvim-lua/plenary.nvim" },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "neovim/nvim-lspconfig", opts = {} },
  {
    "nvim-telescope/telescope.nvim",
    cmd     = "Telescope",
    depends = { "nvim-lua/plenary.nvim" },
  },
})
```

Open Neovim. Run `:GarryInstall`. Done.

---

## Spec Format

Every plugin is a table. The first field is always `"user/repo"`.

```lua
{
  "user/repo",              -- required. github shorthand.

  name    = "override",     -- optional. if the repo name sucks.
  lazy    = true,           -- don't load on startup
  event   = "BufReadPre",   -- load on this autocommand event
  cmd     = "SomeCommand",  -- load when this command is run
  ft      = "rust",         -- load for this filetype
  keys    = "<leader>ff",   -- load when this key is pressed

  depends = {               -- load these first
    "nvim-lua/plenary.nvim"
  },

  opts = {                  -- passed to plugin's setup()
    option = true,
  },

  config = function(opts)   -- or do it yourself
    require("plugin").setup(opts)
  end,

  build = ":TSUpdate",      -- run after install (string or function)
  pin   = true,             -- don't update this plugin
}
```

---

## Commands

| Command | What it does |
|---|---|
| `:GarryInstall` | Install every missing plugin |
| `:GarryUpdate` | Pull updates for all plugins |
| `:GarryClean` | Delete plugins not in your spec |
| `:GarryLock` | Write `garrys.lock` (pins every plugin to its current commit) |
| `:GarryRestore` | Roll back every plugin to its locked commit |
| `:GarryStatus` | Floating window (see what's installed, what's lazy, what's broken) |
| `:GarryList` | Quick cmdline summary |

---

## How it works

```
setup()
  └── normalize specs into plugin objects
  └── loader.load_all()
        └── vim.loader.enable()          -- bytecode cache, free startup speedup
        └── sort by dependencies
        └── eager plugins  → inject immediately
        └── lazy plugins   → register autocmd / stub command / keymap

:GarryInstall
  └── find plugins not on disk
  └── git clone --depth=1 --filter=blob:none  (async, concurrent)
  └── inject into rtp
  └── run build hook
  └── show progress in floating UI

:GarryLock
  └── git rev-parse HEAD for every plugin
  └── write garrys.lock (JSON)

:GarryRestore
  └── read garrys.lock
  └── git checkout <commit> for every plugin
```

---

## garrys.lock

Human-readable. Commit this.

```json
{
  "plenary.nvim": {
    "commit": "a3e3bc82a3f95c5ed0d7201546d5d2ece00051c6",
    "url": "https://github.com/nvim-lua/plenary.nvim.git"
  },
  "nvim-treesitter": {
    "commit": "f2778bd1a28b74adf5b1aa51aa57da85adfa3d16",
    "url": "https://github.com/nvim-treesitter/nvim-treesitter.git"
  }
}
```

---

## Why not lazy.nvim

| | lazy.nvim | garrys.nvim |
|---|---|---|
| Lines of code | ~5000+ | ~500 |
| Fits in your head | no | yes |
| Bytecode caching | yes | yes (`vim.loader`) |
| Lazy loading | yes | yes |
| Lockfile | yes | yes |
| Async installs | yes | yes |
| Built-in UI | elaborate | minimal floating window |
| Rockspec support | yes | no, and proud of it |
| Neovim target | 0.8+ | **0.10+ only** — no legacy weight |

lazy.nvim is an engineering achievement. garrys.nvim is a tool that does one thing.

---

## Structure

```
garrys.nvim/
├── lua/
│   └── garrys/
│       ├── init.lua       setup(), normalize(), plugin registry
│       ├── git.lua        clone, pull, get_commit, checkout
│       ├── loader.lua     rtp injection, lazy loading, bytecode cache
│       ├── lockfile.lua   write, read, restore garrys.lock
│       ├── ui.lua         floating status window
│       └── util.lua       logging, path helpers, dep sorting
└── plugin/
    └── garrys.lua         user commands
```

---

## Part of the Garry's ecosystem

garrys.nvim is the engine under **GarryVim** — a full Neovim framework with an addon system, typed Lua API, and LSP/formatting/linting configured out of the box.

But garrys.nvim stands alone. You don't need GarryVim to use it.

---

## License

MIT. Do whatever. Just don't blame me when you break it.

---

<div align="center">

*built with Neovim, on Arch, at an unreasonable hour*

</div>
