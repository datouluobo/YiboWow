# YBP Mists 宠物 API 只读探针

P0-02 diagnostic, version 0.1.0. It is separate from the older Mists identification probe and is not part of YiboBeastPaths or any package.

## Safety and scope

The probe reads slot APIs and records observations only in `YiboBeastPathsMistsPetProbeDB`. It never writes `YiboBeastPathsDB` or the older `YiboBeastPathsPetProbeDB`, and does not move, summon, tame, release, rename or specialize pets. Wrong product, unknown Core API13/identity or unknown probe schema stops its own writes. Every sample says `complete=unverified`; the provisional slot range is a diagnostic search window, not proof of full coverage.

Probe `/ymx` is unique in this workspace. It records build/project/interface, `GetStablePetInfo` status for each candidate slot, active/stable counts, purchased slots, event sequence count, and occupied slot IDs. Names and slot records stay in this probe's SavedVariables; console output does not print names.

## Install when asked

On the current laptop, the same-name junction at `D:\Program\World of Warcraft\_classic_\Interface\AddOns\YiboBeastPathsMistsPetProbe` points to `D:\Development\YiboWow\_NonRelease\YiboBeastPathsMistsPetProbe`. It was created on 2026-11-12 while Mists was running; the client must be fully restarted to discover it. The former C: path was recorded on the previous computer and must not be assumed valid here.

Enable YiboCore and **YiboBeastPathsMistsPetProbe**. Start Mists fully, log in to a Hunter, and use `/ymx report` or `/ymx scan`. One login sample is automatic. `/ymx scan` records a new observation and `/ymx report` shows it.

## Sampling sequence and evidence

Follow the shared [P0-02 sampling guide](../YiboBeastPathsPetProbe-P0-02/README.md). Existing 5.5.4 build 70531 reports are historical partial evidence only; this probe must report the current build. Candidate range constants and 5+200 fallback remain unverified until checked against the native stable UI and current client behavior.
