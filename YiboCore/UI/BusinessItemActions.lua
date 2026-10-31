local Core = _G.YiboCore
local Actions = { bindings = setmetatable({}, { __mode = "k" }), hoverBindingCount = 0 }
Core.BusinessItemActions = Actions
local function StableValue(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = StableValue(key) .. "=" .. StableValue(value[key]) end
    return "{" .. table.concat(parts, ";") .. "}"
end
local function IntentKey(intent)
    if type(intent) ~= "table" or type(intent.scope) ~= "table" then return nil end
    return StableValue({ providerID = intent.providerID, targetType = intent.targetType, objectID = intent.objectID,
        scope = intent.scope, conditions = intent.conditions, repeatPolicy = intent.repeatPolicy })
end
local buttons = Core.Locale:Bind(function() return { LeftButton = Core:Text("CORE.LEFT_CLICK"), RightButton = Core:Text("CORE.RIGHT_CLICK"), MiddleButton = Core:Text("CORE.MIDDLE_CLICK"), Button4 = Core:Text("CORE.MOUSE_4"), Button5 = Core:Text("CORE.MOUSE_5") } end)
local function SetMenuAdded(binding, added)
    if not binding.menu then return end
    binding.menu:SetText(added and "" or "+")
    binding.menu.addedCheck:SetShown(added == true)
end
local function Settings()
    local db = Core.Database:GetDB()
    db.settings.businessItemGesture = db.settings.businessItemGesture or { button = "MiddleButton", alt = false, ctrl = false, shift = false }
    return db.settings.businessItemGesture
end
function Actions:GetGesture()
    local mode = self:GetOptions().mode
    if mode == "middle" then return { button = "MiddleButton", ctrl = false, alt = false, shift = false } end
    if mode == "ctrlLeft" then return { button = "LeftButton", ctrl = true, alt = false, shift = false } end
    return Core.Defaults:Copy(Settings())
end
function Actions:GetOptions()
    local db, g = Core.Database:GetDB(), Settings()
    if not db.settings.businessItemActions then
        local mode = g.button == "MiddleButton" and not g.ctrl and not g.alt and not g.shift and "middle" or "custom"
        if g.button == "LeftButton" and g.ctrl and not g.alt and not g.shift then mode = "ctrlLeft" end
        db.settings.businessItemActions = { mode = mode, markerStyle = "corner" }
    end
    return Core.Defaults:Copy(db.settings.businessItemActions)
end
function Actions:SetOptions(options)
    if Core.Client:IsInCombat() then return nil, Core:Text("CORE.LEAVE_COMBAT_BEFORE_CHANGING_HOW_TARGETS_ARE") end
    local clean = self:GetOptions()
    if options.mode then
        if not ({ menu = true, middle = true, ctrlLeft = true, custom = true })[options.mode] then return nil, "invalid-mode" end
        clean.mode = options.mode
    end
    if options.markerStyle then
        if not ({ corner = true, dot = true })[options.markerStyle] then return nil, "invalid-style" end
        clean.markerStyle = options.markerStyle
    end
    for _, binding in pairs(self.bindings) do
        if binding.ConfigureCtrlLeft then binding.ctrlLeftSafe = binding.ConfigureCtrlLeft(clean.mode == "ctrlLeft") == true end
    end
    Core.Database:GetDB().settings.businessItemActions = clean
    for control, binding in pairs(self.bindings) do
        binding.needsConfiguration = nil
        if binding.menu then binding.menu:Hide() end
        self:SetMarker(control, binding.itemStatus)
    end
    Core.Events:FireIsolated("BUSINESS_ITEM_GESTURE_CHANGED", self:GetGesture())
    return true
end
function Actions:GestureLabel()
    local mode = self:GetOptions().mode
    if mode == "menu" then return Core:Text("CORE.TOP_RIGHT_BUTTON") end
    if mode == "middle" then return Core:Text("CORE.MIDDLE_CLICK") end
    if mode == "ctrlLeft" then return Core:Text("CORE.CTRL_CLICK") end
    local g, parts = Settings(), {}
    if g.ctrl then parts[#parts + 1] = "Ctrl" end
    if g.alt then parts[#parts + 1] = "Alt" end
    if g.shift then parts[#parts + 1] = "Shift" end
    parts[#parts + 1] = buttons[g.button]
    return table.concat(parts, "+")
end
local function Conflicts(binding, g)
    if g.button == "LeftButton" and g.ctrl and not g.alt and not g.shift and binding.ctrlLeftSafe then return false end
    -- A protected action can use wildcard modifiers. Reserve its entire
    -- physical button, so an insecure callback can never also cast/use it.
    return binding.reservedButtons and binding.reservedButtons[g.button] == true
end
function Actions:SetGesture(g)
    if Core.Client:IsInCombat() then return nil, Core:Text("CORE.LEAVE_COMBAT_BEFORE_CHANGING_HOW_TARGETS_ARE") end
    if type(g) ~= "table" or not buttons[g.button] then return nil, Core:Text("CORE.CHOOSE_A_VALID_MOUSE_BUTTON") end
    local clean = { button = g.button, alt = g.alt == true, ctrl = g.ctrl == true, shift = g.shift == true }
    for _, binding in pairs(self.bindings) do
        if Conflicts(binding, clean) then return nil, Core:Text("CORE.THIS_BINDING_CONFLICTS_WITH_A_BUSINESS_ACTION") end
    end
    Core.Database:GetDB().settings.businessItemGesture = clean
    local mode = clean.button == "MiddleButton" and not clean.ctrl and not clean.alt and not clean.shift and "middle" or "custom"
    self:SetOptions({ mode = mode })
    Core.Events:FireIsolated("BUSINESS_ITEM_GESTURE_CHANGED", clean)
    return true
end
function Actions:Matches(button)
    local mode = self:GetOptions().mode
    if mode == "menu" then return false end
    local g = mode == "middle" and { button = "MiddleButton", alt = false, ctrl = false, shift = false }
        or mode == "ctrlLeft" and { button = "LeftButton", ctrl = true, alt = false, shift = false } or Settings()
    return g.button == button and g.alt == (IsAltKeyDown and IsAltKeyDown() or false)
        and g.ctrl == (IsControlKeyDown and IsControlKeyDown() or false)
        and g.shift == (IsShiftKeyDown and IsShiftKeyDown() or false)
end
function Actions:Invoke(control, options)
    local binding = self.bindings[control]
    if not binding then return nil, Core:Text("CORE.ITEM_IS_NO_LONGER_AVAILABLE") end
    local intent = binding.GetIntent()
    if not intent then return nil, Core:Text("CORE.THIS_ITEM_HAS_NO_TARGET_TO_ADD") end
    local ref = Core.Contracts:Resolve("action.demands", { major = 1 })
    if not ref then Core:Print(Core:Text("CORE.ACTION_CENTER_IS_NOT_READY_ENABLE_A")); return nil, "unavailable" end
    if options and options.toggle then
        local existing = Core.Contracts:Call(binding.owner, ref, "Lookup", { intent = intent })
        if existing then
            if not existing.revision then Core:Print(Core:Text("CORE.REMOVING_TARGETS_REQUIRES_A_NEWER_ACTION_CENTER")); return nil, "incompatible" end
            local removed, err = Core.Contracts:Call(binding.owner, ref, "Update", { id = existing.id, revision = existing.revision, patch = { state = "removed" } })
            if not removed then Core:Print(err or Core:Text("CORE.REMOVAL_FAILED")); return nil, err end
            Core:Print(Core:Text("CORE.TARGET_REMOVED_FROM_ACTION_CENTER"))
            SetMenuAdded(binding, false)
            self:ScheduleMarkers()
            return { id = existing.id, removed = true }
        end
    end
    local result, err = Core.Contracts:Call(binding.owner, ref, "Add", { intent = intent })
    if not result then Core:Print(err or Core:Text("CORE.ADD_FAILED")); return nil, err end
    if result.needsConfiguration then
        binding.needsConfiguration = true
        self:ShowMenu(control)
        if options and options.keepOpen then
            Core:Print(Core:Text("CORE.THIS_ITEM_REQUIRES_TARGET_DETAILS_CLICK_ITS"))
        else Core.Contracts:Call(binding.owner, ref, "Configure", { intent = intent }) end
    else
        Core:Print(result.existing and ((options and options.keepOpen) and Core:Text("CORE.THIS_TARGET_IS_ALREADY_IN_ACTION_CENTER") or Core:Text("CORE.ADDED_LOCATING_TARGET")) or Core:Text("CORE.ADDED_TO_ACTION_CENTER"))
        if result.existing and not (options and options.keepOpen) then Core.Contracts:Call(binding.owner, ref, "Locate", { id = result.id }) end
        SetMenuAdded(binding, true)
        self:ScheduleMarkers()
    end
    return result
end
function Actions:Handle(control, button)
    local binding = self.bindings[control]
    if not binding or not self:Matches(button) then return false end
    local g = self:GetGesture()
    if Conflicts(binding, g) then Core:Print(Core:Text("CORE.THIS_ADD_GESTURE_CONFLICTS_WITH_THE_ITEM")); return false end
    self:Invoke(control, { keepOpen = true, toggle = true })
    return true
end
function Actions:RefreshMarkers()
    local ref = Core.Contracts:Resolve("action.demands", { major = 1, minMinor = 1 })
    local controls, intents, owner = {}, {}, nil
    for control, binding in pairs(self.bindings) do
        if binding.markerEnabled then
            local intent = binding.GetIntent()
            if intent then
                controls[#controls + 1] = control; intents[#intents + 1] = intent; owner = owner or binding.owner
            else self:SetMarker(control, nil) end
        end
    end
    local result = ref and owner and Core.Contracts:Call(owner, ref, "LookupItems", { intents = intents })
    for i, control in ipairs(controls) do self:SetMarker(control, result and result.items and result.items[i]) end
end
function Actions:SetMarker(control, status)
    local binding = self.bindings[control]
    if not binding then return end
    binding.itemStatus = status
    -- Membership queries retain completion history for inspection. A persistent
    -- marker represents unfinished goals, including intentionally paused ones.
    local shown = status and ((status.active or 0) + (status.paused or 0)) > 0 or false
    if control.yiboGoalMarkerH then
        local dot = self:GetOptions().markerStyle == "dot"
        local h, v = control.yiboGoalMarkerH, control.yiboGoalMarkerV
        h:SetSize(dot and 6 or 8, dot and 4 or 2); v:SetSize(dot and 4 or 2, dot and 6 or 8)
        h:ClearAllPoints(); v:ClearAllPoints()
        h:SetPoint("BOTTOMLEFT", 1, dot and 2 or 1); v:SetPoint("BOTTOMLEFT", dot and 2 or 1, 1)
        local color = dot and Core.UITheme.Colors.accent or Core.UITheme.Colors.goalAdded
        h:SetColorTexture(unpack(color)); v:SetColorTexture(unpack(color))
        h:SetShown(shown); v:SetShown(shown)
    end
end
function Actions:ScheduleMarkers()
    if self.markersQueued then return end
    self.markersQueued = true
    local function Flush() Actions.markersQueued = false; Actions:RefreshMarkers() end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end
function Actions:TooltipLines(lines, control)
    local result = {}
    local previous = control and control.yiboBusinessItemActionTooltipLine
    for _, line in ipairs(lines or {}) do
        local isPreviousActionLine = previous and type(line) == "table" and line.kind == "text" and line.text == previous
        local isActionSpacer = type(line) == "table" and line.businessActionSpacer == true
        if not isPreviousActionLine and not isActionSpacer then result[#result + 1] = Core.Defaults:Copy(line) end
    end
    if control and self.bindings[control] then
        local mode = self:GetOptions().mode
        local actionLine = mode == "menu" and Core:Text("CORE.TOP_RIGHT_ADD_CONFIGURE_CHECK_MARK_LOCATE")
            or (self:GestureLabel() .. Core:Text("CORE.ADD_REMOVE_WHILE_KEEPING_THE_WINDOW_OPEN"))
        local compact = self.bindings[control].compactTooltip
        if compact then
            actionLine = mode == "menu" and Core:Text("CORE.COMPACT_TARGET_MENU")
                or Core:Text("CORE.COMPACT_TARGET_TOGGLE", self:GestureLabel())
        end
        if compact then result[#result + 1] = { kind = "spacer", businessActionSpacer = true } end
        result[#result + 1] = { kind = "text", text = actionLine, color = compact and Core.UITheme.Colors.muted or nil }
        control.yiboBusinessItemActionTooltipLine = actionLine
    elseif control then
        control.yiboBusinessItemActionTooltipLine = nil
    end
    return result
end
function Actions:ShowMenu(control)
    local binding = self.bindings[control]
    if not binding then return end
    if self.hoverControl and self.hoverControl ~= control then
        local previous = self.bindings[self.hoverControl]
        if previous and previous.menu then previous.menu:Hide() end
    end
    self.hoverControl = control
    local status = binding.itemStatus
    if status and status.count > 0 and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(control) then
        GameTooltip:AddLine(Core:Text("FORMAT.ADDED_TARGETS", status.count, status.active, status.paused, status.completed), unpack(Core.UITheme.Colors.goalAdded))
        GameTooltip:Show()
    end
    if not binding.menu then return end
    local mode = self:GetOptions().mode
    if mode ~= "menu" and mode ~= "custom" and not binding.needsConfiguration then binding.menu:Hide(); return end
    local ref = Core.Contracts:Resolve("action.demands", { major = 1 })
    local existing = ref and Core.Contracts:Call(binding.owner, ref, "Lookup", { intent = binding.GetIntent() })
    SetMenuAdded(binding, existing ~= nil and existing ~= false)
    binding.menu:Show()
end
function Actions:RefreshHover()
    local focus, state = Core.Client:ReadMouseFocus()
    if state ~= "known" then
        if self.hoverControl then
            local binding = self.bindings[self.hoverControl]
            if binding and binding.menu then binding.menu:Hide() end
            self.hoverControl = nil
        end
        return
    end
    local control
    for _ = 1, 20 do
        if not focus then break end
        local source = focus.yiboActionSource or focus
        local binding = self.bindings[source]
        if binding and binding.menu and source:IsShown() then control = source; break end
        focus = focus.GetParent and focus:GetParent()
    end
    if control then
        local binding = self.bindings[control]
        local mode = self:GetOptions().mode
        local menuEnabled = mode == "menu" or mode == "custom" or binding.needsConfiguration
        if self.hoverControl ~= control or (menuEnabled and not binding.menu:IsShown()) then self:ShowMenu(control) end
    elseif self.hoverControl then
        local source = self.hoverControl
        local previous = self.bindings[source]
        if previous and previous.menu and (source:IsMouseOver() or previous.menu:IsMouseOver()) then return end
        if self.hoverLeavePending then return end
        self.hoverLeavePending = true
        local function Close()
            Actions.hoverLeavePending = nil
            if Actions.hoverControl ~= source then return end
            local binding = Actions.bindings[source]
            if binding and binding.menu and (source:IsMouseOver() or binding.menu:IsMouseOver()) then return end
            if binding and binding.menu then binding.menu:Hide() end
            Actions.hoverControl = nil
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.12, Close) else Close() end
    end
end
function Actions:WatchHover()
    if not self.hoverFrame then
        self.hoverFrame = CreateFrame("Frame")
        local elapsed = 0
        self.hoverFrame:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.05 then return end
            elapsed = 0
            Actions:RefreshHover()
        end)
    end
    self.hoverFrame:Show()
end
function Actions:LeaveMenu(control)
    -- Crossing from the source control onto its child button must not close it.
    local function Close()
        local binding = Actions.bindings[control]
        if binding and binding.menu and not control:IsMouseOver() and not binding.menu:IsMouseOver() then binding.menu:Hide() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Close) else Close() end
end
function Actions:Bind(control, options)
    if not control or type(options) ~= "table" or type(options.GetIntent) ~= "function" or type(options.owner) ~= "string" then return nil, "invalid-binding" end
    local previous = self.bindings[control]
    local intent = options.GetIntent()
    local intentKey = IntentKey(intent)
    local itemStatus = intentKey and previous and previous.intentKey == intentKey and previous.itemStatus or nil
    if previous and previous.menu then self.hoverBindingCount = self.hoverBindingCount - 1 end
    local binding = { owner = options.owner, GetIntent = options.GetIntent, markerEnabled = options.menu ~= false, reservedButtons = options.reservedButtons or {}, menu = control.yiboItemMenu or (previous and previous.menu),
        intentKey = intentKey, itemStatus = itemStatus, ctrlLeftSafe = options.ctrlLeftSafe == true, ConfigureCtrlLeft = options.ConfigureCtrlLeft,
        compactTooltip = options.compactTooltip == true }
    if binding.ConfigureCtrlLeft then binding.ctrlLeftSafe = binding.ConfigureCtrlLeft(self:GetOptions().mode == "ctrlLeft") == true end
    self.bindings[control] = binding
    if not control.yiboItemCleanup then
        control:HookScript("OnHide", function() Actions:Unbind(control) end)
        control.yiboItemCleanup = true
    end
    if options.menu == false then
        if control.yiboGoalMarkerH then control.yiboGoalMarkerH:Hide(); control.yiboGoalMarkerV:Hide() end
        if binding.menu then binding.menu:Hide() end
        binding.menu = nil
        if self.hoverControl == control then self.hoverControl = nil end
        if self.hoverBindingCount == 0 and self.hoverFrame then self.hoverFrame:Hide() end
        return true
    end
    if not control.yiboGoalMarkerH then
        local color = Core.UITheme.Colors.goalAdded
        control.yiboGoalMarkerH = control:CreateTexture(nil, "OVERLAY", nil, 7)
        control.yiboGoalMarkerV = control:CreateTexture(nil, "OVERLAY", nil, 7)
        control.yiboGoalMarkerH:SetSize(8, 2); control.yiboGoalMarkerV:SetSize(2, 8)
        for _, texture in ipairs({ control.yiboGoalMarkerH, control.yiboGoalMarkerV }) do
            texture:SetPoint("BOTTOMLEFT", 1, 1); texture:SetColorTexture(unpack(color)); texture:Hide()
        end
    end
    if not binding.menu then
        binding.menu = Core.UITheme:CreateButton(control, 16, "+")
        -- CJK client fonts may lack the checkmark glyph. Use WoW's native
        -- check texture instead of rendering a missing-glyph square.
        binding.menu.addedCheck = binding.menu:CreateTexture(nil, "OVERLAY")
        binding.menu.addedCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        binding.menu.addedCheck:SetSize(14, 14); binding.menu.addedCheck:SetPoint("CENTER", 0, 0)
        binding.menu.addedCheck:SetVertexColor(unpack(Core.UITheme.Colors.goalAdded)); binding.menu.addedCheck:Hide()
        control.yiboItemMenu = binding.menu
        binding.menu.yiboActionSource = control
        binding.menu:SetSize(16, 16); binding.menu:SetPoint("TOPRIGHT", 0, 0)
        binding.menu:SetScript("OnClick", function() Actions:Invoke(control) end)
        Core.UITheme:BindTooltip(binding.menu, Core:Text("CORE.ADD_TO_ACTION_CENTER"), { { kind = "text", text = Core:Text("CORE.CLICK_TO_ADD_OR_ENTER_DETAILS_OPEN") } })
    end
    binding.menu:ClearAllPoints()
    if options.menuPlacement == "right" then binding.menu:SetPoint("TOPLEFT", control, "TOPRIGHT", 2, 0)
    else binding.menu:SetPoint("TOPRIGHT", control, "TOPRIGHT", 0, 0) end
    binding.menu:Hide()
    self.hoverBindingCount = self.hoverBindingCount + 1
    if binding.itemStatus then self:SetMarker(control, binding.itemStatus)
    elseif control.yiboGoalMarkerH then control.yiboGoalMarkerH:Hide(); control.yiboGoalMarkerV:Hide() end
    self:WatchHover()
    self:RefreshHover()
    self:ScheduleMarkers()
    -- Dispatch remains explicit at the source's existing handler. Hooking an
    -- arbitrary OnClick cannot consume its original business operation.
    return true, Conflicts(binding, self:GetGesture()) and "gesture-conflict" or nil
end
function Actions:Unbind(control)
    local binding = self.bindings[control]
    if binding and binding.menu then self.hoverBindingCount = self.hoverBindingCount - 1 end
    if binding and binding.ConfigureCtrlLeft and not (Core.Client:IsInCombat()) then binding.ConfigureCtrlLeft(false) end
    if binding and binding.menu then binding.menu:Hide() end
    if control.yiboGoalMarkerH then control.yiboGoalMarkerH:Hide(); control.yiboGoalMarkerV:Hide() end
    self.bindings[control] = nil
    if self.hoverControl == control then self.hoverControl = nil end
    if self.hoverBindingCount == 0 and self.hoverFrame then self.hoverFrame:Hide() end
end
for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
    Core.Events:Register(event, Actions, function(_, descriptor)
        if descriptor.name == "action.demands" then Actions:ScheduleMarkers() end
    end)
end
Core.Capabilities:Register("business-item-actions", 3)
