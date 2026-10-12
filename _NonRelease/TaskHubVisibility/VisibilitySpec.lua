dofile("YiboTaskHub/_NonRelease/Tests/ActionIntegrationSpec.lua")
local Hub, Core, checked = YiboTaskHub, YiboCore, 0
local function Equal(actual, expected, label)
    checked = checked + 1
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
assert(Hub.Contracts:Initialize())
local characters, current = Core.Characters:GetAll(), Core.Characters:GetCurrent()
local other; for _, c in ipairs(characters) do if c.id ~= current.id then other = c; break end end
local calls, source = 0, "VisibilityFixture:cooldowns"
local function Task(actor, id)
    local key = actor .. ":" .. id
    return { itemKey = key, title = id, displayGroup = { id = id, title = "冷却 " .. id },
        businessRef = { capability = "action.todo", providerID = source, sourceEpoch = "visibility", key = key },
        execution = { mode = "self", characterID = actor }, beneficiary = { mode = "character", characterID = actor },
        state = "active", readiness = "actionable", temporal = { kind = "daily" }, freshness = { state = "known" } }
end
local tasks = { Task(current.id, "a"), Task(current.id, "b"), Task(other.id, "a") }
local catalog = {}; for i = 1, 16 do catalog[i] = { id = tostring(i), title = "未采集冷却 " .. i } end
local definition = { kind = "provider", name = "action.todo", providerID = source, version = { major = 1, minor = 0 }, methods = { Query = function(request)
    calls = calls + 1
    local coverage, scoped = {}, {}
    for _, id in ipairs(request.scope.characterIDs) do coverage[id] = { state = "known" } end
    for _, task in ipairs(tasks) do if coverage[task.execution.characterID] then scoped[#scoped + 1] = task end end
    return { providerID = source, sourceTitle = "冷却来源", sourceEpoch = "visibility", revision = 1,
        generatedAt = GetServerTime(), status = "ready", coverage = coverage, displayGroups = catalog, data = { tasks = scoped } }
end } }
assert(Core:RegisterAddon("VisibilityFixture", { requiredAPI = 11 }))
local ref = assert(Core.Contracts:Register("VisibilityFixture", definition))
local function Count() return Hub.Snapshot:Build(characters).uniqueCount end
Equal(Count(), 3, "all work shown by default")
local option, options
options = Hub.Settings:WorkOptions()
for _, value in ipairs(options) do if value.key == Hub.Settings:WorkKey(source, "a") then option = value end end
Equal(#options, 19, "source directory includes unobserved cooldowns and source switch")
Hub.Settings:SetWorkVisible(option, false)
local before = calls
Equal(Count(), 1, "one cooldown hidden across all roles")
Equal(calls, before, "display toggle reuses source cache")
Equal(#Hub.Preview:Build({ characters = characters, scope = "all", preview = true }).rows, 1, "hover applies same visibility")
Core.AccountView.GetVisibleCharacters = function() return characters end
Equal(select(2, Hub.Presentation:Current()).actionable, 1, "HUD applies same visibility")
Equal(#tasks, 3, "source facts preserved")
Core.Contracts:Unregister("VisibilityFixture", ref)
Equal(#Hub.Settings:WorkOptions(), 1, "hidden choice remains recoverable without source")
ref = assert(Core.Contracts:Register("VisibilityFixture", definition))
Equal(Count(), 1, "re-registration preserves local visibility")
local sourceOption = { key = Hub.Settings:WorkKey(source), providerID = source, title = "全部工作", sourceTitle = "冷却来源" }
Hub.Settings:SetWorkVisible(sourceOption, false)
Equal(Count(), 0, "source switch hides all work")
Hub.Settings:SetWorkVisible(sourceOption, true)
Equal(Count(), 1, "restoring source preserves individual hidden choice")
Hub.Settings:SetWorkVisible(option, true)
Equal(Count(), 3, "restoring cooldown restores original work")
Equal(Hub.Snapshot:Build({ current }).uniqueCount, 2, "Core character admission is honored")

local host = CreateFrame("Frame"); host:SetWidth(820)
local panel = Hub.Settings:CreatePanel(host, {})
Equal(#panel.workChecks, 8, "wide settings have bounded two-column page")
local routed
Core.AccountView.ShowSettings = function(_, target) routed = target end
panel.roles.scripts.OnClick(); Equal(routed, "sorting", "role shortcut routes to Core")
panel.monitoring.scripts.OnClick(); Equal(routed, "todo", "monitoring shortcut routes to source settings")
panel.workNext.scripts.OnClick(); Equal(panel.workPage, 2, "settings next page")
panel.workPrev.scripts.OnClick(); Equal(panel.workPage, 1, "settings previous page")
local first = panel.workChecks[1]
first.scripts.OnClick()
Equal(first:GetChecked(), false, "actual checkbox click hides work")
first.scripts.OnClick()
Equal(first:GetChecked(), true, "actual checkbox click restores work")
Hub.Database:Initialize(); Hub.db.goals = nil -- historical action.todo envelope fixture
Equal(Count(), 3, "database reload keeps defaults and current visibility")

local h, header = Core.UITheme.Table.rowHeight, Core.UITheme.Table.headerHeight
local function Groups(currentCount)
    local groups = {}
    for i = 1, 20 do
        local entries = {}; for j = 1, (i == 1 and currentCount or (i == 17 and 6 or 17)) do entries[j] = { row = {} } end
        groups[i] = { current = i == 1, entries = entries, rows = entries }
    end
    return groups
end
local function Check(currentCount, slots)
    local groups = Groups(currentCount)
    local plan, _, omitted, remaining = Hub.Preview:Plan({ groups = groups, lines = 400 }, (slots + 2) * h + header + 12)
    local seen, details, expandedOthers = {}, 0, 0
    for _, token in ipairs(plan) do
        seen[token.group] = true
        if token.row then details = details + 1 end
        if token.heading and not token.group.current then expandedOthers = expandedOthers + 1 end
    end
    local roles = 0; for _ in pairs(seen) do roles = roles + 1 end
    Equal(expandedOthers, 0, "other roles never auto-expand")
    Equal(roles + omitted, 20, "all roles shown or explicitly counted")
    Equal(details + remaining, currentCount, "all current details shown or explicitly counted")
    Equal(#plan <= slots, true, "preview stays within row budget")
    return details
end
Equal(Check(6, 32), 6, "screenshot case only expands current role")
Equal(Check(20, 32), 12, "large current role gets partial detail")
Equal(Check(20, 20), 0, "roles retained before details")
Equal(Check(20, 4), 0, "small screen uses explicit remaining role count")
Equal(Check(6, 200), 6, "other roles remain summaries even with spare space")
print("TaskHubVisibility: " .. checked .. " checks passed")
