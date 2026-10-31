# Forever Idle

An idle game that lives inside World of Warcraft. Mine the vein, hire
prospectors, kobolds and goblin shredders, send expeditions from Elwynn
Forest to Naxxramas, and Hearth home for Renown. Your crew keeps mining
while you're logged out.

Built for Classic Era clients (Interface 11509 and 16001).

## Install

1. Download the latest `ForeverIdle-vX.Y.Z.zip` from
   [Releases](../../releases), or click **Code > Download ZIP**.
2. Copy the `ForeverIdle` folder into your WoW install's
   `Interface\AddOns` folder, so you end up with
   `Interface\AddOns\ForeverIdle\ForeverIdle.toc`.
3. Restart the game, or `/reload` if it's already running.

If you downloaded the whole repository, copy only the inner `ForeverIdle`
folder. The game won't load an addon whose folder name doesn't match its
`.toc` file.

## How to play

Type `/idle` (or `/fidle`, `/foreveridle`) to open the window, or click the
addon in the addon compartment by the minimap (on clients that have one).

- **Hirelings**: hire workers who mine gold every second. Each one costs a
  bit more than the last.
- **Upgrades**: double a hireling's output once you own enough of them, or
  buy global upgrades for clicks and overall income.
- **Expeditions**: send your crew to a zone for a while. Clearing it earns a
  relic with a lasting bonus.
- **Renown**: Hearth home to reset your run in exchange for Renown, which
  makes every hireling mine more. Renown, relics and cleared zones are kept.
- **Relic ranks**: send your crew back to a cleared zone to rank its relic
  up, to a maximum of rank 5.
- **The Forever Deep**: once Naxxramas is cleared, descend as far as you
  can. Every depth adds 5% to all mining for good.

### Your real character helps

- Logging out rested (an inn or a city) gives your crew a full-pace shift,
  like rested XP. Logging out anywhere else gives a half-pace shift.
- Levelling up, turning in quests, looting ore and casting your Hearthstone
  all give bonus gold.
- Visiting a zone for real "scouts" it: expeditions there take half the time
  and bring back twice the gold.
- Levels across your characters, your richest wallet and the real ore you've
  mined all add to your income.

### Commands

| Command | What it does |
| --- | --- |
| `/idle` | Open or close the game |
| `/idle status` | Print your gold, income and Renown |
| `/idle sound` | Turn sounds on or off |
| `/idle courier` | Turn the lost courier on or off |
| `/idle bonus` | Turn real-game bonuses on or off |
| `/idle reset` | Wipe your save (asks first) |

## Project layout

```
ForeverIdle/
  ForeverIdle.toc          addon metadata (version lives here)
  ForeverIdle_Vanilla.toc  same, for clients that look for _Vanilla
  Data.lua                 every number and name: hirelings, upgrades, zones
  Core.lua                 the game loop, saved data, events, slash commands
  UI.lua                   the window, tabs, toasts and popups
  Media/Logo.tga           the addon icon (64x64, 32-bit TGA)
```

Balancing is done in `Data.lua`; the game logic in `Core.lua` doesn't create
frames, so it can be tested outside the client.

Saved data is stored per account in `ForeverIdleDB`.

## License

[MIT](LICENSE)
