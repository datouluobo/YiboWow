-- Full real integration regressions, then dense overview interaction scenarios.
dofile("YiboTaskHub/_NonRelease/Tests/MailSourceSpec.lua")
local Hub, Core, checks = YiboTaskHub, YiboCore, 0
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local characters, current = Core.Characters:GetAllCached(), Core.Characters:GetCurrent()
local others = {}; for _, character in ipairs(characters) do if character.id ~= current.id then others[#others + 1] = character end end
local tasks, now = {}, GetServerTime()
local function Work(key, actor, state, beneficiary)
    local task = { itemKey = key, title = "来源工作 " .. key, quantity = 1,
        businessRef = { capability = "action.todo", providerID = "OverviewFixture:work", sourceEpoch = "fixture", key = key },
        execution = { mode = beneficiary and "assigned" or "self", characterID = actor },
        beneficiary = { mode = "character", characterID = beneficiary or actor },
        state = "active", readiness = state, temporal = { kind = "persistent" },
        freshness = { state = state == "unknown" and "stale" or "known", observedAt = now },
        nextAction = { kind = "open-page", title = "查看来源", pageID = "fixture-target" } }
    tasks[#tasks + 1] = task; return task
end
Work("current-ready", current.id, "actionable").icon = "Interface\\Icons\\INV_Letter_15"
for i = 1, 10 do Work("current-unknown-" .. i, current.id, "unknown").quantity = i end
for i = 1, 60 do Work("other-unknown-" .. i, others[1].id, "unknown") end
Work("other-beneficiary", others[1].id, "unknown", current.id)
Work("other-ready", others[2].id, "actionable")
local shared = Work("shared", current.id, "unknown")
shared.execution = { mode = "open", candidateCharacterIDs = { current.id, others[2].id } }
assert(Core:RegisterAddon("OverviewFixture", { requiredAPI = 11 }))
local provider = assert(Core.Contracts:Register("OverviewFixture", { name = "action.todo", kind = "provider", providerID = "OverviewFixture:work",
    version = { major = 1, minor = 0 }, methods = { Query = function(request)
        local coverage = {}; for _, id in ipairs(request.scope.characterIDs) do coverage[id] = { state = "known" } end
        local scoped = {}
        for _, task in ipairs(tasks) do
            if coverage[task.execution.characterID] or task.execution.mode == "open" then scoped[#scoped + 1] = task end
        end
        return { providerID = "OverviewFixture:work", sourceEpoch = "fixture", revision = 1, generatedAt = now,
            sourceTitle = "测试业务", status = "ready", coverage = coverage, data = { tasks = scoped } }
    end } }))
assert(Hub.Contracts:Initialize())
Hub.db.settings.sourceFilter, Hub.db.settings.workFilter = "all", "all"
local value = Hub.Snapshot:Build(characters)
local raw = Hub.AccountPage:Filter(value)
Equal(value.uniqueCount, 74, "source identity count unchanged")
Equal(#raw, 75, "shared candidate has two role projections")
Equal(Hub.AccountPage:Stats(raw), 74, "account statistics deduplicate shared work")
local organized = Hub.AccountPage:Organize(raw, {})
Equal(#organized, 7, "dense unknown work folds without folding confirmed actions")
local group
for _, pair in ipairs(organized) do if pair.members and pair.section == "current" then group = pair end end
Equal(#group.members, 10, "candidate kept separate from assigned work")
Equal(group.row.task.quantity, 1, "first task quantity not replaced by group count")
local expanded = Hub.AccountPage:Organize(raw, { [group.groupKey] = true })
Equal(#expanded, 17, "expansion includes all original members")
local quantities = 0; for _, row in ipairs(group.members) do quantities = quantities + row.task.quantity end
Equal(quantities, 55, "individual quantities retained")
Equal(#Hub.Presentation:GroupDetails(value.byCharacter[others[1].id], { scope = "all" }) <= 18, true, "large tooltip has bounded detail and explicit remaining count")

local context = Core.AccountView:BuildContext(Hub.CoreIntegration.page)
local frame = CreateFrame("Frame"); frame:SetSize(1040, 500)
Hub.AccountPage.Create(frame); Hub.AccountPage.Refresh(frame, context)
Equal(#frame.displayRows, 7)
Equal(frame.displayRows[4].row.task.itemKey, "other-ready", "other actionable work precedes unknown-only roles")
Equal(frame.rows[1].identities[1].shown, true, "role column uses shared identity control")
Equal(frame.rows[1].identities[1].secondary.shown, false, "compact task rows keep one line")
Equal(frame.rows[1].identities[1].tooltipTitle, current.name, "Core owns role identity tooltip")
Equal(frame.source.options[2].value, "OverviewFixture:work", "source is a selectable Core dropdown")
Equal(frame.rows[2].action.label.text, "展开 10")
Equal(frame.summary.text:find("74 项工作", 1, true) ~= nil, true, "grouping does not reduce account total")
Equal(frame.bars[1].cells[6].text:find("待核实 11", 1, true) ~= nil, true, "section statistics count raw work")
frame.rows[2].action.scripts.OnClick(frame.rows[2].action)
Equal(#frame.displayRows, 17, "row button expands actual view")
Equal(frame.rows[2].action.label.text, "收起 10")
frame.rows[2].scripts.OnMouseUp(frame.rows[2], "LeftButton")
Equal(#frame.displayRows, 7, "row click collapses actual view")
frame.workFilter.onValueChanged("ready")
Equal(#frame.displayRows, 2, "ready filter includes current and other confirmed work")
Equal(frame.rows[2].group, nil, "pooled row clears former expansion behavior")
Equal(frame.rows[2].action.label.text, "查看来源")
Core.lastPage = nil; frame.rows[2].action.scripts.OnClick(frame.rows[2].action)
Equal(Core.lastPage, "fixture-target", "reused action navigates to original business page")
Equal(frame.rows[1].workIcon.texture.texturePath, "Interface\\Icons\\INV_Letter_15", "source-supplied icon displayed in bordered control")
frame.workFilter.onValueChanged("unknown")
Equal(Hub.AccountPage:Stats(Hub.AccountPage:Filter(value)), 72, "unknown filter preserves unique count")
local _, counts = Hub.Presentation:Current()
Equal(counts.actionable, 1, "HUD ignores overview status filtering")
local previewContext = Core.AccountView:BuildContext(Hub.CoreIntegration.page, { preview = true })
Equal(Hub.AccountPage:Stats(Hub.Preview:Build(previewContext).rows), 72, "preview honors same status filter")
frame.pageIndex = 9; Hub.db.settings.sourceFilter = "OverviewFixture:work"
Core.AccountView:SetPageScope(Hub.PAGE_ID, "realm:other")
Hub.HUD:Create().open.scripts.OnClick()
Hub.AccountPage.Refresh(frame, context)
Equal(frame.pageIndex, 1, "HUD list resets stale page")
Equal(Hub.db.settings.sourceFilter, "all", "HUD list opens all current sources")
Equal(Hub.db.settings.workFilter, "all", "HUD list clears hiding status filter")
Equal(Core.AccountView:BuildContext(Hub.CoreIntegration.page).scope, "all", "list entry includes current realm regardless of old scope")
Equal(frame.rows[1].row.task.itemKey, "current-ready", "current work is visible at list entry")
local originalName, nameOptions = Core.Characters.FormatName
Core.Characters.FormatName = function(_, _, options) nameOptions = options; return "角色" end
Hub.AccountPage:CharacterLabel(current, { scope = "all" })
Equal(nameOptions.realmMode, "sameRealm", "compact names use Core same-realm policy")
Equal(nameOptions.referenceRealm, current.realm)
Hub.Presentation:Details(value.current[1], { scope = "all" })
Equal(nameOptions.realmMode, "full", "details retain complete identity")
Core.Characters.FormatName = originalName
local sharedHeader, headerCalls = Core.UITheme.SetCharacterHeader, 0
Core.UITheme.SetCharacterHeader = function(self, header, character, ctx, options)
    headerCalls = headerCalls + 1
    return sharedHeader(self, header, character, ctx, options)
end
Hub.AccountPage.Refresh(frame, previewContext)
Equal(headerCalls > 0, true, "hover reuses Core identity rendering too")
Core.UITheme.SetCharacterHeader = sharedHeader
local actualPreview = Hub.Preview:Build(previewContext)
Equal(actualPreview.groups[2].character.id, others[2].id, "hover prioritizes other actionable role over unknown-only role")

-- Dense preview spends spare lines on confirmed work while retaining all roles.
local groups = {}
for i = 1, 20 do
    local row = value.current[1]
    groups[i] = { character = { id = tostring(i) }, rows = { row }, entries = { { row = row } },
        counts = { rows = {}, actionable = 0, preparation = 0, candidates = 0, unknown = 1 } }
end
groups[1].counts.rows = { value.current[1] }; groups[1].counts.actionable = 1
groups[1].current = true
groups[1].entries = {}; for i = 1, 6 do groups[1].entries[i] = { row = value.current[1] } end
local theme = Core.UITheme
local height = 28 * theme.Table.rowHeight + 2 * theme.Table.rowHeight + theme.Table.headerHeight + 12
local plan, compact, omitted = Hub.Preview:Plan({ groups = groups, lines = 45 }, height)
local seen, shownRoles = {}, 0
for _, token in ipairs(plan) do if not seen[token.group] then seen[token.group] = true; shownRoles = shownRoles + 1 end end
Equal(compact, true)
Equal(shownRoles, 20, "mixed preview retains every admitted role")
Equal(plan[1].heading, true, "confirmed current work gets concept-style heading")
Equal(plan[2].row ~= nil, true, "confirmed current work remains visible as detail")
Equal(omitted, 0)

-- Resolve existing item metadata through Core, with one bounded request.
local resolver, originalInfo, originalRequest = Core.ItemResolver, Core.ItemResolver.GetInfo, Core.ItemResolver.Request
local requests, callback, ready = 0, nil, false
resolver.GetInfo = function() return { state = ready and "ready" or "unloaded", icon = ready and "loaded-icon" or nil } end
resolver.Request = function(_, _, handler) requests = requests + 1; callback = handler end
Hub.Presentation.itemRequests = {}
local itemTask = { title = "物品工作", item = { itemID = 98619 }, temporal = { kind = "daily" } }
Hub.Presentation:WorkText(itemTask); Hub.Presentation:WorkText(itemTask)
Equal(requests, 1, "repeated render shares Core item request")
ready = true; callback({ icon = "loaded-icon" })
Equal(Hub.Presentation:WorkText(itemTask):find("loaded-icon", 1, true) ~= nil, true, "loaded icon replaces fallback")
resolver.GetInfo, resolver.Request = originalInfo, originalRequest
local result = Hub.Contracts:GetResults(characters)[1]
result.result.data.tasks[1].icon = "bad|Tmarkup"
Equal(Hub.Snapshot:ValidateResult(result.result, result.descriptor, { current.id, others[1].id, others[2].id, others[3].id }), nil, "invalid icon metadata rejected")
local originalCapability = Core.HasCapability
Core.HasCapability = function(self, name, minimum) if name == "item-resolver" then return false end; return originalCapability(self, name, minimum) end
Hub.CoreIntegration.initialized = false
Equal(Hub.CoreIntegration:Initialize(), nil, "missing Core resolver explicitly stops initialization")
Core.HasCapability = originalCapability
local headerMethod = Core.UITheme.SetCharacterHeader
Core.UITheme.SetCharacterHeader = nil
Equal(Hub.CoreIntegration:Initialize(), nil, "missing shared identity control explicitly stops initialization")
Core.UITheme.SetCharacterHeader = headerMethod
Core.Contracts:Unregister("OverviewFixture", provider); Hub.Contracts:Shutdown()
Equal(YiboTaskHubDB.tasks, nil, "folded groups never become persisted source tasks")
print("OverviewSpec: " .. checks .. " checks passed")
