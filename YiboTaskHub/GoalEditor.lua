local Addon = _G.YiboTaskHub
local Editor = { page = 1 }
Addon.GoalEditor = Editor
local function Theme() return Addon.Core.UITheme end
local function Refresh() Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID) end
local function Text(parent, text, x, y)
    local t = Theme():CreateText(parent, Theme().Font.assist, Theme().Colors.text)
    t:SetPoint("TOPLEFT", x, y); t:SetText(text); return t
end
local function Button(parent, text, width, x, y, callback)
    local b = Theme():CreateButton(parent, width, text)
    b:SetPoint("TOPLEFT", x, y); b:SetScript("OnClick", callback); return b
end
function Editor:Locate(id)
    self.selectedID, self.draft, self.message, self.copyID, self.adding, self.roleID = id, nil, nil, nil, nil, nil
    local list = Addon.Goals:List()
    for i, goal in ipairs(list) do if goal.id == id then self.page = math.ceil(i / (self.capacity or 6)) end end
    local goal, current = Addon.db.goals.byID[id], Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if goal and Addon.db.settings.showOtherCharacters == false and goal.intent.scope.mode == "character"
        and (not current or goal.intent.scope.characterID ~= current.id) then
        self.message = Addon:T("TEXT.THIS_GOAL_BELONGS_TO_ANOTHER_CHARACT.CFADB6")
    end
    Addon.AccountPage.activeTab = "goals"
    Addon.Core.AccountView:ShowPage(Addon.PAGE_ID)
    Refresh(); return true
end
function Editor:Configure(intent, id)
    self.copyID, self.adding = nil, nil
    self.draft, self.editingID = Addon.Core.Defaults:Copy(intent), id
    self.editRevision = id and Addon.db.goals.byID[id].revision
    self.selectedID, self.message, self.lastFields = id, nil, nil
    Addon.AccountPage.activeTab = "goals"
    Addon.Core.AccountView:ShowPage(Addon.PAGE_ID)
    Refresh(); return true
end
function Editor:Entries()
    local entries = {}
    for _, ref in ipairs(Addon.Core.Contracts:List("action.targets", { major = 1, minMinor = 1 })) do
        local entry = Addon.Core.Contracts:Call(Addon.NAME, ref, "GetEntry", {})
        if type(entry) == "table" and type(entry.title) == "string" and type(entry.pageID) == "string" then
            entries[#entries + 1] = { title = entry.title, pageID = entry.pageID, providerID = ref.providerID }
        end
    end
    return entries
end
function Editor.Create(frame)
    frame.title = Text(frame, Addon:T("TEXT.GOAL_MANAGEMENT.D90E7E"), 8, -8)
    frame.hint = Text(frame, Addon:T("TEXT.ADD_GOALS_FROM_SPECIFIC_ITEMS_ON_BUS.D18B56"), 8, -36)
    frame.rows, frame.fields = {}, {}
    frame.previous = Button(frame, Addon:T("TEXT.PREVIOUS.B41561"), 70, 8, -330, function() Editor.page = math.max(1, Editor.page - 1); Refresh() end)
    frame.next = Button(frame, Addon:T("TEXT.NEXT.67A246"), 70, 86, -330, function() Editor.page = Editor.page + 1; Refresh() end)
    frame.footer = Text(frame, "", 170, -336)
    frame.add = Button(frame, Addon:T("TEXT.ADD_GOAL.544420"), 100, 0, 0, function() Editor.adding, Editor.message = true, nil; Refresh() end)
    frame.add:ClearAllPoints(); frame.add:SetPoint("TOPRIGHT", -8, -4)
    frame.boss = Button(frame, Addon:T("BOSS_GOALS_COPY"), 170, 0, 0, function()
        Addon.AccountPage.activeTab = "targets"; Refresh()
    end)
    frame.boss:ClearAllPoints(); frame.boss:SetPoint("RIGHT", frame.add, "LEFT", -8, 0)
    frame.role = Theme():CreateDropdown(frame, 300, {})
    frame.role:SetMenuPageSize(8)
    frame.role:SetPoint("TOPLEFT", 8, -38)
    frame.role:SetOnValueChanged(function(id) Editor.roleID, Editor.page = id ~= "all" and id or nil, 1; Refresh() end)
    frame:SetScript("OnSizeChanged", function() if frame.context then Editor.Refresh(frame, frame.context) end end)
end
function Editor.Refresh(frame, context)
    frame.context = context or frame.context
    Editor.requiredHeight = nil
    for _, row in ipairs(frame.rows) do row:Hide() end
    for _, field in ipairs(frame.fields) do field:Hide() end
    frame.previous:SetShown(not Editor.draft); frame.next:SetShown(not Editor.draft)
    local listMode = not Editor.draft and not Editor.copyID and not Editor.adding
    frame.add:SetShown(listMode); frame.boss:SetShown(listMode); frame.role:SetShown(listMode)
    frame.hint:ClearAllPoints(); frame.hint:SetPoint("TOPLEFT", 8, listMode and -80 or -38)
    frame.hint:SetWidth(math.max(300, frame:GetWidth() - 16))
    if frame.addControls then frame.addControls:Hide() end
    if Editor.adding then
        if frame.actions then frame.actions:Hide() end
        if frame.copyControls then frame.copyControls:Hide() end
        frame.previous:Hide(); frame.next:Hide(); frame.footer:SetText("")
        frame.title:SetText(Addon:T("TEXT.ADD_GOAL.544420"))
        frame.hint:SetText(Addon:T("TEXT.CHOOSE_A_SOURCE_THEN_SELECT_AN_ITEM_.0BF200"))
        local controls = frame.addControls or CreateFrame("Frame", nil, frame); frame.addControls = controls
        controls:SetAllPoints(frame); controls:Show(); controls.buttons = controls.buttons or {}
        for _, b in ipairs(controls.buttons) do b:Hide() end
        local entries = Editor:Entries()
        for i, entry in ipairs(entries) do
            local b = controls.buttons[i] or Button(controls, "", 300, 0, 0, function() end); controls.buttons[i] = b
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8 + ((i - 1) % 2) * 320, -78 - math.floor((i - 1) / 2) * 44)
            b:SetText(entry.title); b:SetScript("OnClick", function() Editor.adding = nil; Addon.Core.AccountView:ShowPage(entry.pageID) end); b:Show()
        end
        controls.back = controls.back or Button(controls, Addon:T("TEXT.BACK_TO_GOAL_MANAGEMENT.D16267"), 130, 0, 0, function() Editor.adding = nil; Refresh() end)
        controls.back:ClearAllPoints(); controls.back:SetPoint("BOTTOMLEFT", 8, 8)
        if #entries == 0 then frame.hint:SetText(Addon:T("TEXT.NO_SOURCE_SUPPORTS_ADDING_GOALS_ENAB.05A6A5")) end
        return
    end
    if Editor.copyID then
        if frame.actions then frame.actions:Hide() end
        frame.previous:Hide(); frame.next:Hide(); frame.title:SetText(Addon:T("TEXT.COPY_GOALS.3F4170"))
        frame.hint:SetText(Editor.message or Addon:T("TEXT.CHOOSE_DESTINATION_CHARACTERS_COPIES.67D7BE"))
        frame.copyControls = frame.copyControls or CreateFrame("Frame", nil, frame)
        local controls = frame.copyControls; controls:SetAllPoints(frame); controls:Show()
        controls.label = controls.label or Text(controls, Addon:T("TEXT.DESTINATION_CHARACTER.86A095"), 8, -72)
        controls.select = controls.select or Theme():CreateDropdown(controls, 360, {})
        controls.select:SetMenuPageSize(8)
        controls.select:SetPoint("TOPLEFT", 8, -100)
        local options = {}
        for _, character in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do
            options[#options + 1] = { value = character.id, label = Addon.Core.Characters:FormatName(character, { realmMode = "full" }) }
        end
        controls.select:SetOptions(options); controls.select:SetValue(Editor.destination)
        controls.select:SetOnValueChanged(function(id) Editor.destination = id end)
        controls.preview = controls.preview or Button(controls, Addon:T("TEXT.PREVIEW_COPY.F55AE8"), 110, 8, -160, function()
            if not Editor.destination then Editor.message = Addon:T("TEXT.CHOOSE_A_DESTINATION_CHARACTER.457439"); Refresh(); return end
            local preview, err = Addon.Goals:PreviewCopy({ Editor.copyID }, { Editor.destination })
            if not preview then Editor.message = err; Refresh(); return end
            Addon.Core.ItemConfirmation:Show({ text = Addon:T("TEXT.WILL_ADD.62B7D6") .. preview.added .. Addon:T("TEXT.GOALS_KEEP.2E3E2D") .. preview.existing .. Addon:T("TEXT.EXISTING_GOALS_COPY_THESE_CHANGES.6A9F7B"),
                IsCurrent = function() return Addon.db.goals.revision == preview.revision end,
                OnAccept = function()
                    local ok, message = Addon.Goals:ApplyCopy(preview.token)
                    Editor.message = ok and Addon:T("TEXT.COPY_COMPLETE.F5F6A2") or message; if ok then Editor.copyID = nil end; Refresh()
                end })
        end)
        controls.cancel = controls.cancel or Button(controls, Addon:T("TEXT.CANCEL.4D0B46"), 80, 128, -160, function() Editor.copyID, Editor.message = nil, nil; Refresh() end)
        frame.footer:SetText(""); return
    end
    if frame.copyControls then frame.copyControls:Hide() end
    if Editor.draft then
        local draft = Editor.draft
        draft.scope = draft.scope or { mode = "character" }; draft.conditions = draft.conditions or {}
        frame.title:SetText(Addon:T("TEXT.CONFIGURE_GOAL.7C0C68"))
        local normalized, err = Addon.Goals:Normalize(draft)
        local fields = normalized and normalized.fields or Editor.lastFields or {}
        if normalized and normalized.fields then Editor.lastFields = normalized.fields end
        if (normalized and normalized.needsCharacter) or
            (draft.scope.mode == "character" and not (normalized and normalized.managesExecutionScope)) then
            local options = normalized and normalized.characterOptions or {}
            if not (normalized and normalized.characterOptions) then
                for _, c in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do
                    options[#options + 1] = { value = c.id, label = Addon.Core.Characters:FormatName(c, { realmMode = "full" }) }
                end
            end
            local all = { { id = "characterID", label = Addon:T("TEXT.ACTING_CHARACTER.456AFC"), kind = "select", options = options, scope = true } }
            for _, f in ipairs(fields) do all[#all + 1] = f end; fields = all
        end
        -- Normalize returns only required/mutable business parameters. The
        -- source owns their interpretation and validates them again on save.
        for i, definition in ipairs(fields) do
            local field = frame.fields[i] or CreateFrame("Frame", nil, frame); frame.fields[i] = field
            field:ClearAllPoints()
            field:SetPoint("TOPLEFT", 8 + ((i - 1) % 2) * 400, -72 - math.floor((i - 1) / 2) * 60); field:SetSize(380, 54)
            field.label = field.label or Text(field, "", 0, 0); field.label:SetText(definition.label)
            if field.select then field.select:Hide() end
            if field.input then field.input:Hide() end
            local container = definition.scope and draft.scope or draft.conditions
            local key = definition.id
            if container[key] == nil and definition.default ~= nil then container[key] = definition.default end
            field.SetValue = function(v) container[key] = definition.kind == "number" and tonumber(v) or v end
            if definition.kind == "select" then
                local d = field.select or Theme():CreateDropdown(field, 360, {})
                field.select = d
                d:SetMenuPageSize(8)
                d:SetPoint("TOPLEFT", 0, -22); d:SetOptions(definition.options or {}); d:SetValue(container[key])
                d:SetOnValueChanged(function(v) field.SetValue(v); Refresh() end); d:Show()
            else
                local input = field.input or Theme():CreateInput(field, { width = 360, OnChanged = function(v) if not field.silent then field.SetValue(v) end end })
                field.input = input
                input:SetPoint("TOPLEFT", 0, -22); field.silent = true; input:SetText(tostring(container[key] or "")); field.silent = false; input:Show()
            end
            field:Show()
        end
        local row = frame.actions or CreateFrame("Frame", nil, frame); frame.actions = row
        Editor.requiredHeight = 82 + math.ceil(#fields / 2) * 60 + 80 + 38
        row:Show()
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 8, -82 - math.ceil(#fields / 2) * 60); row:SetSize(800, 60)
        row.save = row.save or Button(row, Addon:T("TEXT.SAVE_GOAL.9E77AC"), 110, 0, 0, function() end)
        row.save:SetScript("OnClick", function()
            local result, message
            if Editor.editingID then result, message = Addon.Goals:Update(Editor.editingID, Editor.editRevision, { intent = draft })
            else result, message = Addon.Goals:Add(draft) end
            if result and not result.needsConfiguration then Editor.draft, Editor.editingID = nil, nil; Editor.selectedID = result.id; Editor.message = Addon:T("TEXT.SAVED.CDFAB9")
            else Editor.message = message or Addon:T("TEXT.FILL_IN_THE_REQUIRED_OPTIONS.A7C138") end
            Refresh()
        end)
        row.cancel = row.cancel or Button(row, Addon:T("TEXT.CANCEL.4D0B46"), 80, 120, 0, function() Editor.draft, Editor.editingID = nil, nil; Refresh() end)
        frame.hint:SetText(Editor.message or err or (normalized and normalized.title) or Addon:T("TEXT.CHOOSE_GOAL_OPTIONS.B73249"))
        frame.footer:SetText(""); return
    end
    if frame.actions then frame.actions:Hide() end
    frame.title:SetText(Addon:T("TEXT.GOAL_MANAGEMENT.D90E7E"))
    local characters = Addon.Core.Characters:GetAll({ identityOnly = true })
    if Addon.Settings then characters = Addon.Settings:GetDisplayCharacters(characters) end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if Addon.db.settings.showOtherCharacters == false then Editor.roleID = nil end
    local roles = { { value = "all", label = Addon:T("TEXT.GOALS_FOR_ALL_CHARACTERS_AND_THE_ACC.F39936") } }
    for _, c in ipairs(characters) do roles[#roles + 1] = { value = c.id, label = Addon.Core.Characters:FormatName(c, { realmMode = "full" }) } end
    frame.role:SetOptions(roles); frame.role:SetValue(Editor.roleID or "all")
    local list, statuses = {}, {}
    for _, goal in ipairs(Addon.Goals:List()) do
        local scope = goal.intent.scope
        local visible = Addon.db.settings.showOtherCharacters ~= false or scope.mode == "account" or (current and scope.characterID == current.id)
        if visible and (not Editor.roleID or scope.characterID == Editor.roleID) then list[#list + 1] = goal end
    end
    for _, source in ipairs(Addon.Contracts:GetGoalResults(characters)) do
        for _, task in ipairs(source.result.data.tasks) do statuses[task.goalID] = task end
    end
    local capacity = math.max(1, math.floor((frame:GetHeight() - 154) / 56)); Editor.capacity = capacity
    local pages = math.max(1, math.ceil(#list / capacity)); Editor.page = math.min(pages, math.max(1, Editor.page))
    frame.hint:SetText(Editor.message or (#list == 0 and Addon:T("TEXT.NO_GOALS_IN_THIS_SCOPE_CLICK_ADD_GOA.0C159F") .. Addon.Core.BusinessItemActions:GestureLabel() .. Addon:T("TEXT..F92669") or Addon:T("TEXT.THE_OVERVIEW_SHOWS_TASKS_COMPLETED_A.584C7A")))
    for i = 1, capacity do
        local goal = list[(Editor.page - 1) * capacity + i]
        if goal then
            local row = frame.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, frame); frame.rows[i] = row
                row.title = Text(row, "", 0, -2)
                row.detail = Text(row, "", 0, -26)
                row.copy = Button(row, Addon:T("TEXT.COPY.4EDD1D"), 60, 420, 0, function() Editor.copyID, Editor.destination, Editor.message = row.goal.id, nil, nil; Refresh() end)
                row.edit = Button(row, Addon:T("TEXT.EDIT.A7F814"), 64, 490, 0, function() Editor:Configure(row.goal.intent, row.goal.id) end)
                row.pause = Button(row, Addon:T("TEXT.PAUSE.130448"), 76, 562, 0, function()
                    local g = row.goal
                    local result, message = Addon.Goals:Update(g.id, g.revision, { state = g.state == "active" and "paused" or "active", reopen = g.state == "completed" })
                    Editor.message = result and Addon:T("TEXT.SAVED.CDFAB9") or message; Refresh()
                end)
                row.remove = Button(row, Addon:T("TEXT.REMOVE.2F752C"), 64, 646, 0, function()
                    local g = row.goal
                    Addon.Core.ItemConfirmation:Show({ text = Addon:T("TEXT.REMOVE_GOAL.209A78") .. g.title .. Addon:T("TEXT.SOURCE_HISTORY_AND_BUSINESS_MONITORI.BA59C7"),
                        IsCurrent = function() local current = Addon.db.goals.byID[g.id]; return current and current.revision == g.revision end,
                        OnAccept = function()
                            local result, message = Addon.Goals:Update(g.id, g.revision, { state = "removed" })
                            Editor.message = result and Addon:T("TEXT.REMOVED.4E5C49") or message; Refresh()
                        end })
                end)
            end
            local width = math.max(740, frame:GetWidth() - 16)
            row:SetSize(width, 52); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 8, -108 - (i - 1) * 56)
            row.title:SetWidth(width - 310); row.title:SetWordWrap(false)
            row.detail:SetWidth(width - 310); row.detail:SetWordWrap(false)
            for index, button in ipairs({ row.remove, row.pause, row.edit, row.copy }) do
                button:ClearAllPoints(); button:SetPoint("TOPRIGHT", -(index - 1) * 80, -8)
            end
            row.goal = goal
            row.copy:SetEnabled(goal.intent.scope.mode == "character")
            local task = statuses[goal.id]
            local saved = Addon.db.goals.byID[goal.id] or goal
            local state = ({ active = Addon:T("TEXT.ACTIVE.6F1972"), paused = Addon:T("TEXT.PAUSED.FCBAE4"), completed = Addon:T("TEXT.COMPLETE.E99B48") })[saved.state] or saved.state
            if saved.state == "active" and task then
                state = task.state == "completed" and (goal.intent.repeatPolicy == "recurring" and Addon:T("TEXT.COMPLETED_THIS_CYCLE.A1A9A4") or Addon:T("TEXT.GOAL_REACHED.573A35"))
                    or (task.reason or (task.readiness == "unknown" and Addon:T("TEXT.UNVERIFIED.8708E4") or Addon:T("TEXT.ACTIVE.6F1972")))
            end
            local character = goal.intent.scope and goal.intent.scope.characterID and Addon.Core.Characters:Get(goal.intent.scope.characterID, { identityOnly = true })
            local name = character and Addon.Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("TEXT.ACCOUNT.901384")
            row.goal = saved
            row.title:SetText((Editor.selectedID == goal.id and "› " or "") .. (task and task.title or goal.title))
            local detail = name .. " · " .. state .. Addon:T("TEXT.HISTORY.75717E") .. #saved.history
            row.detail:SetText(detail)
            row:EnableMouse(true); Theme():BindTooltip(row, task and task.title or goal.title, { { kind = "text", text = detail }, { kind = "text", text = task and task.summary or Addon:T("TEXT.GOAL_SETTINGS_AND_COMPLETION_HISTORY.958089") } })
            row.pause:SetText(saved.state == "active" and Addon:T("TEXT.PAUSE.130448") or (saved.state == "completed" and Addon:T("TEXT.RUN_AGAIN.AC1BA6") or Addon:T("TEXT.RESUME.79748C"))); row:Show()
        end
    end
    frame.footer:SetText(Editor.page .. " / " .. pages .. Addon:T("TEXT.PAGES.9714DF") .. #list .. Addon:T("TEXT.GOALS.58DECC"))
    frame.previous:ClearAllPoints(); frame.previous:SetPoint("BOTTOMLEFT", 8, 8); frame.previous:SetEnabled(Editor.page > 1)
    frame.next:ClearAllPoints(); frame.next:SetPoint("LEFT", frame.previous, "RIGHT", 8, 0); frame.next:SetEnabled(Editor.page < pages)
    frame.footer:ClearAllPoints(); frame.footer:SetPoint("LEFT", frame.next, "RIGHT", 14, 0)
end
