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
| Rounds | `rounds.lua` | Session phase/pause/map changes, role counts, server uptime, round metadata, manual refresh |
| Runners | `runners.lua` | Live roster, selection, spectate and stop |
| Catchers | `chasers.lua` | Live roster, selection, spectate and stop |
| Catchers | `tackle.lua` | Native tackle request, variant/motion/cooldown telemetry, local prediction box editing |
| Movement | `movement.lua` | Speed/state/recovery telemetry, gated dash input, config/profile details, FOV, automatic turning |
| Movement | `sprint.lua` | Native profile sprint, Shift/always modes, adjustable speed increase |
| Hitboxes | `hitboxes.lua` | Character-part discovery, player selection, local size editing, previews, restoration |
| Abilities | `abilities.lua` | Definition browsing, selections, exposed ability attributes |
| Consumables | `consumables.lua` | Definition browsing, selections, carried tools, exposed consumable attributes |
| Rewards | `rewards.lua` | Public leaderboard stats, net session changes, reset baseline |

The monitor publishes snapshots every 0.25 seconds. Independent background
workers read effective movement profiles, control gates, and tackle bindings
every 0.25 seconds; base movement config is checked every second. Catalog scans
run at startup, every two seconds, and after replicated descendants change.
Missing/failed modules are retried automatically, and replaced instances are
loaded again. Refresh buttons remain available. Failing or stalled workers and
panel subscribers are isolated; a repeated error reports once until recovery.
Lists keep selections and only rebuild when their items change.
Spectating follows active characters and restores the
previous camera when stopped, the target leaves, or the hub unloads. FOV and
turning controls also restore their previous values on disable or unload.

The supplied `CharacterMovementClient`, `MovementProfiles`, `BoostInput`,
`MovementConfig`, `MovementModel`, and `ControlGate` sources establish these
movement bindings:

- Roles are read from the player's `GameRole` attribute: `Runner` and
  `Catcher`. This overrides legacy `Role`/team guesses. The internal
  `Sections.Chasers` and selection flags retain their names for compatibility.
- Movement telemetry comes from character attributes such as `MovementState`,
  `MovementSpeed`, `DashReady`, `DashCooldownUntil`, `DashCount`, and
  `LastDashDistance`. Cooldown timestamps use the client's `os.clock()`.
  `BoostRecoveryUntil`, `LastDashEntrySpeed`, and `FacingPaceMultiplier` supply
  recovery, entry speed, and facing pace telemetry.
- **Read movement profile** loads
  `ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles` and calls
  `get(GameRole, Player)`. The returned frozen profile is read for display.
- **Read movement settings** reads the live `Movement.MovementConfig` and
  checks `Movement.ControlGate`. The details list includes base settings and
  the effective profile once loaded: speed, acceleration, braking, turning,
  dash, crossing balance, and camera parameters. These values are read only.
- **Request dash** uses the live `Movement.BoostInput.available(Player)` and
  `request(touchStyle)`. This queues input for the existing character
  controller. Cooldowns, movement locks, and native availability checks apply.
  `ControlGate.movementReason(Player)` and `reason(Player)` also apply, so
  paused sessions, map transitions, spectating, game menus, and typing block
  requests. Missing or failing gate functions prevent a request. The optional
  V shortcut ignores processed input and typing. A successful request means
  input was queued; the model still decides whether a boost starts.

`MovementModel` requires grounded movement, no cooldown/recovery/active dash,
and a qualifying turn relative to recent travel. Base `RunBoost` settings are
10.8 studs over 0.28 seconds, a 1.1-second cooldown, and 0.2-second recovery.
Distance scales with entry speed, so 10.8 is not a guaranteed travel distance.
Standard input uses a 0.18-second buffer, 0.38-second turn history, and
35-degree intent threshold. Touch-style input uses 0.32 seconds, 0.55 seconds,
and 25 degrees. The UI reads these parameters from the current profile/config;
roles, crossing balance, and equipment can change the effective values.
Jump is disabled in the supplied base config.

The decompiled availability function contains suspicious Model/Humanoid
references, and the profile modifier expressions also need verification.
Integration uses the live modules rather than reconstructing those expressions.
`MovementModel.new()` creates separate state; it does not expose the running
character controller's private state. A separate model or an unused config copy
would not tune the existing controller.

**Native sprint speed** wraps the live `MovementProfiles.get` function, which
the character controller calls every render frame. The supplied module is
frozen, so this needs the client's `hookfunction` API. Missing support leaves
the feature disabled with an explanation. An unfrozen module can be wrapped
directly. Hold either Shift key, or enable **Always sprint** for touch/gamepad.
The default increase is 15%, adjustable from 0% to 100%.

Only the local player's returned profile is copied. Sprint scales MaxSpeed,
Acceleration, and Deceleration, and preserves dash/crossing/gear fields. The
copy keeps its identity across Shift presses/releases and slider changes;
otherwise the native controller resets dash state when it sees a new profile.
The game's original frozen profiles are unchanged. Universal WalkSpeed writes
are suspended while this feature is enabled, then resume with their prior
settings. Disable/unload restores the function and leaves any remaining wrapper
as a pass-through if restoration fails.

This addresses competing client speed writes. It does not establish a server
anti-cheat bypass: [server movement validation](https://create.roblox.com/docs/scripting/security/network-ownership)
and [prediction corrections](https://create.roblox.com/docs/projects/server-authority)
can still cause rubberbanding. The actual movement validator/limits are needed
to diagnose server corrections in this game.

**Hitboxes** discovers actual BasePart paths under current player characters.
The initial selection is `HumanoidRootPart`; it is a generic character part,
not a verified Huss Valley tackle hitbox. Enable **Edit character hitboxes
(local)** and adjust X/Y/Z from 0.5 to 20 studs. **All other players** defaults
on; turn it off to use the player selections. **Include your character** adds
your own character. **Show edited hitboxes** draws SelectionBox previews.
**Non-colliding edited parts** defaults on to avoid enlarged collision surfaces.

Edits follow respawns and refresh every half second. Deselection, disabling,
leaving, and unloading restore recorded sizes/collision values, while preserving
game changes that replaced our writes. These are client edits, so changing part
sizes does not prove that the server will accept larger catches.

The supplied `TacklePrediction`, `TackleProfile`, `TackleMotion`,
`TacklePredictionConfig`, and `TackleCollision` establish these additional
bindings under `ReplicatedStorage.ChickenOrHero.Game`:

- `GameConfig.Tackle` contains the actual variants and base tackle parameters.
  `TackleProfile.select(config, horizontalSpeed, catcherMaxSpeed)` chooses the
  live variant and its distance, duration, and recovery. The UI samples this
  with the current root velocity and native Catcher movement profile.
- `TacklePrediction.request()` owns the tackle input. The button checks Catcher
  role, active run, grounded/live/unlocked character, dagger state, native
  control gates, and cooldown, then calls that live function. It does not
  construct a separate `GameAction` payload. `remaining()` and the player's
  `TackleReadyAt` use `workspace:GetServerTimeNow()`, unlike dash cooldowns.
- `TackleMotion.distance(profile, profile.Duration)` supplies integrated motion
  distance for display. Selected profile and prediction tolerance fields appear
  in the Catchers details list. Local settings never change server tolerances.
- `TackleCollision` builds an obstacle sweep from the catcher's root size:
  `(root.Size.X + 0.2, 1.6, root.Size.Z + 0.2)`. This is wall clearance.
  Resizing your root affects those casts and does not identify the catch box.
- Catch prediction calls `HitReplayMath.bounds("Tackle", selectedProfile)`.
  **Edit tackle prediction box** probes this live result and only enables when
  it is a positive finite Vector3. Its X/Y/Z multipliers range from 0.5x to 3x.
  A frozen module requires `hookfunction`; an unfrozen module is wrapped
  directly. Other action types pass through. Unknown schemas remain disabled,
  and removing/replacing bindings disables the editor and restores its hook.

These bounds edits affect the local client prediction/replay path, across
tackle calls. They do not target a particular opponent or resize the server's
catch bounds. `TackleResult` can reject the request or return corrected speed,
start time, and cooldown. The native module handles reconciliation. The useful
next sources are `GameConfig.Tackle`, `HitReplayMath`, `CombatPrediction`, and
the server tackle/movement validator to verify bounds semantics and accepted
movement limits.

The decompiled tackle source discards the Humanoid reference, then treats the
character Model as a Humanoid/root. Its `finish` clears `u1` before accessing
`u1.id`. These are decompiler artifacts; integration calls the live module and
reports errors instead of rebuilding that source.

Ability/item schemas are still discovery conventions. Catalogs search
`ReplicatedStorage` folders named `Abilities`, `RunnerAbilities`,
`CatcherAbilities`, `ChaserAbilities`, or `Consumables`. They list nested
ModuleScript, Model, Tool, and ValueBase definitions without executing them.
Selections support browsing; equipping, buying, and using items require verified
game bindings. The carried-tools list covers Backpack and character Tools.

Round metadata reads all attributes from
`ReplicatedStorage.ChickenOrHero.Game.Session`, including `Phase`,
`GlobalPaused`, `MapChanging`, `LeadUserId`, and `SelectedUserId`. It also uses
matching root attributes and named round-state folders. The known session flags
provide movement block status before native modules are loaded. Public stats
use the standard `leaderstats` folder. Missing data shows as
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
also exposes the game context as `Context.HussValley`. Modules with a `Section`
entry reuse that section, as `sprint.lua` does with Movement.

Runtime helpers include `RefreshData()`, `RefreshCatalogs()`,
`Subscribe(callback)`, `GetRole(player)`, `SpectatePlayer(player)`,
`StopSpectating()`, `ReadMovementProfile()`, `ReadMovementSettings()`, and
`RequestDash(touchStyle)`, plus `ReadTackleBindings()` and `RequestTackle()`.
`WatchData(name, callback, interval)` schedules independent background reads.
`ReadGameModule`, `GetMovementProfile`, `CheckControlGates`, and
`DescribeSettings` support game bindings. `Subscribe(callback, optionalName)`
delivers the latest snapshot without one failed subscriber blocking others.
The latest data is in `Context.State.Snapshot`.

For example, Runner controls go in `modules/runners.lua` and use
`Context.Sections.Runners`. Keep shared movement and equipment in their
respective modules rather than duplicating them in both role modules.

Universal movement, the player roster, and UI settings already load separately.
Upload the template files together with the updated loader to the repository
used by `MyFullUrl` before trying the template in a live session.
