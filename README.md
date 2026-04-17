<div align="center">

```
 ________  ________  ________  ________      ___    ___ ________       ________   ___      ___ ___  _____ ______      
|\   ____\|\   __  \|\   __  \|\   __  \    |\  \  /  /|\   ____\     |\   ___  \|\  \    /  /|\  \|\   _ \  _   \    
\ \  \___|\ \  \|\  \ \  \|\  \ \  \|\  \   \ \  \/  / | \  \___|_    \ \  \\ \  \ \  \  /  / | \  \ \  \\\__\ \  \   
 \ \  \  __\ \   __  \ \   _  _\ \   _  _\   \ \    / / \ \_____  \    \ \  \\ \  \ \  \/  / / \ \  \ \  \\|__| \  \  
  \ \  \|\  \ \  \ \  \ \  \\  \\ \  \\  \|   \/  /  /   \|____|\  \  __\ \  \\ \  \ \    / /   \ \  \ \  \    \ \  \ 
   \ \_______\ \__\ \__\ \__\\ _\\ \__\\ _\ __/  / /       ____\_\  \|\__\ \__\\ \__\ \__/ /     \ \__\ \__\    \ \__\
    \|_______|\|__|\|__|\|__|\|__|\|__|\|__|\___/ /       |\_________\|__|\|__| \|__|\|__|/       \|__|\|__|     \|__|
                                           \|___|/        \|_________|                                                
                                                                                                                      
                                                                                                                      
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
You give it a list of plugins. It installs them, loads them fast, and gets out of your way.

lazy.nvim is brilliant. garrys.nvim fits in your head.

---

## Requirements

- **Neovim** `>= 0.10.0` LuaJIT, uses `vim.system()` and `vim.uv` directly
- **Git** `>= 2.19.0`
- That's it

---

## Install

Paste this at the top of your `~/.config/nvim/init.lua`. garrys.nvim bootstraps itself.

```lua
-- bootstrap garrys.nvim
local path = vim.fn.stdpath("data") .. "/garrys/garrys.nvim"

if not (vim.uv or vim.loop).fs_stat(path) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/ihave17bucks/garrys.nvim.git",
    path,
  })

  if vim.v.shell_error ~= 0 then
    error("Failed to clone garrys.nvim:\n" .. out)
  end
end

vim.opt.rtp:prepend(path)

require("garrys").setup({
  { import = "plugins" },
})
```

> Installs to `~/.local/share/nvim/garrys/garrys.nvim`. Remove anytime with
> `rm -rf ~/.local/share/nvim/garrys`.

---

## Usage

```lua
require("garrys").setup({
  { "nvim-lua/plenary.nvim" },
  { "nvim-treesitter/nvim-treesitter", make = ":TSUpdate" },
  { "neovim/nvim-lspconfig",           opts = {}          },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dep = { "nvim-lua/plenary.nvim" },
  },
})
```

Missing plugins install automatically on first launch. No `:GarryInstall` needed.

---

## Spec Format

```lua
{
  "user/repo",              -- required. github shorthand.

  name  = "override",       -- if the repo name sucks
  lazy  = true,             -- don't load on startup
  event = "BufReadPre",     -- load on this autocmd event
  cmd   = "SomeCommand",    -- load when this command runs
  ft    = "rust",           -- load for this filetype
  keys  = "<leader>ff",     -- load when this key is pressed
  cond  = function()        -- skip plugin if returns false
    return vim.fn.executable("rg") == 1
  end,

  dep   = {                 -- load these first (strict by default)
    "nvim-lua/plenary.nvim"
  },

  opts  = { option = true }, -- passed to plugin's setup()
  on    = function(opts)     -- or configure it yourself
    require("plugin").setup(opts)
  end,

  make  = ":TSUpdate",       -- run after install
  pin   = true,              -- never update this plugin
}
```

> `dep`, `on`, `make` are short aliases for `depends`, `config`, `build`.
> Both work. Pick what you like.

---

## Multi-file config

Drop files in `~/.config/nvim/lua/plugins/` and garrys.nvim discovers them automatically:

```
lua/plugins/
├── ui.lua       -- return { { "catppuccin/nvim", ... }, ... }
├── lsp.lua      -- return { { "neovim/nvim-lspconfig" }, ... }
├── tools.lua    -- return { { "nvim-telescope/telescope.nvim", ... } }
└── coding.lua   -- return { { "hrsh7th/nvim-cmp", ... } }
```

Each file returns a table of specs. Explicit specs in `setup({})` take priority.

---

## Commands

| Command | What it does |
|---|---|
| `:GarryInstall` | Install every missing plugin |
| `:GarryUpdate` | Pull updates for all plugins |
| `:GarryClean` | Delete plugins not in your spec |
| `:GarryStatus` | Open the tabbed HUD window |
| `:GarryLock` | Write `garrys.lock` pin every plugin to its current commit |
| `:GarryRestore` | Roll back every plugin to its locked commit |
| `:GarryHealth` | Check every plugin on disk, valid repo, loadable, require() |
| `:GarryProfile` | Show startup load time ranked per plugin |
| `:GarryDiff` | Show what commits changed per plugin since last update |
| `:GarrySearch <query>` | Search GitHub, pick a result, install it live |
| `:GarryMigrate [file]` | Convert a lazy.nvim spec + validate output |
| `:GarryValidate` | Check all declared deps are in your spec |
| `:GarryList` | Quick cmdline summary |

---

## The UI

Open with `:GarryStatus` or any install/update command.

```
┌────────────────────────────────────────────────────────────┐
│                       garrys.nvim                          │
│                    4 plugins  0.84s                        │
├────────────────────────────────────────────────────────────┤
│  ▌  Installed  ▐     Updates        Log                    │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ ✔ plenary.nvim                  installed                  │
│ ✔ nvim-treesitter               installed                  │
│ ▶ nvim-lspconfig                installing                │
│ □ telescope.nvim                missing                    │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ ██████████████████████░░░░░░░░  75%                        │
│ plugins: 4  ok: 2                                          │
│ done  —  1/2/3 switch tabs  —  q close                     │
└────────────────────────────────────────────────────────────┘
```

Keys: `1` Installed · `2` Updates · `3` Log · `<Tab>` cycle · `q` close

---

## Lockfile

```json
{
  "plenary.nvim": {
    "commit": "a3e3bc82a3f95c5ed0d7201546d5d2ece00051c6",
    "url": "https://github.com/nvim-lua/plenary.nvim.git"
  }
}
```

`:GarryLock` to write it. `:GarryRestore` to roll back. Commit it to your dotfiles.

---

## Migrating from lazy.nvim

```
:GarryMigrate ~/.config/nvim/lua/plugins.lua
```

Converts your lazy.nvim spec, renames `dependencies` → `dep`, drops unsupported fields,
validates deps, and tells you exactly what's missing. One command.

---

## How it works

```
setup()
  └── discover plugin modules from lua/plugins/
  └── normalize all specs
  └── strict dep validation — errors if deps aren't declared
  └── loader.load_all()
        └── vim.loader.enable()       -- free bytecode cache
        └── sort by dep graph
        └── eager → inject into rtp
        └── lazy  → register autocmd / stub cmd / keymap
  └── autoinstall missing on VimEnter

:GarryInstall
  └── git clone --depth=1 --filter=blob:none  (async, concurrent)
  └── inject into rtp
  └── run make hook
  └── HUD progress bar updates live
```

---

## File structure

```
garrys.nvim/
├── lua/garrys/
│   ├── init.lua       setup(), plug(), load(), autoinstall
│   ├── git.lua        clone, pull, get_commit, checkout
│   ├── loader.lua     rtp injection, lazy loading, bytecode cache
│   ├── lockfile.lua   write, read, restore garrys.lock
│   ├── ui.lua         tabbed HUD — Installed / Updates / Log
│   ├── util.lua       logging, path helpers, dep sorting
│   ├── profile.lua    startup time tracking per plugin
│   ├── diff.lua       git log since last update
│   ├── search.lua     GitHub API search + install
│   ├── migrate.lua    lazy.nvim → garrys.nvim conversion
│   └── addon/
│       └── lua.lua    EmmyLua types for the garrys.nvim API
└── plugin/
    └── garrys.lua     all user commands
```

---

## vs lazy.nvim

| | lazy.nvim | garrys.nvim |
|---|---|---|
| Lines of code | ~5000+ | ~800 |
| Fits in your head | no | yes |
| Bytecode caching | yes | yes |
| Lazy loading | yes | yes |
| Lockfile | yes | yes |
| Async installs | yes | yes |
| Tabbed UI | yes | yes |
| Plugin search | no | yes (`:GarrySearch`) |
| Startup profiler | yes | yes (`:GarryProfile`) |
| Diff view | no | yes (`:GarryDiff`) |
| Health checks | no | yes (`:GarryHealth`) |
| Migration tool | no | yes (`:GarryMigrate`) |
| Strict dep graph | no | yes |
| Rockspec support | yes | no, and proud of it |
| Neovim target | 0.8+ | **0.10+ only** |

---

## Part of the Garry's ecosystem

garrys.nvim is the engine under **GarryVim** a full Neovim distribution built on this plugin manager with an addon system, typed Lua API, and LSP/formatting/linting configured out of the box.

But garrys.nvim stands alone. You don't need GarryVim to use it.

---

## License

MIT. Do whatever. Just don't blame me when you break it.

---

<div align="center">

*built with Neovim, on Arch, at an unreasonable hour*

</div>
