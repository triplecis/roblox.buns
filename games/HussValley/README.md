# Huss Valley modules

`10764627709.lua` is the entry point registered in the loader under universe ID
`10764627709`. It creates the sections below and loads their files from
`modules/`, with shared data and camera helpers in `modules/runtime.lua`.

Research checked October 6, 2026:

- [Know Your Meme](https://knowyourmeme.com/memes/huss-valley) describes Huss Valley
  as a fictional chase setting. The proposed origin of "huss" is the sound of
  heavy breathing while running.
- This template targets [Huss Valley by Huss Valley Official](https://www.roblox.com/games/107535308163741/Huss-Valley).
  The similarly named Ve3 and Escape Huss Valley experiences have different mechanics.
- The module categories are our organization choice based on
  [Pro Game Guides' gameplay reporting](https://progameguides.com/roblox/complete-huss-valley-beginners-guide-movement-abilities-consumables/).
  The official description is brief; implementation details still need in-game verification.

| Section | File | Current functions |
| --- | --- | --- |
| Rounds | `rounds.lua` | Role counts, server uptime, exposed round metadata, manual refresh |
| Runners | `runners.lua` | Live roster, selection, spectate and stop |
| Catchers | `chasers.lua` | Live roster, selection, spectate and stop |
| Movement | `movement.lua` | Speed/state/dash telemetry, dash input, native profile reader, FOV, automatic turning |
| Abilities | `abilities.lua` | Definition browsing, selections, exposed ability attributes |
| Consumables | `consumables.lua` | Definition browsing, selections, carried tools, exposed consumable attributes |
| Rewards | `rewards.lua` | Public leaderboard stats, net session changes, reset baseline |

The monitor refreshes every half second. Catalog scans run at startup and from
the refresh buttons. Spectating follows active characters and restores the
previous camera when stopped, the target leaves, or the hub unloads. FOV and
turning controls also restore their previous values on disable or unload.

The supplied `CharacterMovementClient`, `MovementProfiles`, and `BoostInput`
decompilations establish these movement bindings:

- Roles are read from the player's `GameRole` attribute: `Runner` and
  `Catcher`. This overrides legacy `Role`/team guesses. The internal
  `Sections.Chasers` and selection flags retain their names for compatibility.
- Movement telemetry comes from character attributes such as `MovementState`,
  `MovementSpeed`, `DashReady`, `DashCooldownUntil`, `DashCount`, and
  `LastDashDistance`. Cooldown timestamps use the client's `os.clock()`.
- **Read movement profile** loads
  `ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles` and calls
  `get(GameRole, Player)`. The returned frozen profile is read for display.
- **Request dash** uses the live `Movement.BoostInput.available(Player)` and
  `request(touchStyle)`. This queues input for the existing character
  controller. Cooldowns, movement locks, and native availability checks apply.
  Module errors are reported. The optional V shortcut ignores processed input
  and typing; touch-style input passes the request boolean used by the controller.

The decompiled availability function contains suspicious Model/Humanoid
references, and the profile modifier expressions also need verification.
Integration uses the live modules rather than reconstructing those expressions.
`MovementConfig`, `MovementModel`, and `ControlGate` are the useful next
sources for tuning and interpreting the remaining movement behavior.

Ability/item schemas are still discovery conventions. Catalogs search
`ReplicatedStorage` folders named `Abilities`, `RunnerAbilities`,
`CatcherAbilities`, `ChaserAbilities`, or `Consumables`. They list nested
ModuleScript, Model, Tool, and ValueBase definitions without executing them.
Selections support browsing; equipping, buying, and using items require verified
game bindings. The carried-tools list covers Backpack and character Tools.

Round metadata uses matching root attributes and named round-state folders;
public stats use the standard `leaderstats` folder. Missing data shows as
unavailable. These features need live-game verification. The native movement
controller writes WalkSpeed every render step and configures jump state, so
generic Universal movement overrides may be overwritten by it.

To add a feature:

1. Edit the appropriate module, or add a file and an entry in the `Modules` table.
2. Access its section through `Context.Sections.<Name>`.
3. Store shared feature state in `Context.State` and prefix UI flags with
   `HussValley` to avoid collisions with universal controls.
4. Use `Context.Connect` for event listeners and `Context.AddCleanup` for
   restoring modified values or disposing of other resources.

Each module returns `function(Context)`. The context inherits `Player`,
`Library`, `Window`, `Pages`, IDs, and the loader helpers. The root context
also exposes the game context as `Context.HussValley`.

Runtime helpers include `RefreshData()`, `RefreshCatalogs()`,
`Subscribe(callback)`, `GetRole(player)`, `SpectatePlayer(player)`,
`StopSpectating()`, `ReadMovementProfile()`, and `RequestDash(touchStyle)`.
The latest data is in `Context.State.Snapshot`.

For example, Runner controls go in `modules/runners.lua` and use
`Context.Sections.Runners`. Keep shared movement and equipment in their
respective modules rather than duplicating them in both role modules.

Universal movement, the player roster, and UI settings already load separately.
Upload the template files together with the updated loader to the repository
used by `MyFullUrl` before trying the template in a live session.
