# Changelog

All notable changes to Forever Idle are listed here. Versions match the
git tag a release is built from; the packager writes it into the `.toc`
files in place of `@project-version@`.

## [0.3.4] - 2026-11-03

### Fixed
- Scouting now works on clients in every language. Zones are recognised by
  their map, so German, French, Russian and other players get the half-time,
  double-gold bonus too. Zones you already visited still count.
- Toasts no longer replace each other. When several arrive at once, such as
  an expedition coming home and a zone being scouted at login, they now
  show one after another.
- The You page shows your real offline shift length, including the extra
  hours from the Night Watch Lantern and the Skeleton Key.
- `/idle reset` keeps your settings (sound, couriers, bonuses) and the
  window's position, size and tab. Before, a wipe in the compact window
  left the size button needing two clicks.

### Changed
- The addon's version now comes from the release tag, so the version shown
  in game always matches the CurseForge file.

## [0.3.3] - 2026-10-31

### Fixed
- The "While you were away" box now grows to fit its text, so the last
  line is no longer hidden behind the Collect button.

## [0.3.2] - 2026-10-31

### Changed
- Releases are now packaged and uploaded to CurseForge automatically when a
  version tag is pushed.

## [0.3.1] - 2026-10-30

### Fixed
- Pressing Escape no longer closes the game window. Close it with the ×
  button, `/idle` or the addon compartment.

## [0.3.0] - 2026-10-30

### Added
- Relic ranks. Clearing a zone again raises its relic a rank, up to rank 5.
  Each rank adds half the relic's base bonus again, so rank 5 is three times
  as strong. Ranks are kept when you Hearth home.
- The Forever Deep, an endless expedition that opens once Naxxramas is
  cleared. Each depth takes longer, costs more and needs more hirelings, and
  every depth you reach adds 5% to all mining for good.
- A fifth upgrade for every hireling, unlocked at 200 owned.
- The Forever Idle logo, as the addon's icon in the addon list and the
  addon compartment, and in the window's title bar.

### Changed
- Offline gains, expeditions, the courier and Battle Shout now run on the
  realm's clock instead of your computer's, so changing the PC clock no
  longer finishes expeditions or pays out offline gold.
- The window is a little taller to fit the Forever Deep.

## [0.2.1] - 2026-10-30

First version on GitHub.
