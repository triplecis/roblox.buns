# Huss Valley template

`10764627709.lua` is the entry point registered in the loader under universe ID
`10764627709`. It creates the sections below and loads their files from
`modules/`. Labels and placeholders are ready; feature functions are pending.

Research checked October 6, 2026:

- [Know Your Meme](https://knowyourmeme.com/memes/huss-valley) describes Huss Valley
  as a fictional chase setting. The proposed origin of "huss" is the sound of
  heavy breathing while running.
- This template targets [Huss Valley by Huss Valley Official](https://www.roblox.com/games/107535308163741/Huss-Valley).
  The similarly named Ve3 and Escape Huss Valley experiences have different mechanics.
- The module categories are our organization choice based on
  [Pro Game Guides' gameplay reporting](https://progameguides.com/roblox/complete-huss-valley-beginners-guide-movement-abilities-consumables/).
  The official description is brief; implementation details still need in-game verification.

| Section | File | Topic for function planning |
| --- | --- | --- |
| Rounds | `rounds.lua` | Crossings, round flow, Hero / Chicken |
| Runners | `runners.lua` | Survival and teammate revives |
| Chasers | `chasers.lua` | Pursuit, tagging, role conversion |
| Movement | `movement.lua` | Momentum, lateral dashes, stopping |
| Abilities | `abilities.lua` | Role ability loadouts |
| Consumables | `consumables.lua` | Single-use items |
| Rewards | `rewards.lua` | Gems, coins, match payouts |

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

For example, Runner controls go in `modules/runners.lua` and use
`Context.Sections.Runners`. Keep shared movement and equipment in their
respective modules rather than duplicating them in both role modules.

Universal movement, the player roster, and UI settings already load separately.
Upload the template files together with the updated loader to the repository
used by `MyFullUrl` before trying the template in a live session.
