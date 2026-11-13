# YBP Retail 宠物 API 只读探针

P0-02 diagnostic, version 0.1.1. It is not part of YiboBeastPaths and must not be packaged or published. The 0.1.1 sample adds the native extra-slot constant, bonus availability and specialization ID; missing or nil extra-slot data remains unknown, not a verified empty slot.

## Safety and scope

The probe reads Retail hunter pet APIs and records diagnostic observations only in `YiboBeastPathsRetailPetProbeDB`. It never writes `YiboBeastPathsDB`, and does not move, summon, tame, release, rename or specialize pets. Unknown probe schema, wrong product, unavailable Core API13/identity or unknown character stops its own writes. Fullness is always reported as unverified; a successful API call does not mean the sample is complete.

Probe `/yrx` is unique in this workspace. Target guard requires project 1 and Mainline 1. It records GetBuildInfo, list API results and counts, native slot constants, per-slot reads, the returned `IsAtStableMaster` value, and event count. Pet rows are kept in this probe's local SavedVariables for review; chat output avoids names. The report prints the probe sample count so a reload can confirm diagnostic history persisted.

## Install when asked

On the current laptop, the same-name junction at `D:\Program\World of Warcraft\_retail_\Interface\AddOns\YiboBeastPathsRetailPetProbe` points to `D:\Development\YiboWow\_NonRelease\YiboBeastPathsRetailPetProbe`. It was created on 2026-11-12 while the Retail client was closed; loading remains unverified. The former C: path belongs to the previous computer. Enable YiboCore and **YiboBeastPathsRetailPetProbe**. Start Retail fully, log in to a Hunter, and check `/yrx report` has the expected project and Core readiness. Use `/yrx scan` to record each named sampling point; `/yrx detail` prints slot IDs only. The probe performs one login sample automatically.

The link was checked to target the workspace probe directory. Do not delete or replace it during sampling.

## Sampling sequence

Follow the steps in [P0-02 Retail and Mists sampling guide](../YiboBeastPathsPetProbe-P0-02/README.md). Do not infer that zero/nil, an empty API list, or matching counts prove a complete empty stable. Provide only the requested `[YBP Retail Probe]` lines; reports do not include pet names.

## Evidence status

Source API shape was reviewed against the Retail UI source mirror at the commit pinned in the [DEV-002 plan](../../YiboBeastPaths/Docs/DEV-002-离线兽栏实施与验收方案.md). The mirror is not the installed 12.1.5 client build. On 2026-10-27, two open-stable samples about two seconds apart on build 70575 each found 4 active + 5 stabled pets, matching the native 9/205 counter; all 205 slot calls succeeded and found the same 9 occupied slots. Name-descending sort and the native special-type filter kept the API lists and slot IDs unchanged; while special filtering showed one visible row, the native total remained 9/205. Closed-stable samples immediately, after about two seconds, and after `/reload` returned the same 4/5 list and 9 occupied slots. After reload, `IsAtStableMaster` returned false and the count APIs returned 4 and 5. The latest probe store held nine samples, but no pre-reload count was printed for direct comparison. These results establish per-character data is available while away from a stable through a reload; full-exit availability, cache freshness, extra-slot coverage and movement remain unverified; details are in the shared [P0-02 record](../YiboBeastPathsPetProbe-P0-02/README.md).
