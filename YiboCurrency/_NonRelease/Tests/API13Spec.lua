-- Real Core runtime + Currency modules; frame measurements are simulated.
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local nodes, methods = {}, {}
local Node
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, callback) local previous = self.scripts[event]; self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 800 end
function methods:GetHeight() return self.height or 600 end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:GetParent() return self.parent end
function methods:SetText(value) self.text = tostring(value or "") end
function methods:GetText() return self.text or "" end
function methods:SetFont(path, size) self.fontSize = size end
function methods:GetFont() return "fixture", self.fontSize or 12, "" end
function methods:GetStringWidth() return #(self.text or "") * (self.fontSize or 12) * 0.5 end
function methods:GetStringHeight() return self.fontSize or 12 end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown == true end
function methods:IsVisible() return self.shown == true end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:CreateFontString() return Node(self) end
function methods:CreateTexture() return Node(self) end
Node = function(parent)
    local node = setmetatable({ parent = parent, scripts = {}, shown = true }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key:match("^Register") or key:match("^Enable") or key:match("^Bind") or key:match("^Refresh") then return function() end end
    end })
    nodes[#nodes + 1] = node; return node
end
CreateFrame = function(_, _, parent) return Node(parent) end
UIParent = Node(); UIParent:SetSize(1920, 1080)
GetServerTime = function() return 1792022400 end
GetLocale = function() return arg[1] or "zhCN" end
GetRealmName = function() return "Realm" end
UnitGUID = function() return "A-Realm" end
BreakUpLargeNumbers = tostring
STANDARD_TEXT_FONT = "fixture"
RAID_CLASS_COLORS = { MAGE = { r = 0.4, g = 0.8, b = 1 } }
GameTooltip = Node()
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " " .. right end
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Runtime/Locale.lua")
dofile("YiboCore/Locales/zhCN.lua")
dofile("YiboCore/Locales/enUS.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/Runtime/EntryConfig.lua")
dofile("YiboCore/Util/CharacterSort.lua")
local Core = YiboCore
Core.Print = function() end
local characters = { { id = "A-Realm", name = "Original", realm = "Realm", class = "MAGE" }, { id = "B-Other", name = "Other", realm = "Other", class = "MAGE" } }
local db = { settings = {}, characters = { byID = {}, aliases = {}, seenOrder = {} }, characterDisplay = { ["A-Realm"] = { shortName = "Short" } } }
for _, character in ipairs(characters) do db.characters.byID[character.id] = character end
Core.Database = { GetDB = function() return db end }
db.settings.language = arg[2] or "auto"
Core.Locale:Initialize()
dofile("YiboCore/Data/Characters.lua")
dofile("YiboCore/Data/CharacterCleanup.lua")
dofile("YiboCore/Runtime/ArchiveFields.lua")
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/UI/Input.lua")
Core.UITheme.CreateScrollFrame = function(_, parent) return Node(parent) end
dofile("YiboCore/UI/AccountView.lua")
Core._private.initialized = true
Core.RegisterAddon = function(self, name, metadata) return self.Registry:Register(name, metadata) end
Core.ClaimResource = function(self, kind, id, owner) return self.Registry:ClaimResource(kind, id, owner) end
Core.CreateItemPicker = function() end
Core.ItemResolver = {}
Core.ItemConfirmation = { Show = function() end }
Core.LevelFilter = { Validate = function(_, value) return true, value end }
local entryDefinition
Core.Entry = { RegisterBusinessEntry = function(_, _, definition) entryDefinition = definition; return definition end }
local snapshots = {}
for _, character in ipairs(characters) do snapshots[character.id] = { state = "known", updatedAt = 1000,
    data = { money = 10000, currencyState = "known", currencies = { [392] = { quantity = 42 } } } } end
Core.DataDomains = { Get = function(_, id, domain) return domain == "economy" and snapshots[id] or nil end, GetDefinitions = function() return {} end }
for name, version in pairs({ localization = 1, ["account-entry"] = 2, ["account-preview-field-groups"] = 1,
    ["data-domains"] = 1, ["basic-input"] = 1, ["item-resolver"] = 1, ["item-picker"] = 1 }) do Core.Capabilities:Register(name, version) end
YiboCurrencyDB = { version = 3, settings = { visible = { ["currency:392"] = false }, monitored = { money = true, ["currency:392"] = false }, customItems = {} } }
dofile("YiboCurrency/Bootstrap.lua")
dofile("YiboCurrency/Locales/zhCN.lua")
dofile("YiboCurrency/Locales/enUS.lua")
dofile("YiboCurrency/Catalog.lua")
dofile("YiboCurrency/Store.lua")
dofile("YiboCurrency/Migration.lua")
dofile("YiboCurrency/Scanner.lua")
dofile("YiboCurrency/ArchiveProvider.lua")
dofile("YiboCurrency/Data.lua")
dofile("YiboCurrency/VaultIntegration.lua")
dofile("YiboCurrency/Projection.lua")
dofile("YiboCurrency/AccountPage.lua")
dofile("YiboCurrency/GoalTargets.lua")
dofile("YiboCurrency/CoreIntegration.lua")
GetMoney = function() return 10000 end
C_CurrencyInfo = { GetCurrencyInfo = function(id) if id == 392 then return { name = "Honor", quantity = 42 } end end }
local Addon, view = YiboCurrency, Core.AccountView
local settings = Addon:GetSettings()
check(settings.previewColumns.money == true and settings.previewColumns["currency:392"] == false, "legacy monitored selection imports once with explicit false")
settings.previewColumns.money = false; Addon:EnsureDB()
check(not settings.previewColumns.money and settings.monitored.money, "repeated DB setup never reimports stale preferences")
-- Fail before registration, both for old API and missing capability/method.
Core.API_VERSION = 12
check(not Addon.CoreIntegration:Initialize() and not Core.Registry:Get(Addon.NAME), "old Core stops before registration")
Core.API_VERSION = 13
local originalHas = Core.HasCapability
Core.HasCapability = function(self, name, version) if name == "account-dynamic-fields" then return false end; return originalHas(self, name, version) end
check(not Addon.CoreIntegration:Initialize() and not Core.Registry:Get(Addon.NAME), "missing dynamic-field capability stops initialization")
Core.HasCapability = function(self, name, version) if name == "account-surface-budget" then return version <= 1 end; return originalHas(self, name, version) end
check(not Addon.CoreIntegration:Initialize() and not Core.Registry:Get(Addon.NAME), "old scroll budget stops before registration")
Core.HasCapability = originalHas
local originalFormat = Core.Characters.FormatName; Core.Characters.FormatName = nil
check(not Addon.CoreIntegration:Initialize(), "missing actual method stops initialization")
Core.Characters.FormatName = originalFormat
check(Addon.CoreIntegration:Initialize(), "API13 core initializes without Vault or optional goal actions")
check(not Addon.GoalTargets.ref, "missing goal actions disable only the enhancement")
check(Core.Registry:Get(Addon.NAME).requiredAPI == 13, "registered version gate is API13")
check(not entryDefinition.defaultChannels.minimap and not entryDefinition.defaultChannels.broker and not entryDefinition.defaultChannels.builtinBar, "all three entry channels default off")
local page = view._pages.currency
check(#view:GetFieldDefinitions("currency") == #Addon:GetCatalog(), "Core receives each catalog entry as a field")
check(not Addon:IsVisible({ id = "currency:392" }), "legacy main choice seeds the default")
view:SetFieldVisible("currency", "currency:392", true)
check(Addon:IsVisible({ id = "currency:392" }) and settings.visible["currency:392"] == false, "Core becomes the authoritative main visibility override")
check(page.SetPreviewFieldVisible("money", true) and not page.SetPreviewFieldVisible("invalid", true), "preview setter validates stable catalog IDs")
local copy = page.GetPreviewFields(); copy.money = false
check(settings.previewColumns.money, "preview selections return a copy")
local before = #view:GetFieldDefinitions("currency")
GetItemInfo = function(id) return "Custom " .. id end
check(Addon:AddCustomItem(123), "custom token can be added")
check(#view:GetFieldDefinitions("currency") == before + 1, "dynamic main and preview options include a newly added token without reload")
page.SetPreviewFieldVisible("item:123", true)
view:SetFieldVisible("currency", "item:123", false)
check(Addon:RemoveCustomItem(123) and not settings.previewColumns["item:123"], "removal clears preview selection")
check(#view:GetFieldDefinitions("currency") == before, "removed token disappears from definitions")
local fields = view:GetFieldDefinitions("currency"); fields[1].title = "tampered"
check(view:GetFieldDefinitions("currency")[1].title ~= "tampered", "dynamic definitions return deep copies")
-- Static consumers retain their existing visibility behavior.
check(view:RegisterPage(Addon.NAME, { id = "static-test", title = "Static", Create = function() end, Refresh = function() end,
    fields = { { id = "one", title = "One" }, { id = "two", title = "Two", defaultVisible = false } } }), "static page registration stays compatible")
check(#view:GetVisibleFields("static-test") == 1, "static field defaults stay compatible")
local bad = { id = "bad-fields", title = "Bad", Create = function() end, Refresh = function() end,
    GetFieldDefinitions = function() return { { id = "same", title = "One" }, { id = "same", title = "Two" } } end }
check(view:RegisterPage(Addon.NAME, bad), "dynamic callback registers without evaluating business state early")
local invalid, code = view:GetFieldDefinitions("bad-fields")
check(#invalid == 0 and code == "invalid-field-definitions", "duplicate dynamic IDs fail safely")
view._pages["bad-fields"].GetFieldDefinitions = function() error("bad provider") end
invalid, code = view:GetFieldDefinitions("bad-fields")
check(#invalid == 0 and code == "field-definitions-error", "callback exceptions do not escape into shared UI")
-- Same matrix renderer, shared values and totals for main and hover.
local parent = Node(UIParent); parent:SetSize(1400, 600); Addon:CreateCurrencyPage(parent)
local context = { characters = characters, scope = "all", preview = false, surfaceAvailableWidth = 1400 }
Addon:RefreshCurrencyPage(parent, context)
check(parent.currencyHeaders[3].label:GetText() == "Short", "shared header honors Core short names")
local mainTotal = parent.currencyRows[1].cells[2]:GetText()
context = { characters = characters, scope = "all", preview = true, surfaceAvailableWidth = 1400 }
Addon:RefreshCurrencyPage(parent, context)
check(parent.currencyHeaders[3].label:GetText() == "Short" and parent.currencyRows[1].cells[2]:GetText() == mainTotal, "hover shares main orientation, names and totals")
check(parent.currencyRows[1].entry.id == "money" and not parent.currencyRows[2]:IsShown(), "hover displays selected currencies only")
local narrow = Addon:GetCurrencySurfaceMetrics({ characters = characters, scope = "all", preview = false })
check(narrow.naturalContentWidth > narrow.minContentWidth, "all characters participate in natural width before paging")
local only = Addon:GetCurrencySurfaceMetrics({ characters = { characters[1] }, scope = "all", preview = false })
check(only.naturalContentWidth < narrow.naturalContentWidth, "natural width scales with the complete eligible roster")
local money = { source = "money" }
local english = Core.Locale:GetLanguage() == "en"
check(Addon:FormatCompact({ quantity = 294000 }) == (english and "294k" or "29.4万"), "compact count uses correct locale units")
check(Addon:FormatCompact({ quantity = 2940000000 }, money) == (english and "294k" or "29.4万"), "gold converts copper before formatting")
check(#Core.Locale:GetMissingEnglish("YiboCurrency") == 0, "all owner resources have English")
local language = Core.Locale:GetLanguage()
Core.Locale:SetPreference(language == "en" and "zh" or "en")
check(Core.Locale:GetLanguage() == language and Core.Locale:IsReloadPending(), "manual language preference takes effect on reload only")
-- Goal provider uses the same native balance when optional capabilities exist.
Core.BusinessItemActions = { Bind = function() end, Handle = function() return false end,
    Unbind = function() end, GestureLabel = function() return "Ctrl+Left" end }
Core.Capabilities:Register("business-item-actions", 1)
check(Addon.GoalTargets:Initialize(), "compatible target actions enable the optional goal provider")
local goal = { id = "goal-1", intent = { objectID = "currency:392", conditions = { quantity = 40, mode = "maintain" }, scope = { characterID = "A-Realm" } } }
local result = Addon.GoalTargets:Evaluate({ goals = { goal } })
check(result.evaluations[goal.id].task.state == "completed", "goal provider consumes the same currency quantity")
Addon.Store.db.characters["A-Realm"].native.state = "stale"
result = Addon.GoalTargets:Evaluate({ goals = { goal } })
check(result.evaluations[goal.id].task.readiness == "unknown", "stale currency snapshot cannot satisfy a goal")
Addon.Store.db.characters["A-Realm"].native.state = "known"
-- Idempotent integration must not create duplicate pages or subscriptions.
local count = #view._pageOrder
check(Addon.CoreIntegration:Initialize() and #view._pageOrder == count, "initialization is idempotent")
-- Layout regression: a complete 13-character roster fits before pagination.
check(page.autoFitWidth == true, "main page expands instead of keeping an undersized saved width")
local roster = {}
for i = 1, 13 do roster[i] = { id = "R" .. i, name = "R" .. i, realm = "Realm", class = "MAGE" } end
local pageInfo
local updatePager = view.UpdateColumnPager
view.UpdateColumnPager = function(_, _, _, _, info) pageInfo = info end
Addon:RefreshCurrencyPage(parent, { characters = roster, scope = "all", preview = false, surfaceAvailableWidth = 1100 })
check(pageInfo.pages == 1 and pageInfo.last == 13, "all 13 characters fit the compact main matrix")
local visibleHeaders = 0
for _, header in ipairs(parent.currencyHeaders) do if header:IsShown() then visibleHeaders = visibleHeaders + 1 end end
check(visibleHeaders == 15 and parent.currencyBody:GetWidth() <= 1100, "complete main matrix stays inside available width")
Addon:RefreshCurrencyPage(parent, { characters = roster, scope = "all", preview = false, surfaceAvailableWidth = 360 })
check(pageInfo.pages > 1, "only real screen overflow retains Core safety pagination")
settings.hoverTranspose = true
settings.previewColumns["currency:392"] = true
local previewContext = { characters = characters, scope = "all", preview = true, surfaceAvailableWidth = 1400 }
local moneyEntry = Addon:GetDisplayCatalog(true)[1]
local normalTotal = Addon:ProjectionTotal(Addon:GetCurrencyProjection(previewContext, characters, Addon:GetDisplayCatalog(true)), characters, moneyEntry)
Addon:RefreshCurrencyPage(parent, previewContext)
check(parent.currencyRows[1].entry.kind == "total" and parent.currencyRows[2].entry.character.id == characters[1].id, "transposed hover has total then character rows")
check(parent.currencyRows[1].cells[2]:GetText():find(Addon:FormatCompact({ quantity = normalTotal.quantity }, moneyEntry), 1, true), "transposed total uses the same full-roster projection")
local transposedValue, transposedState = Addon:ProjectionValue(parent.currencyRows[2].projection, characters[1], moneyEntry)
check(parent.currencyRows[2].cells[2]:GetText() == Addon:FormatLimitCell(transposedValue, transposedState, moneyEntry, Addon.FormatCell), "transposed value agrees with source snapshot")
local transposedMetrics = Addon:GetCurrencySurfaceMetrics(previewContext)
check(transposedMetrics.naturalContentHeight >= (#characters + 1) * Core.UITheme.Table.rowHeight, "hover sizing measures every transposed row")
Addon:RefreshCurrencyPage(parent, { characters = characters, scope = "all", preview = false, surfaceAvailableWidth = 1400 })
check(parent.currencyRows[1].entry.id == "money", "hover transpose never transposes the main window")
settings.hoverTranspose = false
Addon:RefreshCurrencyPage(parent, previewContext)
check(parent.currencyRows[1].entry.id == "money" and parent.currencyHeaders[3]:IsShown(), "switching transpose off restores pooled matrix frames")
-- Natural sizing must budget the scrollbar before a minimum-width roster is paged.
local originalCatalog, originalColumnWidth = Addon.Catalog, Core.UITheme.GetCharacterMatrixColumnWidth
Addon.Catalog = {}
for i = 1, 54 do Addon.Catalog[i] = { id = "test:" .. i, source = "money", title = "Gold " .. i } end
Core.UITheme.GetCharacterMatrixColumnWidth = function() return 52 end
local naturalContext = { characters = roster, scope = "all", preview = false }
local originalCreate = view.CreateFrame
local shell = Node(UIParent); shell:SetSize(760, 640)
view.CreateFrame = function() return shell end
view:ApplyPageSize(page, naturalContext)
local completeWidth = shell:GetWidth() - Core.UITheme:GetNavigationWidth() - Core.UITheme.Geometry.shellBorder * 2 - 1
naturalContext.surfaceAvailableWidth = completeWidth
view.CreateFrame = originalCreate
Addon:RefreshCurrencyPage(parent, naturalContext)
check(pageInfo.pages == 1 and pageInfo.last == 13, "natural width includes scrollbar and keeps every minimum-width character column")
check(parent.currencyBody:GetWidth() <= completeWidth - Core.UITheme.Geometry.scrollbarGutter, "natural matrix leaves the scrollbar outside data columns")
Addon.Catalog, Core.UITheme.GetCharacterMatrixColumnWidth = originalCatalog, originalColumnWidth
Addon:RefreshCurrencyPage(parent, { characters = characters, scope = "all", preview = false, surfaceAvailableWidth = 1400 })
local tooltipRow = parent.currencyRows[1]
tooltipRow.scripts.OnEnter(tooltipRow)
check(#GameTooltip.lines == 3 and GameTooltip.lines[1] == tooltipRow.entry.title, "row tooltip keeps name, total and action without a duplicate roster")
tooltipRow.goalHits[3].scripts.OnEnter()
check(#GameTooltip.lines <= 6 and GameTooltip.lines[3]:find("Short", 1, true), "cell tooltip adds only the hovered character")
-- Exercise both display surfaces with the same built-in/custom row handlers.
local function FindRow(host, id)
    for _, row in ipairs(host.currencyRows) do if row:IsShown() and row.entry.id == id then return row end end
end
local function MainContext() return { characters = characters, scope = "all", preview = false, surfaceAvailableWidth = 1400 } end
local function HoverContext() return { characters = characters, scope = "all", preview = true, surfaceAvailableWidth = 1400 } end
check(Addon:AddCustomItem(123), "custom currency registers after frame pool was used by built-in currencies")
check(Addon.Store:Commit(characters[1].id, "carriedTokens", { items = { [123] = { carried = 7 } } }, "known"), "custom balance snapshot is valid")
Addon:RefreshCurrencyPage(parent, MainContext())
local customRow = FindRow(parent, "item:123")
check(customRow and customRow.hoverToggle:IsShown() and not customRow.hoverToggle:GetChecked(), "new custom currency has an explicit unchecked hover control")
customRow.goalHits[1].scripts.OnClick(customRow.goalHits[1], "RightButton")
check(Addon:IsMonitored(customRow.entry) and Addon:IsVisible(customRow.entry), "custom name-cell right-click changes hover only")
Addon:RefreshCurrencyPage(parent, HoverContext())
customRow = FindRow(parent, "item:123")
check(customRow and customRow.cells[3]:GetText():find("7", 1, true) and not customRow.hoverToggle:IsShown(), "custom currency actually renders its source balance in read-only hover")
Addon:RefreshCurrencyPage(parent, MainContext())
customRow = FindRow(parent, "item:123")
customRow.goalHits[3].scripts.OnClick(customRow.goalHits[3], "RightButton")
check(not Addon:IsMonitored(customRow.entry) and Addon:IsVisible(customRow.entry), "custom value-cell right-click cancels hover without removing the catalog entry")
customRow.hoverToggle.scripts.OnClick(customRow.hoverToggle)
check(Addon:IsMonitored(customRow.entry), "explicit hover checkbox uses the same selection as right-click")
check(Addon:SetCurrencyDisplay("item:123", "main", false), "custom main visibility can be disabled independently")
Addon:RefreshCurrencyPage(parent, MainContext())
check(not FindRow(parent, "item:123"), "main-hidden custom entry is absent from main rows")
Addon:RefreshCurrencyPage(parent, HoverContext())
check(FindRow(parent, "item:123"), "main-hidden custom entry remains in hover when selected")
local hoverRow = FindRow(parent, "item:123")
hoverRow.scripts.OnClick(hoverRow, "RightButton")
check(Addon:IsMonitored(hoverRow.entry), "preview right-click cannot accidentally remove a selected entry")

-- Real settings rows and callbacks against real Core field storage.
local originalPicker = Core.CreateItemPicker
Core.CreateItemPicker = function(_, owner, config)
    local picker = Node(owner); picker.config = config; picker.input = Node(picker)
    function picker:Layout(width) self.layoutContentWidth = width - Core.UITheme.Space.md; return Core.UITheme.Size.standard end
    function picker:SetValue(value) self.input:SetText(value) end
    return picker
end
dofile("YiboCurrency/Settings.lua")
local host, settingsContext = Node(UIParent), { notifyPageChanged = function() end }
host:SetWidth(1100)
settingsContext.refreshPanel = function() Addon:CreateSettingsPanel(host, settingsContext) end
settingsContext.refreshPage = settingsContext.refreshPanel
settingsContext.refreshPanel()
local panel = host.ycuSettings
panel.catalogTabs.custom.scripts.OnClick()
check(panel.catalogFilter == "custom" and panel.rows[1].entry.id == "item:123", "custom tab uses the same display editor as built-in currencies")
check(not panel.rows[1].main:GetChecked() and panel.rows[1].hover:GetChecked(), "settings reads independent main and hover flags")
panel.rows[1].main.scripts.OnClick(panel.rows[1].main)
check(Addon:IsVisible(panel.rows[1].entry) and panel.rows[1].hover:GetChecked(), "settings main checkbox keeps existing hover selection")
panel.rows[1].hover.scripts.OnClick(panel.rows[1].hover)
check(not Addon:IsMonitored(panel.rows[1].entry) and panel.rows[1].main:GetChecked(), "settings hover checkbox keeps main visibility")
check(page.SetPreviewFieldVisible("item:123", true), "Core display settings share the custom hover setter")
settingsContext.refreshPanel()
check(panel.rows[1].hover:GetChecked(), "Currency settings reflect Core preview-field changes")
-- Sweep every real catalog ID, including gold, native currencies, curated
-- item tokens and the custom token, across every main/hover combination.
local function SettingsRow(entry)
    local filter, index = entry.isCustom and "custom" or "builtin", 0
    for _, item in ipairs(Addon:GetCatalog()) do
        if (item.isCustom and "custom" or "builtin") == filter then index = index + 1 end
        if item.id == entry.id then break end
    end
    panel.catalogFilter, panel.catalogPage = filter, math.floor((index - 1) / 24) + 1
    settingsContext.refreshPanel()
    for _, row in ipairs(panel.rows) do if row:IsShown() and row.entry.id == entry.id then return row end end
    error("Settings omitted " .. entry.id)
end
local catalogUnderReview = Addon:GetCatalog()
for _, entry in ipairs(catalogUnderReview) do
    local originalMain, originalHover = Addon:IsVisible(entry), Addon:IsMonitored(entry)
    for _, mainShown in ipairs({ false, true }) do
        for _, hoverShown in ipairs({ false, true }) do
            local edit = SettingsRow(entry)
            if edit.main:GetChecked() ~= mainShown then edit.main.scripts.OnClick(edit.main); edit = SettingsRow(entry) end
            if edit.hover:GetChecked() ~= hoverShown then edit.hover.scripts.OnClick(edit.hover); edit = SettingsRow(entry) end
            check(edit.main:GetChecked() == mainShown and edit.hover:GetChecked() == hoverShown, entry.id .. " settings preserve both independent choices")
            Addon:RefreshCurrencyPage(parent, MainContext())
            check((FindRow(parent, entry.id) ~= nil) == mainShown, entry.id .. " main rendering matches settings")
            Addon:RefreshCurrencyPage(parent, HoverContext())
            check((FindRow(parent, entry.id) ~= nil) == hoverShown, entry.id .. " hover rendering matches settings")
        end
    end
    Addon:SetCurrencyDisplay(entry.id, "main", true)
    Addon:SetCurrencyDisplay(entry.id, "hover", false)
    Addon:RefreshCurrencyPage(parent, MainContext())
    local source = FindRow(parent, entry.id)
    for _, target in ipairs({ source, source.goalHits[1], source.goalHits[3], source.hoverToggle }) do
        local wasSelected = Addon:IsMonitored(entry)
        target.scripts.OnClick(target, target == source.hoverToggle and "LeftButton" or "RightButton")
        local edit = SettingsRow(entry)
        check(edit.hover:GetChecked() ~= wasSelected and edit.main:GetChecked(), entry.id .. " right-click/checkbox synchronizes settings without changing main visibility")
        Addon:RefreshCurrencyPage(parent, HoverContext())
        check((FindRow(parent, entry.id) ~= nil) == edit.hover:GetChecked(), entry.id .. " hover reflects each main-window action")
        Addon:RefreshCurrencyPage(parent, MainContext())
        source = FindRow(parent, entry.id)
    end
    check(page.SetPreviewFieldVisible(entry.id, true) and SettingsRow(entry).hover:GetChecked(), entry.id .. " Core preview editor synchronizes Currency settings")
    Addon:SetCurrencyDisplay(entry.id, "main", originalMain)
    Addon:SetCurrencyDisplay(entry.id, "hover", originalHover)
end
check(not Addon:RemoveCustomItem(43589) and Addon:GetCatalogEntry("item:43589"), "curated built-in item cannot be removed as a custom currency")
check(Addon:RemoveCustomItem(123) and not settings.previewColumns["item:123"], "catalog removal clears custom hover choice")
check(Addon.Store:Get(characters[1].id, "carriedTokens").data.items[123].carried == 7, "catalog removal preserves recorded inventory data")
check(not Addon:ToggleHoverCurrency("item:123") and not Addon:SetCurrencyDisplay("item:123", "main", true), "stale controls cannot recreate removed catalog selections")
Core.CreateItemPicker = originalPicker
view.UpdateColumnPager = updatePager
print("API13Spec (" .. Core.Locale:GetLanguage() .. "): " .. checks .. " checks passed")
