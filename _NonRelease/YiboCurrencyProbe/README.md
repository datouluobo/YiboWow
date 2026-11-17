# YiboCurrencyProbe

Native API sampler for Mists and Forever. It does not load YiboCore or YiboCurrency, inspect a business catalog, or read business SavedVariables. Captures are manual and written only to `YiboCurrencyProbeDB` in the account of each client.

Commands: `/ycp capture` and `/ycp status`. The former `/ycu probe` command read YiboCurrency/Core state and has been removed from the business addon.

The default TOC is a hint. The Mists and Forever target TOCs select the same probe, and the runtime verifies project identity before registering the command or writing a sample. Both clients need a complete restart after TOC changes. In the native currency panel expand available sections before capture. The probe records the visible list, API availability, links, ID when exposed by list fields or links, and a detail query for each ID. It records row errors and marks lists over 500 rows or with failed rows incomplete. Collapsed sections and entries the client does not expose remain outside the sample. No panel expansion, item use, or business database modification is performed. `lastCapture` is overwritten on each capture in the same account.

2026-11-12 junctions point to this directory from `D:/Program/World of Warcraft/_classic_/Interface/AddOns/YiboCurrencyProbe` and `D:/Program/World of Warcraft Forever/World of Warcraft/_forever_/Interface/AddOns/YiboCurrencyProbe`. Simulated Mists, Forever, wrong-target, and partial-list checks passed. Actual TOC selection, API responses and list completeness require the two clients.
