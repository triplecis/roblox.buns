# roblox.buns

A modular Luau client hub using MentalityUI. Refinery Caves 2 is registered under
universe ID `4298676072`; other games receive the universal pages.

Run `loader.lua` in a client environment that provides `game:HttpGet`,
`loadstring`, and the filesystem/custom-asset APIs required by MentalityUI.
This is not a standalone Roblox Studio LocalScript.

The loader downloads project modules from `triplecis/roblox.buns` on GitHub's
`main` branch. Local edits must be uploaded there, or `MyFullUrl` must point
to a hosted copy, before those edits appear in a live session. The UI library is
pinned to commit `4f5c7733335bd6576f9fbda7931e8838b1eb8d39`; check its API
when updating that pin.

Available features:

- Walk speed as a percentage increase over the game's current baseline.
- Separate jump power and jump height controls, with the active mode displayed.
- Movement controls that rebind on respawn and restore values when disabled or
  the hub is unloaded.
- A live server player roster with multiple selections.
- RC2 ore, tree, fish, oil, and item catalogs with a refresh button.
- RC2 server time from `workspace.ServerData.CurrentCycle.ClockTime`.
- Appearance, keybind, and config controls through the UI Settings page.
  Configs are stored under `roblox.buns/Configs/<GameId>`.

RC2 catalogs read the direct children of `ReplicatedStorage.Content` folders.
Resource names containing `bush` (case insensitive) are excluded. Fish require
matching names in both `BigFish` and `Items`. Oil definitions are read from
an optional `Oils` folder. Missing folders produce empty lists; use
**Refresh resources** after content arrives. These folder assumptions still
need verification against the live game.

World, vehicle, base, and automation tools are unfinished. The Buy section
currently browses item definitions; purchasing is not implemented. No additional
external scripts are configured.

Every module returns `function(Context)`. Common helpers are
`Context.LoadModule(path, optionalContext)`, `Context.Notify(title, description)`,
`Context.Connect(signal, callback)`, and `Context.AddCleanup(callback)`.
Use these helpers to report loading failures and disconnect listeners on unload.
RC2 modules also receive `Sections`, `Catalog`, and `Selections`.

Install the official [Luau CLI](https://github.com/luau-lang/luau/releases) and
run the compile and regression checks from PowerShell:

```powershell
.\tests\run.ps1
```

For binaries outside PATH:

```powershell
.\tests\run.ps1 -Luau C:\tools\luau.exe -Compiler C:\tools\luau-compile.exe
```

The regression suite executes the real local sources with mocked Roblox/UI
objects. It checks movement baselines, immediate and deferred signals, respawns,
module failures, content refreshes, player joins/leaves, clock formatting, and
cleanup. It does not render the UI or connect to a live Roblox server.
