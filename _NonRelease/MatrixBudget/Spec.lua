-- Real business metric/render functions and real Core sizing/paging, synthetic facts only.
dofile("YiboCurrency/_NonRelease/Tests/API13Spec.lua")
dofile("YiboCore/Util/LevelFilter.lua")
local Core, Theme, view, checks = YiboCore, YiboCore.UITheme, YiboCore.AccountView, 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local nativeCreate = CreateFrame
CreateFrame = function(...)
    local frame = nativeCreate(...)
    frame.GetFrameStrata = function() return "DIALOG" end
    frame.GetVerticalScroll = function() return 0 end
    frame.IsMouseOver = function() return false end
    frame.HasFocus = function() return false end
    frame.Disable = function(self) self.disabled = true end
    return frame
end
local function Frame(w, h) local f = CreateFrame("Frame", nil, UIParent); f:SetSize(w or 1200, h or 300); return f end
UIParent:SetSize(4096, 500)
local roster, keys = {}, {}
for i = 1, 13 do
    local c = { id = "Matrix" .. i, name = "Role" .. i, realm = "Realm", class = "MAGE", level = 90 }
    roster[i], keys[i] = c, c.id
end
local function Context(preview)
    return { characters = roster, scope = "all", preview = preview == true, viewMode = "character-columns",
        GetFieldVisible = function(_, id) return id ~= "action" and id ~= "phase" end,
        SetTitleBarControl = function() end, ClearTitleBarControl = function() end }
end
local stage, budgets, slices = "", {}, {}
local nativeBudget, nativePager, nativeVariablePager = view.GetScrollSurfaceWidth, view.GetColumnPage, view.GetColumnPageByWidth
view.GetScrollSurfaceWidth = function(self, context, parent, body, fixed)
    budgets[stage] = (budgets[stage] or 0) + 1
    Check(type(body) == "number" and type(fixed) == "number", stage .. " declares content dimensions")
    return nativeBudget(self, context, parent, body, fixed)
end
view.GetColumnPage = function(self, pageID, stateKey, columns, width, fixed, cell, current)
    local shown, info = nativePager(self, pageID, stateKey, columns, width, fixed, cell, current)
    slices[stage] = { shown = shown, info = info, width = width }
    return shown, info
end
view.GetColumnPageByWidth = function(self, pageID, stateKey, columns, width, fixed, measure)
    local shown, info = nativeVariablePager(self, pageID, stateKey, columns, width, fixed, measure)
    slices[stage] = { shown = shown, info = info, width = width }
    return shown, info
end
local pagerState = {}
view.UpdateColumnPager = function(_, _, _, _, info) pagerState[stage] = info or false end
local shellWidth = Theme:GetNavigationWidth() + Theme.Geometry.shellBorder * 2 + 1
local function Exercise(name, metricsFn, renderFn, instance, context, limited)
    stage = name
    local metrics = metricsFn(context)
    Check(type(metrics.scrollContentHeight) == "number" and type(metrics.scrollFixedHeight) == "number", name .. " opts into Core budget")
    local shell = Frame(760, 250); shell.preview = false
    view.CreateFrame = function() return shell end
    view:ApplyPageSize({ id = "budget-" .. name, title = name, GetSurfaceMetrics = metricsFn }, context)
    context.surfaceAvailableWidth = shell:GetWidth() - shellWidth
    context.surfaceAvailableHeight = shell:GetHeight() - Theme.Geometry.titleBar - 2
    instance:SetSize(context.surfaceAvailableWidth, context.surfaceAvailableHeight)
    renderFn(instance, context)
    Check((budgets[name] or 0) > 0, name .. " renderer consumes Core budget")
    if slices[name] then Check(limited and slices[name].info.pages > 1 or not limited and slices[name].info.pages == 1, name .. " pages only at the actual screen boundary") end
    return metricsFn(context)
end

-- AltoBoss and lockouts.
YAB = { CoreReady = true }
dofile("YiboAltoBoss/Locale.lua"); dofile("YiboAltoBoss/LockoutLocale.lua")
local bosses, columns = {}, {}
for i = 1, 54 do bosses[i] = { key = "boss" .. i, name = "Boss " .. i } end
for i = 1, 13 do columns[i] = { id = "instance" .. i, name = "Instance " .. i, abbreviation = "I" .. i } end
YAB.GetBossList = function() return bosses end
YAB.GetAccountCharacterKeys = function() return keys end
YAB.GetCharacterIdentity = function(key) for _, c in ipairs(roster) do if c.id == key then return c end end end
YAB.FormatCharacterName = function(key) return key end
YAB.GetCurrentCharKey = function() return keys[1] end
YAB.GetBossKillStatus = function() return "unknown" end
YAB.GetLockoutColumns = function() return columns end
YAB.GetLockoutStatus = function() return "unknown", "?" end
YAB.GetLockoutTooltip = function() return {} end
YAB.GetBusinessTabHeight = function() return 34 end
dofile("YiboAltoBoss/AccountPage.lua"); dofile("YiboAltoBoss/LockoutsPage.lua")
local bossPage = Frame(); YAB.CreateAccountPage(bossPage)
Exercise("boss", YAB.GetAccountSurfaceMetrics, YAB.RefreshAccountPage, bossPage, Context())
Exercise("boss-hover", YAB.GetAccountSurfaceMetrics, YAB.RefreshAccountPage, bossPage, Context(true))
local lockouts = Frame(); YAB.CreateLockoutsPage(lockouts)
Exercise("lockouts", YAB.GetLockoutsSurfaceMetrics, YAB.RefreshLockoutsPage, lockouts, Context())
Check(lockouts.scroll ~= nil and lockouts.body:GetParent() == lockouts.scroll, "lockouts use Core vertical scroll container")
local lockoutHover = YAB.GetLockoutsHoverMetrics(Context(true))
Check(lockoutHover.scrollContentHeight == #keys * 26, "lockout hover forwards the same content height")

local bossRowsContext = Context(); bossRowsContext.viewMode = "character-rows"
Exercise("boss-rows", YAB.GetAccountSurfaceMetrics, YAB.RefreshAccountPage, bossPage, bossRowsContext, true)
local bossRowCells = 0; for _, cell in ipairs(bossPage.rows[1].cells) do if cell:IsShown() then bossRowCells = bossRowCells + 1 end end
Check(bossRowCells == #slices[stage].shown, "Boss row layout paginates actual boss columns through Core instead of clipping them")

-- Crafting: real filters, grouping, matrix renderer and locale resources.
YiboCrafting = { NAME = "YiboCrafting", Store = { db = { settings = {}, characters = {} }, GetRecipeState = function() return "unknown" end } }
dofile("YiboCrafting/Locales/Interface.lua"); dofile("YiboCrafting/Locales/Categories.lua")
dofile("YiboCrafting/AccountPage.lua")
local crafting, recipes, snapshotReads = YiboCrafting.AccountPage, {}, 0
for i = 1, 54 do recipes[i] = { id = i, key = "333:" .. i, professionID = 333, name = "Recipe " .. i, outputItemIDs = {}, categoryID = 1 } end
crafting.Snapshot = function() snapshotReads = snapshotReads + 1; return recipes, {}, { [333] = "Enchanting" } end
local craftPage = Frame()
craftPage.crafting = { state = { search = "" }, matrixWidth = 1200, toolbar = Frame(1200, 32), footer = Frame(),
    matrix = Frame() }
local matrix = craftPage.crafting.matrix
matrix.scroll, matrix.body, matrix.header, matrix.empty, matrix.rows = Frame(), Frame(), Frame(), Frame(), {}
craftPage.crafting.matrix.header.cells = {}; craftPage.crafting.matrix.header.title = Frame()
crafting.filterState = craftPage.crafting.state
local function RenderCraft(parent, context)
    parent.crafting.matrixWidth = context.surfaceAvailableWidth - 16
    crafting:RenderMatrix(parent, context, recipes, { [333] = "Enchanting" })
end
Exercise("crafting", function(c) return crafting:GetMatrixSurfaceMetrics(c) end, RenderCraft, craftPage, Context())
local craftingPreview = Frame(); crafting:Create(craftingPreview)
craftingPreview.crafting.matrix.scroll.GetVerticalScroll = function() return 0 end
local previewContext = Context(true)
local previewMetrics = Exercise("crafting-hover", function(c) return crafting:GetMatrixSurfaceMetrics(c) end,
    function(parent, c) crafting:Refresh(parent, c); Check(c.craftingSurfaceSnapshot == nil, "Crafting consumes the measurement snapshot without retaining a stale context cache") end, craftingPreview, previewContext)
Check(craftingPreview.crafting.matrix.body:GetHeight() == previewMetrics.scrollContentHeight, "Crafting hover measures exactly its rendered grouped subset")
local sameContext = Context(); crafting:GetMatrixSurfaceMetrics(sameContext); local reads = snapshotReads
crafting:GetMatrixSurfaceMetrics(sameContext)
Check(snapshotReads == reads, "Crafting measurement reuses context snapshot")
crafting.filterState.search = "not present"
Check(crafting:GetMatrixSurfaceMetrics(Context()).scrollContentHeight == 0, "Crafting filters affect scroll height")
crafting.filterState.search = ""
local previewEntries = crafting:GetMatrixEntries({ preview = true, characters = roster, surfaceAvailableHeight = 250 }, recipes, crafting.filterState, 32)
Check(#previewEntries < #recipes, "Crafting preview measures its density-limited subset")

-- Legendary target columns and complete role rows.
YiboLegendary = { NAME = "YiboLegendary", Core = Core, runtime = { snapshotsByCharacter = {} }, db = { byCharacter = {} } }
function YiboLegendary:T(key, ...) return Core.Locale:Get(self.NAME, key, ...) end
dofile("YiboLegendary/Locales/Interface.lua"); dofile("YiboLegendary/UI.lua")
local legendary, targets = YiboLegendary.UI, {}
for i = 1, 13 do targets[i] = { id = "target" .. i, title = "Target " .. i, shortTitle = "T" .. i, expansionLabel = "Expansion", routeLabel = "Route" } end
YiboLegendary.Catalog = { GetTargets = function() return targets end, GetTarget = function(_, id) return { id = id } end }
for _, c in ipairs(roster) do YiboLegendary.db.byCharacter[c.id] = { snapshot = { targets = {} } } end
legendary.details = Frame(); legendary.details.preview = legendary:CreatePreview(legendary.details)
Exercise("legendary-hover", function(c) return legendary:GetSurfaceMetrics(c) end,
    function(_, c) legendary:RefreshPreview(c) end, legendary.details.preview, Context(true))
Check(#legendary.details.preview.rows == #roster, "Legendary keeps every admitted role row")

-- QuestBlocker includes the same complete-scope groups on all character pages.
YQB = { CoreCompatible = true }
dofile("YiboQuestBlocker/Locale.lua")
local questDB = { settings = {}, filters = {}, characterData = {} }
local blocked = {}; for i = 1, 54 do blocked[i] = { id = i, name = "Quest " .. i } end
YQB.GetDatabase = function() return questDB end
YQB.GetStats = function() return 0, 0, 54 end
YQB.GetBlockedQuestList = function() return blocked end
YQB.GetCurrentQuestList = function() return { { id = 999, name = "Current" } } end
YQB.GetCurrentCharacterID = function() return keys[1] end
YQB.IsQuestBlockedByAny = function() return false end
YQB.GetBlockStatus = function() return {} end
YQB.GetProcessModeOptions = function() return {} end
YQB.GetProcessMode = function() return "all" end
YQB.IsProcessingPaused = function() return false end
YQB.ValidateLevelExpr = function() return true, "" end
dofile("YiboQuestBlocker/AccountPage.lua")
local questPage = Frame(); YQB.AccountPage.Create(questPage)
Exercise("quest", YQB.AccountPage.GetSurfaceMetrics, YQB.AccountPage.Refresh, questPage, Context())
Exercise("quest-hover", YQB.AccountPage.GetSurfaceMetrics, YQB.AccountPage.Refresh, questPage, Context(true))
local qHover = YQB.AccountPage.GetHoverMetrics(Context(true))
Check(qHover.scrollContentHeight == YQB.AccountPage.GetSurfaceMetrics(Context(true)).scrollContentHeight, "QuestBlocker forwards its hover budget")

-- Narrow screens must use one shared slice for headers and cells.
UIParent:SetWidth(900)
local function Visible(pool) local count = 0; for _, item in pairs(pool) do if item:IsShown() then count = count + 1 end end; return count end
Exercise("boss-narrow", YAB.GetAccountSurfaceMetrics, YAB.RefreshAccountPage, bossPage, Context(), true)
Check(Visible(bossPage.rows[1].cells) == #slices[stage].shown, "Boss cells match Core character slice")
Exercise("lockouts-narrow", YAB.GetLockoutsSurfaceMetrics, YAB.RefreshLockoutsPage, lockouts, Context(), true)
Check(Visible(lockouts.headers) == #slices[stage].shown + 1 and Visible(lockouts.rows[1].cells) == #slices[stage].shown, "Lockout headers and data use the same instance slice")
Exercise("crafting-narrow", function(c) return crafting:GetMatrixSurfaceMetrics(c) end, RenderCraft, craftPage, Context(), true)
Check(Visible(craftPage.crafting.matrix.header.cells) == #slices[stage].shown, "Crafting headers use Core character slice")
Exercise("legendary-narrow", function(c) return legendary:GetSurfaceMetrics(c) end,
    function(_, c) legendary:RefreshPreview(c) end, legendary.details.preview, Context(true), true)
Check(Visible(legendary.details.preview.header.cells) == #slices[stage].shown + 1
    and Visible(legendary.details.preview.rows[1].cells) == #slices[stage].shown + 1, "Legendary target headers and cells share Core slice")
Exercise("quest-narrow", YQB.AccountPage.GetSurfaceMetrics, YQB.AccountPage.Refresh, questPage, Context(), true)
Check(Visible(questPage.headerCharacters) == #slices[stage].shown and Visible(questPage.rows[2].cells) == #slices[stage].shown, "Quest headers and cells share Core character slice")
Check(questPage.rowCount == 57, "Quest row groups remain based on the full role scope while paging")

local hiddenBoss = Context(); hiddenBoss.GetFieldVisible = function() return false end
stage = "boss-hidden"; YAB.RefreshAccountPage(bossPage, hiddenBoss)
Check(pagerState[stage] == false and Visible(bossPage.rows[1].cells) == 0, "hidden Boss character columns cannot create a phantom page")
local hiddenQuest = Context(); hiddenQuest.GetFieldVisible = function(_, id) return id ~= "characters" end
stage = "quest-hidden"; YQB.AccountPage.Refresh(questPage, hiddenQuest)
Check(pagerState[stage] == false and Visible(questPage.headerCharacters) == 0, "hidden Quest character columns cannot create a phantom page")

-- Empty/filter transitions are dimensions of the source layout, not guessed Core row thresholds.
bosses = {}; Check(YAB.GetAccountSurfaceMetrics(Context()).scrollContentHeight == 0, "empty Boss list has no scrolling content")
keys = {}; Check(YAB.GetLockoutsSurfaceMetrics(Context()).scrollContentHeight == 0, "empty lockout roster has no scrolling content")
blocked = {}; YQB.GetCurrentQuestList = function() return {} end
local emptyQuest = Context(); emptyQuest.characters = {}
Check(YQB.AccountPage.GetSurfaceMetrics(emptyQuest).scrollContentHeight == 44, "empty Quest view retains its actual group/empty height")
local hiddenTargets = Context(true); hiddenTargets.GetFieldVisible = function() return false end
local emptyTargetColumns = legendary:GetSurfaceMetrics(hiddenTargets)
Check(emptyTargetColumns.naturalContentWidth < legendary:GetSurfaceMetrics(Context(true)).naturalContentWidth, "Legendary hidden target columns change natural width")

-- Source invariant supplements runtime checks: business matrices must not own a track constant or screen budget.
for _, path in ipairs({ "YiboAltoBoss/AccountPage.lua", "YiboAltoBoss/LockoutsPage.lua", "YiboCrafting/AccountPage.lua",
    "YiboLegendary/UI.lua", "YiboQuestBlocker/AccountPage.lua", "YiboCurrency/AccountPage.lua", "YiboReputation/AccountMatrixView.lua" }) do
    local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close()
    Check(not source:find("scrollbarGutter", 1, true) and not source:find("PREVIEW_SCROLLBAR_GUTTER", 1, true)
        and not source:find("GetScreenWidth", 1, true) and not source:find("GetPhysicalScreen", 1, true), path .. " delegates scroll/screen geometry to Core")
end

-- Actual initialization gates must reject v1 and missing public methods before registration/storage.
local originalHas, originalRegister, failures = Core.HasCapability, Core.RegisterAddon, 0
Core.RegisterAddon = function() error("unsupported Core must not register a business addon") end
local function LowBudget(_, name, version) return name ~= "account-surface-budget" or version <= 1 end
Core.HasCapability = LowBudget
dofile("YiboAltoBoss/CoreRequirements.lua")
Check(not YAB.CoreReady, "Boss early gate rejects old budget")
YAB.CoreReady = true; dofile("YiboAltoBoss/CoreIntegration.lua")
Check(not YAB.CoreIntegration:Initialize(), "Boss integration rejects old budget")
dofile("YiboCrafting/Bootstrap.lua")
local ok, errorMessage = YiboCrafting:Initialize()
Check(not ok and errorMessage:find("account-surface-budget:2", 1, true), "Crafting rejects old budget with upgrade detail")
SlashCmdList = SlashCmdList or {}
dofile("YiboLegendary/Bootstrap.lua")
YiboLegendary.Print = function() failures = failures + 1 end
local previousDB = YiboLegendary.db; YiboLegendary:Initialize()
Check(failures == 1 and YiboLegendary.db == previousDB, "Legendary rejects old budget before data initialization")
dofile("YiboQuestBlocker/Locale.lua")
Check(not YQB.CoreCompatible, "Quest early gate rejects old budget")
YQB.CoreCompatible = true; dofile("YiboQuestBlocker/CoreIntegration.lua")
Check(not YQB.CoreIntegration:Initialize(), "Quest integration rejects old budget")
Core.HasCapability = function() return true end
view.GetScrollSurfaceWidth = nil
dofile("YiboAltoBoss/CoreRequirements.lua")
Check(not YAB.CoreReady, "Boss rejects missing public width method")
Check(not YiboCrafting:Initialize(), "Crafting rejects missing public width method")
YiboLegendary:Initialize(); Check(failures == 2 and YiboLegendary.db == previousDB, "Legendary rejects missing public width method")
Check(not YQB.CoreIntegration:Initialize(), "Quest rejects missing public width method")
Core.HasCapability, Core.RegisterAddon = originalHas, originalRegister
view.GetColumnPageByWidth = nativeVariablePager
view.GetScrollSurfaceWidth, view.GetColumnPage = nativeBudget, nativePager
print("MatrixBudgetSpec: " .. checks .. " checks passed")
