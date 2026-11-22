# Pixel-line migration brief (shared by all migration agents)

Repo: `D:\Development\YiboWow` (World of Warcraft addons, Lua 5.1, Windows, PowerShell 5.1). Respond/report in Chinese is fine; code comments English.
Read the repo's `AGENTS.md` sections "多版本触及即迁移", "Core 公共能力收归与渐进接入", "客户端语言与玩家可见文本" before editing.

## Goal
YiboCore (working tree) now provides API 14 / capability `pixel-line:1`. Every 1-thickness line must be exactly 1 physical pixel at any resolution/UI scale, and no boundary may be painted twice (no double lines). Business addons must stop drawing 1-UI-unit lines themselves and use Core. Layout sizes (widths, heights, insets) stay in UI units and must NOT change.

Full API doc: `YiboCore/Docs/API-v14-像素线宽.md`. Implementation: `YiboCore/UI/Theme.lua` (search `pixel-line`). DO NOT edit anything under `YiboCore/`.

## Core API (`local Theme = _G.YiboCore.UITheme`)
- `Theme:ApplyPixelBackdrop(frame, { background = true|false, pixels = 1 })` — drop-in replacement for `frame:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })`. Keep existing `SetBackdropColor`/`SetBackdropBorderColor` calls unchanged. Use `background = false` when the original backdrop had no bgFile. Frame must still be created with `"BackdropTemplate"`.
- `Theme:ApplyPixelRule(texture, "horizontal"|"vertical", { color = {r,g,b,a}, pixels = 1 })` — replaces `texture:SetHeight(1)` / `SetWidth(1)` for separator lines. Caller keeps the anchors along the line; Core owns thickness and re-applies it on scale change.
- `Theme:CreatePixelRule(parent, orientation, options)` — creates a texture and applies the above.
- `Theme:CreatePixelBorder(frame, { sides = { top=, right=, bottom=, left= }, color = {..}, sublevel = n })` — side-selectable border; repeated calls update in place (safe to call every refresh). Returns object with `:SetColor(color)`, `:SetSides(sides)`, `:SetShown(bool)`. Vertical edges stop short of drawn horizontal edges (corner pixel painted once).
- `Theme:GetPixelSize(region, n)` — N physical pixels in UI units. Use it whenever code used `1` as a line-width-dependent anchor offset (e.g. `SetPoint(..., 1, -1)` meaning "inside the 1px border", or a 1-unit gap that is visually a rule).
- Current-character outline (`Theme:UpdateCurrentCharacterRowOutline`, `UpdateCurrentCharacterColumnOutline`, `CreateCurrentCharacterOutline`) already handled by Core; see the "当前角色描边几何" section in the API doc for the calling contract (column: `header` = frame whose top is the character header top, `viewport` = Core scroll frame or last row). Fix calls only if they violate that contract.

## Dedupe rules ("一条边界只画一次")
- Stacked data rows (touching, gap 0): row has NO 4-edge backdrop border. Use `bgFile`-only backdrop (`row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })`) for the fill, plus `Theme:CreatePixelBorder(row, { color = C.matrixLine, sides = { top = rowIndex == 1, right = true, bottom = true, left = true } })`. Remove the `SetBackdropBorderColor` call for that row. Reference implementation: `YiboAltoBoss/Mists/AccountPage.lua` (`SetRowBorder`) and `YiboCore/UI/AccountPages/CharacterArchive.lua`.
- Cells/buttons inside an already ruled row: ordinary state should not draw a frame parallel to the row rules (set border color alpha 0, keep semantic borders such as completed/selected/hover). Reference: AltoBoss `CELL_NO_BORDER`.
- If a row has a separate bottom rule texture AND a 4-edge border, keep only one.
- Standalone controls/panels (buttons, inputs, popups, cards, tiles, section boxes) that do not touch neighbours: just switch to `ApplyPixelBackdrop` (no dedupe needed). Tiles in a grid with a gap > 0 also just use `ApplyPixelBackdrop`.
- Do not change colors, sizes, or layout beyond what dedupe requires.

## Minimum Core gate (required, no local fallback)
Each migrated addon/target must require `CheckAPIVersion(14)` and `HasCapability("pixel-line", 1)` (plus method check `type(Core.UITheme.ApplyPixelBackdrop)=="function"` where the addon already checks methods). Find the addon's existing gate (search `CheckAPIVersion`, `REQUIRED_CORE_API`, `CoreReady`, `requiredAPI`) for EVERY target TOC you touch (`<Addon>_Mists.toc`, `_Forever.toc`, `_Mainline.toc`). Raise 13→14 there, add the capability to the required list, update `RegisterAddon(..., { requiredAPI = 14 })` if present, and update the upgrade message text in BOTH Chinese and English resources (keep format args identical; if a locale key name contains API13, add a new key `..._API14...` and switch the code to it, remove the now-unused old key only if nothing else uses it). The release builder reads the gate via `Tools/ReleaseProfiles.psd1` `RequiredCorePattern` — make sure the pattern still matches the new number (do not edit ReleaseProfiles unless the pattern breaks; if it breaks, report it instead).
Version numbers (TOC `## Version`, VERSION constants) must NOT be changed.

## Targets
Check each TOC to see which files a target loads; a shared file (e.g. `Common/…`) affects all targets that load it, and then every such target's gate must be raised. Also check `.xml` files for `edgeSize="1"` / 1-px textures.

## Tests (must run, must not regress)
Lua: `& "C:\Program Files (x86)\Lua\5.1\lua.exe" <path>` from repo root (use `cmd /c "...2>&1"` to see errors). Run every test file under your addons' `Tests/` and `_NonRelease/Tests/` directories, before AND after, and compare. Pre-existing failures (also failing before your change) must be reported, not "fixed" by weakening assertions. If a test fixture stubs `YiboCore.UITheme` by hand and now lacks a new method, add a minimal stub (e.g. `ApplyPixelBackdrop=function(_,f) return f end`, `CreatePixelBorder=function() return {SetColor=function()end,SetShown=function()end,SetSides=function()end} end`, `ApplyPixelRule=function(_,t) return t end`) — that is fine. If a test asserts the old API13 gate/message, update it to API14 and add one assertion that an API13 Core is refused.
Syntax: `powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'D:\Development\YiboWow\Tools\Test-LuaSyntax.ps1' -Addon <AddonName>"`.
Builder: `powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:Path += ';C:\Program Files (x86)\Lua\5.1'; & 'D:\Development\YiboWow\Tools\Build-ReleasePackages.ps1' -Addon <Addon> -Target <Mists|Forever|Retail> -ValidateOnly"` for every target you touched; it must succeed.
After edits, `grep` your addon (excluding `_NonRelease`) for `edgeSize\s*=\s*1\b` and `:Set(Height|Width)\(1\)` — remaining hits must each be justified in your report (e.g. a 1-unit hit-area frame that is not a line).

## Do NOT
- Edit `YiboCore/`, `Tools/`, `Docs/`, `YiboCore/Docs/Core-公共能力迁移台账.md`, `Docs/无限服适配与发布验收台账.md`, or any addon not assigned to you. The lead consolidates ledgers.
- Change version numbers, SavedVariables, TOC file lists, slash commands.
- Touch files under `_NonRelease/` except your addon's own tests.
- Use git (not installed).

## Report (final message, Chinese, concise)
1. Per addon/target: files changed, each converted site (file:line, before → after, dedupe decision).
2. Gate changes (file:line), locale keys added/changed.
3. Test results before/after (name: pass/fail, counts), syntax, ValidateOnly per target.
4. Remaining `edgeSize=1`/`Set*(1)` hits with justification.
5. Anything you could not decide or that needs in-game verification (specific page/state to look at).
6. A short paragraph to append to the addon's own doc — and actually append it to the addon's existing main Core-integration doc under `<Addon>/Docs/` (pick the most relevant existing doc; create none if none fits, just report).
