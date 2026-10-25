local Addon = _G.YiboTaskHub
local Page = {}
Addon.TargetsPage = Page
local function Theme() return Addon.Core.UITheme end
local function Text(parent, text, x, y)
    local t = Theme():CreateText(parent, Theme().Font.assist, Theme().Colors.muted)
    t:SetPoint("TOPLEFT", x, y); t:SetText(text); return t
end
local function Button(parent, label, x, y, width, callback)
    local b = Theme():CreateButton(parent, width, label, "secondary")
    b:SetPoint("TOPLEFT", x, y); b:SetScript("OnClick", callback); return b
end
local function Select(parent, options, x, y, width, callback)
    local d = Theme():CreateDropdown(parent, width, options)
    d:SetPoint("TOPLEFT", x, y); d:SetMenuPageSize(8); d:SetOnValueChanged(callback); return d
end
local function Update(frame) Page.Refresh(frame, frame.context) end
local function Message(frame, ok, err)
    frame.message = ok and Addon:T("TEXT.SAVED.CDFAB9") or (err or Addon:T("TEXT.ACTION_COULD_NOT_BE_COMPLETED.223FB3"))
    Update(frame)
end
function Page.Create(frame)
    frame.left, frame.right = CreateFrame("Frame", nil, frame), CreateFrame("Frame", nil, frame)
    frame.leftRows, frame.rightRows = {}, {}
    frame.role = Select(frame, {}, 4, -4, 260, function(id)
        frame.characterID, frame.leftPage, frame.rightPage = id, 1, 1
        frame.mode, frame.draft, frame.pending, frame.message, frame.worldSelection = "catalog", nil, nil, nil, {}; Update(frame)
    end)
    frame.copyTo = Button(frame, Addon:T("TEXT.COPY_TO.C3D084"), 276, -4, 100, function()
        frame.mode, frame.selectedRoles, frame.rightPage, frame.pending = "copy-to", {}, 1, nil; Update(frame)
    end)
    frame.copyFrom = Button(frame, Addon:T("TEXT.COPY_FROM_OTHER_CHARACTERS.F99A92"), 384, -4, 142, function()
        frame.mode, frame.selectedRoles, frame.rightPage, frame.pending, frame.sourceID = "copy-from", {}, 1, nil, nil; Update(frame)
    end)
    frame.summary = Text(frame, "", 540, -12)
    frame.leftTitle = Text(frame.left, Addon:T("TEXT.BOSS_GOALS_FOR_THIS_CHARACTER.C2BFA0"), 0, -4)
    frame.add = Button(frame.left, Addon:T("TEXT.ADD_GOAL.544420"), 0, -28, 96, function()
        frame.mode, frame.draft, frame.rightPage, frame.message = "catalog", nil, 1, nil; Update(frame)
    end)
    frame.leftPrev = Button(frame.left, Addon:T("TEXT.PREVIOUS.B41561"), 0, 0, 62, function() frame.leftPage = frame.leftPage - 1; Update(frame) end)
    frame.leftNext = Button(frame.left, Addon:T("TEXT.NEXT.67A246"), 70, 0, 62, function() frame.leftPage = frame.leftPage + 1; Update(frame) end)
    frame.leftFooter = Text(frame.left, "", 146, 0)
    frame.rightTitle = Text(frame.right, "", 0, -4)
    frame.search = Theme():CreateInput(frame.right, { width = 260, clearable = true, placeholder = Addon:T("TEXT.SEARCH_CHINESE_ENGLISH_ABBREVIATION_.93555C"),
        OnChanged = function(value) frame.query, frame.rightPage = value, 1; Update(frame) end })
    frame.search:SetPoint("TOPLEFT", 0, -28)
    frame.filter = Select(frame.right, { { value = "all", label = Addon:T("TEXT.ALL_TYPES.FA6968") }, { value = "world", label = Addon:T("TEXT.WORLD_BOSS.DEBA90") },
        { value = "instance", label = Addon:T("TEXT.RAID.71D6EE") }, { value = "holiday", label = Addon:T("TEXT.HOLIDAY_BOSS.FBB24D") } }, 270, -28, 130,
        function(value) frame.filterValue, frame.rightPage = value, 1; Update(frame) end)
    frame.difficulty = Select(frame.right, {}, 0, -28, 230, function(value)
        frame.draft.difficultyID, frame.draft.encounterIDs, frame.rightPage, frame.message = value, {}, 1, nil; Update(frame)
    end)
    frame.scope = Select(frame.right, { { value = "all", label = Addon:T("TEXT.ALL_BOSSES_IN_RAID.11F973") }, { value = "boss", label = Addon:T("TEXT.SELECTED_BOSSES.3FE5FA") } }, 240, -28, 160,
        function(value) frame.draft.scope, frame.rightPage, frame.message = value, 1, nil; Update(frame) end)
    frame.rightPrev = Button(frame.right, Addon:T("TEXT.PREVIOUS.B41561"), 0, 0, 62, function() frame.rightPage = frame.rightPage - 1; Update(frame) end)
    frame.rightNext = Button(frame.right, Addon:T("TEXT.NEXT.67A246"), 70, 0, 62, function() frame.rightPage = frame.rightPage + 1; Update(frame) end)
    frame.rightFooter = Text(frame.right, "", 146, 0)
    frame.save = Button(frame.right, Addon:T("TEXT.SAVE_GOAL.9E77AC"), 0, 0, 112, function()
        local ok, err = Addon.BossTargets:Put(frame.characterID, frame.draft, frame.replacing)
        if ok then frame.mode, frame.draft, frame.replacing = "catalog", nil, nil end
        Message(frame, ok, err)
    end)
    frame.saveSelected = Button(frame.right, Addon:T("TEXT.ADD_SELECTED_BOSSES.3DE8AF"), 0, 0, 132, function()
        local targets = {}
        for id in pairs(frame.worldSelection or {}) do targets[#targets + 1] = { catalogID = id, scope = "all", active = true } end
        local ok, err = Addon.BossTargets:PutMany(frame.characterID, targets)
        if ok then frame.worldSelection = {} end
        Message(frame, ok, err)
    end)
    frame.cancel = Button(frame.right, Addon:T("TEXT.BACK_TO_CATALOG.36CBFA"), 120, 0, 100, function()
        frame.mode, frame.draft, frame.pending, frame.replacing, frame.message = "catalog", nil, nil, nil, nil; Update(frame)
    end)
    frame.preview = Button(frame.right, Addon:T("TEXT.PREVIEW_COPY.F55AE8"), 0, 0, 112, function()
        local destinations, source = {}, frame.characterID
        if frame.mode == "copy-from" then source = frame.sourceID; destinations[1] = frame.characterID
        else for id in pairs(frame.selectedRoles) do destinations[#destinations + 1] = id end end
        if not source or #destinations == 0 then Message(frame, nil, Addon:T("TEXT.SELECT_CHARACTERS_TO_COPY_TO.AB8AA1")); return end
        local pending, err = Addon.BossTargets:PreviewCopy(source, destinations)
        frame.pending = pending
        frame.message = pending and string.format(Addon:T("TEXT.ADD_D_MERGE_D_D_EXPAND_TO_FULL_RAID_.D7D44C"), pending.added, pending.merged, pending.expanded, pending.unchanged, pending.pausedDifferences) or err
        Update(frame)
    end)
    frame.apply = Button(frame.right, Addon:T("TEXT.CONFIRM_MERGE.46CDAB"), 120, 0, 100, function()
        local ok, err = Addon.BossTargets:ApplyCopy(frame.pending)
        frame.pending = nil; Message(frame, ok, err)
    end)
    frame.status = Text(frame, "", 4, 0)
    frame.status:ClearAllPoints(); frame.status:SetPoint("BOTTOMLEFT", 4, 4); frame.status:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.status:SetHeight(28); frame.status:SetWordWrap(true)
    frame:SetScript("OnSizeChanged", function() if frame.context and not frame.refreshing then Update(frame) end end)
end
local function Pager(prev, nextButton, footer, page, count, capacity, parent)
    local pages = math.max(1, math.ceil(count / capacity)); page = math.max(1, math.min(page or 1, pages))
    for _, button in ipairs({ prev, nextButton }) do button:ClearAllPoints() end
    prev:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 40); nextButton:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    footer:ClearAllPoints(); footer:SetPoint("LEFT", nextButton, "RIGHT", 10, 0)
    footer:SetText(string.format(Addon:T("TEXT.PAGE_D_D_D_ITEMS.58176A"), page, pages, count))
    prev:SetEnabled(page > 1); nextButton:SetEnabled(page < pages)
    prev:SetShown(pages > 1); nextButton:SetShown(pages > 1); footer:Show()
    return page, (page - 1) * capacity + 1
end
local function Row(parent, rows, index, width, step)
    step = step or 38
    local row = rows[index]
    if not row then
        row = CreateFrame("Frame", nil, parent); rows[index] = row
        row.label = Text(row, "", 4, -4); row.label:SetHeight(32); row.label:SetWordWrap(false)
        row.main = Button(row, "", 0, 0, 68, function() end)
        row.remove = Button(row, Addon:T("TEXT.REMOVE.2F752C"), 0, 0, 52, function() end)
        row.check = Theme():CreateCheckbox(row, ""); row.check:SetAllPoints()
    end
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -64 - (index - 1) * step); row:SetSize(width, step - 2)
    row.label:SetHeight(step - 8)
    row.main:SetHeight(step - 4); row.remove:SetHeight(step - 4)
    row.label:SetWidth(math.max(80, width - 136))
    row.main:ClearAllPoints(); row.main:SetPoint("TOPRIGHT", -58, 0)
    row.remove:ClearAllPoints(); row.remove:SetPoint("TOPRIGHT", 0, 0)
    row.check:Hide(); row.label:Show(); row.main:Show(); row.remove:Show(); row:Show()
    return row
end
function Page.Refresh(frame, context)
    if frame.refreshing or not context then return end
    frame.refreshing, frame.context = true, context
    local characters, options, allowed = context.characters or {}, {}, {}
    if Addon.Settings and Addon.db.settings.showOtherCharacters == false then characters = Addon.Settings:GetDisplayCharacters(characters) end
    for _, c in ipairs(characters) do options[#options + 1] = { value = c.id, label = Addon.AccountPage:CharacterLabel(c, context, true) .. " · " .. #Addon.BossTargets:List(c.id) .. Addon:T("TEXT.ITEMS.12DE8E") }; allowed[c.id] = true end
    if not allowed[frame.characterID] then
        local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
        frame.characterID = current and allowed[current.id] and current.id or (characters[1] and characters[1].id)
        frame.mode, frame.draft, frame.pending, frame.worldSelection = "catalog", nil, nil, {}
    end
    if frame.pending and (frame.pending.sourceEpoch ~= Addon.db.bossTargets.sourceEpoch or frame.pending.revision ~= Addon.db.goals.revision) then
        frame.pending, frame.message = nil, Addon:T("TEXT.GOAL_CHANGED_PREVIEW_THE_COPY_AGAIN.54D9B0")
    end
    frame.role:SetOptions(options); frame.role:SetValue(frame.characterID)
    frame.copyTo:SetEnabled(frame.characterID ~= nil); frame.copyFrom:SetEnabled(frame.characterID ~= nil)
    local width, height = math.max(620, frame:GetWidth() - 12), math.max(150, frame:GetHeight() - 80)
    local leftWidth = math.floor(width * 0.46); local rightWidth = width - leftWidth - 20
    frame.left:SetPoint("TOPLEFT", 4, -44); frame.left:SetSize(leftWidth, height)
    frame.right:SetPoint("TOPLEFT", leftWidth + 24, -44); frame.right:SetSize(rightWidth, height)
    local capacity = math.max(1, math.floor((height - 140) / 38))
    local entryStep = Theme().Size.standard + 2
    local entryCapacity = math.max(1, math.floor((height - 140) / entryStep))
    for _, list in ipairs({ frame.leftRows, frame.rightRows }) do for _, row in ipairs(list) do row:Hide() end end
    local goals = frame.characterID and Addon.BossTargets:List(frame.characterID) or {}
    frame.summary:SetText(#goals .. Addon:T("TEXT.GOALS_SHOWN_AUTOMATICALLY.A724B2") .. (Addon.db.settings.bossTargetsAutoDisplay and Addon:T("TEXT.ON.256783") or Addon:T("TEXT.OFF.6C14BD")))
    frame.summary:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    local first
    frame.leftPage, first = Pager(frame.leftPrev, frame.leftNext, frame.leftFooter, frame.leftPage, #goals, capacity, frame.left)
    for i = first, math.min(#goals, first + capacity - 1) do
        local goal = goals[i]; local row = Row(frame.left, frame.leftRows, i - first + 1, leftWidth)
        local detail = goal.difficultyName or (goal.kind == "holiday" and Addon:T("TEXT.HOLIDAY_DAILY.8B970D") or Addon:T("TEXT.WORLD_WEEKLY.4F7924"))
        detail = detail .. (goal.scope == "all" and Addon:T("TEXT.ALL.F5AE40") or (" · " .. #goal.encounterIDs .. Addon:T("TEXT.BOSSES.E76E60")))
        row.label:SetText(goal.title .. "\n" .. (goal.active and "" or Addon:T("TEXT.PAUSED.57C0BD")) .. detail)
        row.main:SetText(goal.active and Addon:T("TEXT.PAUSE.130448") or Addon:T("TEXT.ENABLE.D4E9CA"))
        row.main:SetScript("OnClick", function() Message(frame, Addon.BossTargets:Edit(frame.characterID, goal.id, not goal.active)) end)
        row.remove:SetScript("OnClick", function()
            local characterID, revision = frame.characterID, Addon.db.goals.revision
            Addon.Core.ItemConfirmation:Show({ text = Addon:T("TEXT.REMOVE_GOAL.209A78") .. goal.title .. Addon:T("TEXT.SOURCE_HISTORY_AND_BUSINESS_MONITORI.BA59C7"),
                IsCurrent = function() return Addon.db.goals.revision == revision end,
                OnAccept = function() Message(frame, Addon.BossTargets:Edit(characterID, goal.id, nil, true)) end })
        end)
        -- The label is an edit affordance with the complete goal in its tooltip.
        row:SetScript("OnMouseUp", function()
            frame.draft, frame.replacing, frame.mode, frame.rightPage = Addon.BossTargets:Validate(goal) or goal, goal.id, "editor", 1; Update(frame)
        end)
        row:EnableMouse(true)
        Theme():BindTooltip(row, goal.title, { detail, Addon:T("TEXT.CLICK_A_NAME_TO_EDIT_THE_BOSS_SET_PA.A3E60E") })
    end
    frame.add:SetEnabled(frame.characterID ~= nil)
    -- A search refresh must not hide the focused edit box: Core correctly
    -- clears focus and pending IME composition when an input really closes.
    frame.search:SetShown((frame.mode or "catalog") == "catalog")
    for _, control in ipairs({ frame.filter, frame.difficulty, frame.scope, frame.save, frame.saveSelected, frame.cancel, frame.preview, frame.apply }) do control:Hide() end
    local catalog, catalogErr = Addon.BossTargets:Catalog()
    local mode, entries = frame.mode or "catalog", {}
    if mode == "catalog" then
        frame.rightTitle:SetText(Addon:T("TEXT.ADD_BOSS_GOALS.2B65F3")); frame.search:Show(); frame.filter:Show()
        frame.search:SetWidth(math.max(100, rightWidth - 140)); frame.filter:ClearAllPoints(); frame.filter:SetPoint("TOPRIGHT", 0, -28)
        frame.filter:SetValue(frame.filterValue or "all")
        for _, entry in ipairs(catalog and catalog.targets or {}) do if (not frame.filterValue or frame.filterValue == "all" or entry.kind == frame.filterValue) and Addon.BossTargets:Matches(entry, frame.query) then entries[#entries + 1] = entry end end
        local selectedCount = 0; for _ in pairs(frame.worldSelection or {}) do selectedCount = selectedCount + 1 end
        frame.saveSelected:SetShown(selectedCount > 0); frame.saveSelected:SetText(Addon:T("TEXT.ADD.B661A4") .. selectedCount .. Addon:T("TEXT.BOSSES.478A5F"))
    elseif mode == "editor" then
        local definition
        for _, entry in ipairs(catalog and catalog.targets or {}) do if entry.id == frame.draft.catalogID then definition = entry end end
        frame.rightTitle:SetText(definition and definition.name or frame.draft.title or Addon:T("TEXT.GOAL_CATALOG_TEMPORARILY_UNAVAILABLE.B2AFCD"))
        frame.cancel:Show(); frame.save:Show(); frame.save:SetEnabled(definition ~= nil)
        if definition and definition.kind == "instance" then
            local difficulties, selected = {}, nil
            for _, d in ipairs(definition.difficulties or {}) do if d.complete and d.trackable ~= false then
                difficulties[#difficulties + 1] = { value = d.id, label = d.name }
                if d.id == frame.draft.difficultyID then selected = d end
            end end
            frame.difficulty:SetOptions(difficulties); frame.difficulty:SetValue(frame.draft.difficultyID); frame.difficulty:Show()
            frame.difficulty:SetWidth(math.max(110, rightWidth - 170)); frame.scope:ClearAllPoints(); frame.scope:SetPoint("TOPRIGHT", 0, -28)
            local scopes = { { value = "all", label = Addon:T("TEXT.ALL_BOSSES_IN_RAID.11F973") } }
            if selected and not selected.finalEncounterID and frame.draft.scope == "final" then frame.draft.scope = "boss" end
            if selected and selected.finalEncounterID then
                for _, boss in ipairs(selected.encounters or {}) do if boss.id == selected.finalEncounterID then
                    scopes[#scopes + 1] = { value = "final", label = Addon:T("GOAL.FINAL_BOSS_NAME", boss.name) }
                end end
            end
            scopes[#scopes + 1] = { value = "boss", label = Addon:T("TEXT.SELECTED_BOSSES.3FE5FA") }
            frame.scope:SetOptions(scopes); frame.scope:SetValue(frame.draft.scope); frame.scope:Show()
            frame.save:SetEnabled(selected ~= nil)
            if selected and frame.draft.scope == "boss" then entries = selected.encounters or {} end
            if selected and frame.draft.scope == "boss" and #(frame.draft.encounterIDs or {}) == 0 then frame.save:SetEnabled(false) end
            if not selected then frame.message = Addon:T("GOAL.SELECT_DIFFICULTY") end
        end
    else
        frame.rightTitle:SetText(mode == "copy-to" and Addon:T("TEXT.COPY_CURRENT_GOALS_TO_MULTIPLE_CHARA.FB4CEC") or Addon:T("TEXT.MERGE_GOALS_FROM_OTHER_CHARACTERS_IN.2D5439"))
        frame.cancel:Show(); frame.preview:Show(); frame.apply:SetShown(frame.pending ~= nil)
        for _, c in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do if c.id ~= frame.characterID then entries[#entries + 1] = c end end
    end
    frame.rightPage, first = Pager(frame.rightPrev, frame.rightNext, frame.rightFooter, frame.rightPage, #entries, entryCapacity, frame.right)
    for i = first, math.min(#entries, first + entryCapacity - 1) do
        local entry, row = entries[i], Row(frame.right, frame.rightRows, i - first + 1, rightWidth, entryStep)
        row.remove:Hide(); row.main:ClearAllPoints(); row.main:SetPoint("TOPRIGHT", 0, 0)
        row.label:SetWidth(math.max(80, rightWidth - 80))
        if mode == "catalog" then
            local matched = Addon.BossTargets:EncounterMatch(entry, frame.query)
            row.label:SetText(entry.name .. (matched and (" · " .. matched) or "") .. (entry.kind == "instance" and (entry.complete and "" or Addon:T("TEXT.CATALOG_NEEDS_VERIFICATION.4B0143")) or ""))
            row.main:SetText(Addon:T("TEXT.SELECT.70B208")); row.main:SetEnabled(entry.available ~= false and (entry.kind ~= "instance" or entry.complete))
            row.main:SetScript("OnClick", function()
                frame.mode, frame.replacing, frame.rightPage, frame.message = "editor", nil, 1, nil
                frame.draft = { catalogID = entry.id, scope = "all", encounterIDs = {}, active = true }
                local choices = {}
                for _, d in ipairs(entry.difficulties or {}) do if d.complete and d.trackable ~= false then choices[#choices + 1] = d end end
                if #choices == 1 then frame.draft.difficultyID = choices[1].id end
                Update(frame)
            end)
            Theme():BindTooltip(row.main, entry.name, { matched and (Addon:T("TEXT.MATCHING_BOSS.CDEEC0") .. matched) or (entry.reason or Addon:T("TEXT.CHOOSE_A_DIFFICULTY_AND_THE_BOSSES_T.04E8EE")), table.concat(entry.aliases or {}, " / ") })
            if entry.kind ~= "instance" then
                row.label:Hide(); row.main:Hide(); row.check:Show(); row.check:SetWidth(rightWidth)
                row.check.label:SetText(entry.name); row.check.label:SetWidth(math.max(80, rightWidth - 28))
                row.check:SetChecked(frame.worldSelection and frame.worldSelection[entry.id] == true)
                row.check:SetScript("OnClick", function()
                    frame.worldSelection = frame.worldSelection or {}
                    frame.worldSelection[entry.id] = not frame.worldSelection[entry.id] or nil; Update(frame)
                end)
            end
        else
            row.label:Hide(); row.main:Hide(); row.check:Show()
            row.check.label:SetText(mode == "editor" and entry.name or Addon.AccountPage:CharacterLabel(entry, context, true))
            local change = frame.pending and frame.pending.changes[mode == "copy-from" and frame.characterID or entry.id]
            if change and (mode ~= "copy-from" or frame.sourceID == entry.id) then
                row.check.label:SetText(row.check.label:GetText() .. string.format(Addon:T("TEXT.ADD_D_MERGE_D_FULL_RAID_D.DBC8D4"), change.added, change.merged, change.expanded))
            end
            row.check:SetWidth(rightWidth); row.check.label:SetWidth(math.max(80, rightWidth - 28))
            Theme():BindTooltip(row.check, mode == "editor" and entry.name or Addon.AccountPage:CharacterLabel(entry, context, true),
                { row.check.label:GetText() })
            local chosen = false
            if mode == "editor" then for _, id in ipairs(frame.draft.encounterIDs or {}) do if id == entry.id then chosen = true end end
            else chosen = mode == "copy-from" and frame.sourceID == entry.id or (mode == "copy-to" and frame.selectedRoles[entry.id]) end
            row.check:SetChecked(chosen)
            row.check:SetScript("OnClick", function()
                if mode == "editor" then
                    local selected = {}; for _, id in ipairs(frame.draft.encounterIDs or {}) do if id ~= entry.id then selected[#selected + 1] = id end end
                    if not chosen then selected[#selected + 1] = entry.id end; frame.draft.encounterIDs = selected
                elseif mode == "copy-from" then frame.sourceID = entry.id
                else frame.selectedRoles[entry.id] = not chosen or nil end
                frame.pending, frame.message = nil, nil; Update(frame)
            end)
        end
    end
    for _, control in ipairs({ frame.save, frame.saveSelected, frame.preview, frame.cancel, frame.apply }) do
        control:ClearAllPoints(); control:SetPoint("BOTTOMLEFT", frame.right, "BOTTOMLEFT", control == frame.cancel and 240 or (control == frame.apply and 120 or 0), 4)
    end
    local note = mode == "editor" and (frame.draft.scope == "final" and Addon:T("GOAL.FINAL_HINT") or (#entries == 0 and Addon:T("TEXT.FULL_RAID_GOALS_FOLLOW_THE_COMPLETE_.162EAD") or Addon:T("TEXT.SELECT_THE_BOSSES_TO_FARM_YOUR_SELEC.15FA88")))
        or ((mode == "copy-to" or mode == "copy-from") and Addon:T("TEXT.MERGING_PRESERVES_EXISTING_GOALS_AND.B193E2") or Addon:T("TEXT.CLICK_A_GOAL_NAME_ON_THE_LEFT_TO_EDI.256FB7"))
    frame.status:SetText(frame.message or catalogErr or note)
    frame.refreshing = false
end
