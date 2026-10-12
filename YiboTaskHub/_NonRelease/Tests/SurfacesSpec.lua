-- Actual source/Core integration regression first, then actual account-view
-- admission/field contracts and all four task surfaces with controlled frames.
dofile("YiboTaskHub/_NonRelease/Tests/ActionIntegrationSpec.lua")
local Hub, Todo, Core = YiboTaskHub, YiboTodo, YiboCore
local checks, now, timers, notices = 0, 1000000, {}, {}
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
GetServerTime = function() return now end
GetGameTime = function() return 12, 0 end
local nativeCreate = CreateFrame
CreateFrame = function(...)
    local frame = nativeCreate(...)
    frame.GetFrameLevel = function() return 1 end
    frame.GetEffectiveScale = function() return 1 end
    frame.GetCenter = function(self) return 500, 400 end
    frame.IsShown = function(self) return self.shown end
    return frame
end
UIParent = CreateFrame("Frame"); UIParent:SetSize(1280, 720)
Hub.Print = function(_, message) notices[#notices + 1] = message end
local coreDB = { settings = {} }
Core.Database = { GetDB = function() return coreDB end }
Core.Characters.GetCurrentID = function() return Core.Characters:GetCurrent().id end
Core.Characters.GetAllCached = Core.Characters.GetAll
dofile("YiboCore/Util/CharacterSort.lua")
dofile("YiboCore/Util/LevelFilter.lua")
dofile("YiboCore/UI/AccountView.lua")
Equal(Core:HasCapability("account-character-admission", 1), true, "Core implements admission capability")
local view = Core.AccountView
view.RefreshPage = function() end -- no full WoW window shell in this harness
view.ShowPage = function(_, pageID) Core.lastPage = pageID end
Hub.CoreIntegration.initialized = false
assert(Hub.CoreIntegration:Initialize())
local page = view._pages.taskhub
Equal(page.previewEnabled, true)
Equal(type(page.settings.CreateSettingsPanel), "function", "hosted business settings")
Equal(#page.fields, 6, "Core main/preview field definitions")
Todo.Settings = { IsMonitoringGroupEnabled = function() return false end,
    IsMonitoringItemEnabled = function(_, _, id) return id == Todo.ActionNomi.GROUP end }
Todo.Snapshot:Invalidate()
assert(Todo.ActionContracts:Initialize())
local current = Core.Characters:GetCurrent()
local log = { { id = 31336, label = "第5课", complete = false } }
GetNumQuestLogEntries = function() return #log end
GetQuestLogTitle = function(index)
    local entry = log[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 1, entry and entry.id
end
local daily = Todo.Providers.Registry:Get("daily-quest")
assert(daily:Observe(current.id))

local admission = {}
Core.Events:Register("ACCOUNT_VIEW_CHARACTERS_CHANGED", "surface-audit", function(_, change) admission[#admission + 1] = change end)
view:SetCharacterHidden("U", true)
Equal(#admission, 1, "Core visibility publishes a fact")
view:SetCharacterHidden("U", true)
Equal(#admission, 1, "unchanged visibility does not publish")
Equal(admission[1].characterID, "U")
assert(page.characterFilter.SetExpression(""))
assert(#admission == 1, "initial empty filter is unchanged admission")
assert(page.characterFilter.SetExpression("90"))
Equal(admission[#admission].pageID, "taskhub", "Core page filter publishes a scoped fact")
local admissionCount = #admission
assert(page.characterFilter.SetExpression("90"))
Equal(#admission, admissionCount, "same page filter does not broadcast")
Equal(page.characterFilter.SetExpression("bad-expression"), false, "invalid page filter rejected")
Equal(#admission, admissionCount, "invalid page filter does not broadcast")
assert(page.characterFilter.SetExpression(""))
view:SetCharacterHidden("U", false)

C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
local function Flush()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end
Hub.Displays:Initialize()
Hub.Displays:Initialize()
Equal(#Core.Events._listeners.CHARACTER_DISPLAY_UPDATED, 1, "display initialization idempotent")
Equal(#notices, 0, "initial source settling delays summary")
now = now + 1; Flush()
Equal(#notices, 1, "one login summary")
local value, counts = Hub.Presentation:Current()
Equal(counts.actionable, 1, "only confirmed current Nomi is actionable")
Equal(counts.candidates, 0)
Equal(Hub.HUD.frame.shown, true)
Equal(Hub.HUD.frame.rows[1].row.task.identity, value.current[1].task.identity, "HUD uses same task identity")
Equal(Hub.HUD.frame.rows[1].cells[2].text, Hub.Presentation:Status(value.current[1]), "HUD source status formatting")
local context = view:BuildContext(page, { preview = true })
Equal(context.preview, true)
local preview = Hub.Preview:Build(context)
local allRows = Hub.AccountPage:Filter(Hub.Snapshot:Build(context.characters))
Equal(Hub.AccountPage:Stats(preview.rows), Hub.AccountPage:Stats(allRows), "preview/main same unique count")
local surface = CreateFrame("Frame"); surface:SetSize(820, 500)
Hub.AccountPage.Create(surface)
Hub.AccountPage.Refresh(surface, context)
Equal(surface.source.shown, false, "preview has no source editing button")
Equal(surface.taskPreview.shown, true)
Equal(surface.taskPreview.rows[1].scripts.OnClick, nil, "preview read only")
Equal(surface.taskPreview.rows[1].rule.height, 1, "preview one shared divider")
Equal(surface.taskPreview.rows[1].backdrop, nil, "preview no adjoining outer boxes")
assert(page.SetPreviewFieldVisible("source", false))
Equal(page.GetPreviewFields().source, false, "preview field stored through Core workbench callback")
local columns = Hub.Presentation:Columns(context)
Equal(#columns, 3, "hidden preview field honored")
assert(page.SetPreviewFieldVisible("source", true))
local mainContext = view:BuildContext(page)
view:SetFieldVisible("taskhub", "source", false)
Equal(#Hub.Presentation:Columns(mainContext), 5, "Core saves main-field selection")
Hub.AccountPage.Refresh(surface, mainContext)
Equal(surface.taskPreview.shown, false, "normal view restores after hover")
Equal(surface.source.shown, true)
view:SetFieldVisible("taskhub", "source", true)

local groups = {}; for i = 1, 20 do groups[i] = { rows = { {}, {} } } end
local plan, compact, omitted = Hub.Preview:Plan({ groups = groups, lines = 60 }, 700)
Equal(compact, true, "dense preview collapses role groups")
Equal(#plan, 20, "all 20 roles fit compact preview when space permits")
Equal(omitted, 0)
plan, compact, omitted = Hub.Preview:Plan({ groups = groups, lines = 60 }, 180)
Equal(#plan < 20, true, "small screen capacity is explicit")
Equal(#plan + omitted, 20, "no silently missing roles")

-- Exercise actual Core measurement before TASK renders its compact layout.
local originalBuild, originalCreate, originalShow = Hub.Preview.Build, view.CreateFrame, view.ShowPage
Hub.Preview.Build = function() return { groups = groups, lines = 60 } end
local shell = CreateFrame("Frame"); shell:Hide()
for _, key in ipairs({ "nav", "sortButton", "settingsButton", "close", "content", "pageIcon", "title", "titleBar", "version", "subtitle" }) do
    shell[key] = CreateFrame("Frame", nil, shell)
end
shell.GetLeft = function() return 100 end
shell.GetTop = function() return 680 end
view.CreateFrame = function() return shell end
local measured
view.ShowPage = function(_, _, options) measured = options.context end
Equal(Core:HasCapability("account-surface-budget", 1), true, "Core declares content height budget")
UIParent:SetHeight(900)
assert(view:ShowPreview("taskhub", nil, true))
Equal(measured.surfaceAvailableHeight, 820, "safe height excludes preview shell before measurement")
local expectedHeight = (20 + 2) * Core.UITheme.Table.rowHeight + Core.UITheme.Table.headerHeight + 12
Equal(shell:GetHeight(), expectedHeight + 48, "compact preview shell fits its 20 rendered rows")
UIParent:SetHeight(720)
local anchor = CreateFrame("Frame")
anchor.GetLeft = function() return 500 end; anchor.GetRight = function() return 530 end
anchor.GetTop = function() return 410 end; anchor.GetBottom = function() return 390 end
shell:Hide()
assert(view:ShowPreview("taskhub", anchor, true))
Equal(measured.surfaceAvailableHeight, 326, "anchored budget accounts for available opening direction")
Equal(shell:GetHeight() <= 374, true, "clipped compact rows stay in anchored room")
shell.preview = false; shell:Hide()
local mainBudget
local savedMetrics = page.GetSurfaceMetrics
page.GetSurfaceMetrics = function(context)
    mainBudget = context.surfaceAvailableHeight
    return { naturalContentWidth = 820, naturalContentHeight = 130 }
end
view:ApplyPageSize(page, view:BuildContext(page))
Equal(mainBudget, 560, "main measurement also excludes shell and safe margins")
page.GetSurfaceMetrics = savedMetrics
Hub.Preview.Build, view.CreateFrame, view.ShowPage = originalBuild, originalCreate, originalShow
view.previewAnchor = nil
local function Plain(text) return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
Equal(Plain(Hub.Preview:Status({ actionable = 0, preparation = 0, candidates = 0, unknown = 26 })), "待核实 26", "zero counts cannot hide unknown work")
Equal(Plain(Hub.Preview:Status({ actionable = 1, preparation = 0, candidates = 0, unknown = 26 })), "可推进 1 · 待核实 26", "compact state retains positive and unknown counts")

Hub.db.settings.sourceFilter = "not-the-current-source"
local independent, independentCounts = Hub.Presentation:Current()
Equal(independentCounts.actionable, counts.actionable, "HUD ignores main source filter")
Equal(Hub.db.settings.sourceFilter, "not-the-current-source", "HUD query does not alter main filter")
Hub.db.settings.sourceFilter = "all"
view:SetPageScope("taskhub", "realm:other")
Equal(Hub.Presentation:Current().currentAllowed, true, "HUD ignores main realm selection")
view:SetPageScope("taskhub", "all")

view:SetCharacterHidden(current.id, true); Flush()
Equal(Hub.HUD.frame.shown, false, "Core hide event immediately hides current HUD")
Equal(#notices, 1, "visibility update does not repeat summary")
view:SetCharacterHidden(current.id, false); Flush()
Equal(Hub.HUD.frame.shown, true)
assert(page.characterFilter.SetExpression("90")); Flush()
Equal(Hub.HUD.frame.shown, false, "Core level admission event refreshes HUD")
assert(page.characterFilter.SetExpression("")); Flush()
Equal(Hub.HUD.frame.shown, true)
Equal(#notices, 1, "level admission does not repeat login summary")
assert(Hub.Settings:Set("hudEnabled", false)); Flush()
Equal(Hub.HUD.frame.shown, false)
assert(Hub.Settings:Set("hudEnabled", true)); Flush()
Equal(Hub.HUD.frame.shown, true)
Equal(Hub.Settings:Set("hudRows", 99), false, "settings reject invalid capacity")
assert(Hub.Settings:Set("hudLocked", true)); Flush()
Hub.HUD:SavePosition()
Equal(Hub.db.settings.hudPosition.x, -140, "HUD stores only its own position")
Equal(Hub.db.settings.hudPosition.y, 40)
Hub.db.settings.hudPosition = { point = "bad", x = math.huge }
Hub.HUD:RestorePosition()
Equal(Hub.HUD.frame.point[1], "TOPRIGHT", "invalid position safely restores default")
Hub.db.settings.hudPosition = nil
local settingsHost = CreateFrame("Frame"); settingsHost:SetWidth(820)
local settingsPanel = page.settings.CreateSettingsPanel(settingsHost, {})
Equal(settingsPanel.height, 586, "hosted settings include shared item-action settings shortcut")
settingsHost:SetWidth(440); settingsPanel = page.settings.CreateSettingsPanel(settingsHost, {})
Equal(settingsPanel.height, 844, "narrow settings keep semantic groups intact")

assert(Core:RegisterAddon("SurfaceFixture", { requiredAPI = 11 }))
local state, validUntil = "active", now + 10
local function Query(request)
    local coverage = {}; for _, id in ipairs(request.scope.characterIDs) do coverage[id] = { state = "known" } end
    return { providerID = "SurfaceFixture:open", sourceEpoch = "fixture", revision = 1, generatedAt = now,
        status = "ready", coverage = coverage, data = { tasks = {
            { itemKey = "shared", title = "候选工作", businessRef = { capability = "action.todo", providerID = "SurfaceFixture:open", sourceEpoch = "fixture", key = "shared" },
                state = state, readiness = "actionable", execution = { mode = "open", candidateCharacterIDs = { current.id, "C", current.id } },
                beneficiary = { mode = "character", characterID = "F" }, temporal = { kind = "persistent" }, freshness = { state = "known", validUntil = validUntil } },
        } } }
end
local fixture = assert(Core.Contracts:Register("SurfaceFixture", { name = "action.todo", kind = "provider", providerID = "SurfaceFixture:open",
    version = { major = 1, minor = 0 }, methods = { Query = Query } }))
Flush()
value, counts = Hub.Presentation:Current()
Equal(counts.candidates, 1, "shared candidate counted once for current role")
Equal(counts.actionable, 1, "candidate separate from assigned work")
Equal(#notices, 1, "late provider does not repeat login summary")
Equal(Hub.HUD.frame.footer.text:find("新增 1", 1, true) ~= nil, true, "late work marked on HUD")
surface:SetHeight(180); surface.pageIndex = 1
Hub.AccountPage.Refresh(surface, view:BuildContext(page)); Flush()
Equal(next(Hub.Reminders.new) ~= nil, true, "unviewed later page keeps new-work marker")
surface.pageIndex = 2
Hub.AccountPage.Refresh(surface, view:BuildContext(page)); Flush()
Equal(next(Hub.Reminders.new), nil, "viewing the work page acknowledges its new marker")
surface:SetHeight(500); surface.pageIndex = 1
Hub.AccountPage.Refresh(surface, view:BuildContext(page)); Flush()
Equal(next(Hub.Reminders.new), nil, "viewing current rows acknowledges new work")
now = validUntil + 1; Flush()
value, counts = Hub.Presentation:Current()
Equal(counts.candidates, 0, "expired candidate not advertised as actionable")
Equal(counts.unknown > 0, true, "expired candidate retained as unknown")
local before = #notices
Hub.Reminders:Start(current.id); Hub.db.settings.reminderMode = "hud"
Hub.Reminders:Update(value, counts)
Equal(#notices, before, "HUD-only mode has no chat summary")
Hub.Reminders:Start(current.id); Hub.db.settings.reminderMode = "list"
InCombatLockdown = function() return true end
Core.lastPage = nil
Hub.Reminders:Update(value, counts)
Equal(Core.lastPage, nil, "list reminder waits during combat")
InCombatLockdown = function() return false end
Hub.Reminders:Update(value, counts)
Equal(Core.lastPage, "taskhub", "list reminder opens after combat")
Core.lastPage = nil; Hub.Reminders:Update(value, counts)
Equal(Core.lastPage, nil, "list reminder occurs once")

Core.Contracts:Unregister("SurfaceFixture", fixture)
Todo.ActionContracts:Shutdown()
Hub.db.settings.reminderMode = "summary"; Hub.Reminders:Start(current.id)
value, counts = Hub.Presentation:Current()
Equal(value.providerCount, 0)
before = #notices; Hub.Reminders:Update(value, counts)
Equal(Hub.Reminders.sent, false, "missing sources wait for first real snapshot")
Equal(#notices, before)
log = {}; assert(daily:Observe(current.id))
assert(Todo.ActionContracts:Initialize())
value, counts = Hub.Presentation:Current()
Equal(counts.actionable, 0, "unconfirmed daily never becomes a positive reminder")
Equal(counts.unknown, 1)
Hub.Reminders:Update(value, counts)
Equal(#notices, before + 1, "late first real snapshot gives exactly one summary")
Equal(notices[#notices]:find("待核实 1", 1, true) ~= nil, true, "unknown state explicit in summary")
Flush(); Flush()
Equal(#notices, before + 1, "deferred surface refresh does not duplicate first summary")

Hub.Displays:Shutdown()
Equal(#Core.Events._listeners.CHARACTER_DISPLAY_UPDATED, 0, "display subscription cleaned")
Equal(#Core.Events._listeners.ACCOUNT_VIEW_CHARACTERS_CHANGED, 1, "only test audit listener remains")
Equal(Hub.HUD.frame.shown, false, "display shutdown hides HUD")
Flush(); Equal(Hub.HUD.frame.shown, false, "retired callbacks cannot reopen HUD")
local originalCheck = Core.HasCapability
Core.HasCapability = function(self, capability, minimum) if capability == "account-character-admission" then return false end; return originalCheck(self, capability, minimum) end
Hub.CoreIntegration.initialized = false
Equal(Hub.CoreIntegration:Initialize(), nil, "missing new Core capability stops initialization")
Core.HasCapability = originalCheck
Core.HasCapability = function(self, capability, minimum) if capability == "account-surface-budget" then return false end; return originalCheck(self, capability, minimum) end
Equal(Hub.CoreIntegration:Initialize(), nil, "missing height contract explicitly stops initialization")
Core.HasCapability = originalCheck
Equal(YiboTaskHubDB.tasks, nil, "four surfaces never persist source tasks")
local saved = YiboTaskHubDB
YiboTaskHubDB = { schemaVersion = 1, settings = { sourceFilter = "kept", hudEnabled = false } }
assert(Hub.Database:Initialize())
Equal(Hub.db.schemaVersion, 4, "display and target schema migration")
Equal(Hub.db.settings.sourceFilter, "kept", "existing source filter preserved")
Equal(Hub.db.settings.hudEnabled, false, "explicit HUD preference preserved")
Equal(Hub.db.settings.hudRows, 5)
YiboTaskHubDB = { schemaVersion = 99 }
Equal(Hub.Database:Initialize(), nil, "future schema refused")
Equal(Hub.db, nil, "future schema cannot leave an initialized database handle")
YiboTaskHubDB = saved; assert(Hub.Database:Initialize())
Hub.db.goals = nil -- restore the historical action.todo fixture for dependent envelope tests
Todo.ActionContracts:Shutdown(); Hub.Contracts:Shutdown()
print("SurfacesSpec: " .. checks .. " checks passed")
