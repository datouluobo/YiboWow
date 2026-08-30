# YiboAltoBoss

YiboAltoBoss is a World of Warcraft addon for Mists of Pandaria Classic that helps you track world boss kill status and Warbringer phase observations across all of your characters. Version 2.1.2 requires YiboCore API v5, which provides the shared account page, optional entry, and settings navigation.

It provides a compact account-wide overview so you can quickly see which characters have already killed each boss, which targets still need attention, and what has recently been observed in each Warbringer location.

## Features

- Account-wide overview of MoP Classic world boss weekly kill status
- Character-by-character tracking for:
  - Sha of Anger
  - Galleon
  - Nalak
  - Oondasta
  - Timeless Isle Four Celestials and Ordos
- The Four Celestials are shown as one weekly row. Its tooltip records which Celestial was actually defeated; no phase or action data is shown for this rotating encounter.
- Warbringer observation tracking by zone
- Unified YiboCore account entry
- Main overview panel for quick cross-character checking
- Settings panel for display and behavior options
- Lightweight local data storage through SavedVariables

## P5 tracking

Combat-log kills are recorded immediately, and completed current-week kills are restored on login from Blizzard's server-side weekly lockout flags. The Four Celestials do not produce phase or action records because they rotate at one location without a respawn wait.

For an earlier missed kill, `/yab celestial` manually corrects the current character's Four Celestials record. It does not read quests or infer historical kills.

## Screenshots

### Main overview

![Main overview](https://raw.githubusercontent.com/datouluobo/YiboAltoBoss/main/Screenshots/Snipaste_2026-07-06_06-09-49.png)

### Warbringer action details

![Warbringer action details](https://raw.githubusercontent.com/datouluobo/YiboAltoBoss/main/Screenshots/Snipaste_2026-07-06_06-10-51.png)

### Phase detail hover

![Phase detail hover](https://raw.githubusercontent.com/datouluobo/YiboAltoBoss/main/Screenshots/Snipaste_2026-07-06_06-11-04.png)

### Settings panel

![Settings panel](https://raw.githubusercontent.com/datouluobo/YiboAltoBoss/main/Screenshots/Snipaste_2026-07-06_06-11-19.png)

## Notes

- Built for **Mists of Pandaria Classic**
- Tracks information recorded by the addon during gameplay
- Requires YiboCore; no external services are used

## 2.1.2 Core page

YiboCore owns the default minimap/Broker entry, account character directory, page scope, and settings navigation. AltoBoss continues to own its Boss, phase, respawn-sample, and custom-target SavedVariables. The Boss grid and optional AltoBoss entry now use the same Core-hosted account-page projection.
