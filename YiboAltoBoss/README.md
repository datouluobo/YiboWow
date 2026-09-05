# YiboAltoBoss

YiboAltoBoss is a World of Warcraft addon for Mists of Pandaria Classic that tracks world boss weekly kills and Warbringer observations across your characters. Version 2.2 requires YiboCore API v5 and uses its unified account page, character directory, optional entry, and settings navigation.

![YiboAltoBoss overview](Screenshots/Snipaste_2026-07-06_06-09-49.png)

## Features

- Account-wide overview for MoP Classic world boss progress
- Per-character tracking for Sha of Anger, Galleon, Nalak, Oondasta, the combined Four Celestials encounter, and Ordos
- The Four Celestials are a single weekly row; the recorded kill tooltip identifies the specific Celestial defeated
- Warbringer observation tracking by zone and realm
- Unified YiboCore entry and account-view navigation
- Configurable overview and settings panels

## Core integration (2.0)

- `YiboAltoBossDB` remains the owner of all Boss, phase, respawn-sample, custom-target, and display data.
- Known AltoBoss characters are imported into YiboCore's shared character directory without changing their legacy Boss data keys.
- YiboCore owns the default minimap/Broker entry and exposes AltoBoss in its settings navigation.
- The formal Boss grid and its hover preview use one AltoBoss renderer inside the Core account view. Page scope, character hiding, sorting, preview limits, and optional entry lifecycle are managed by Core.

## Release Package

GitHub Releases and packaged builds exclude unused source artwork under `Media/Source/`.

## P5 tracking

Timeless Isle kills are recorded immediately from combat-log events. On login, the addon also restores completed current-week kills from Blizzard's server-side weekly lockout flags, so a kill remains recoverable after reloads or on another computer. The Four Celestials do not create phase or action records because they rotate at one location without a respawn wait.

If a character killed a Celestial before the addon was installed, run `/yab celestial` to manually correct that character's current-week Four Celestials record. This command does not read quests or infer historical kills.
