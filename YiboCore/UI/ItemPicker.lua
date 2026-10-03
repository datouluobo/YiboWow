local Core, Theme = _G.YiboCore, _G.YiboCore.UITheme
Core.Capabilities:Register("item-picker", 1)

function Core:CreateItemPicker(parent, config)
    local picker = CreateFrame("Frame", nil, parent)
    picker.config, picker.generation, picker.candidates, picker.page = config or {}, 0, {}, 1
    picker.preview = Theme:CreateText(picker, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    picker.preview:SetWordWrap(true)
    function picker:Feedback(message)
        self.preview:SetText(message or "")
        if self.layoutWidth then self:Layout(self.layoutWidth) end
    end
    function picker:IsCurrent(generation) return not self.unbound and self:IsVisible() and self.generation == generation end
    function picker:Invalidate()
        self.generation = self.generation + 1
        if self.request then self.request:Cancel(); self.request = nil end
        if self.confirmation then self.confirmation:Cancel(); self.confirmation = nil end
        self.busy = false
        self.canRetry = false
    end
    function picker:SetValue(value)
        self:Invalidate(); self.selected = nil; self.candidates = {}; self.page = 1
        self.input:SetValue(value); self:UpdateCandidates(); self:Feedback("")
    end
    function picker:Unbind() self:Invalidate(); self.unbound = true; self:Hide() end
    function picker:UpdateCandidates()
        local options, capacity = {}, 8
        local pages = math.max(1, math.ceil(#self.candidates / capacity))
        self.page = math.max(1, math.min(self.page, pages))
        if self.page > 1 then options[#options + 1] = { value = "previous", label = "上一页" } end
        for index = (self.page - 1) * capacity + 1, math.min(self.page * capacity, #self.candidates) do
            local info = self.candidates[index]
            options[#options + 1] = { value = info.itemID, label = (info.name or "物品") .. " · " .. info.itemID }
        end
        if self.page < pages then options[#options + 1] = { value = "next", label = "下一页" } end
        self.dropdown:SetOptions(options)
        self.dropdown:SetText(#self.candidates > 0 and ("选择候选 · " .. self.page .. "/" .. pages) or "暂无候选")
        self.dropdown:SetEnabled(#self.candidates > 0)
        if #self.candidates <= 1 then self.dropdown.menu:Hide() end
        if self.layoutWidth then self:Layout(self.layoutWidth) end
    end
    function picker:Finish(ok, message, generation)
        if not self:IsCurrent(generation) then return end
        self.busy = false
        if ok then self:SetValue(""); self:Feedback(message or "操作成功。")
        else self:Feedback(message or "操作失败。") end
        if ok and self.config.OnSuccess then self.config.OnSuccess() end
    end
    function picker:Run(action, info, generation)
        if not self:IsCurrent(generation) then return end
        if action == "select" then
            self.busy = false
            if self.config.OnSelected then self.config.OnSelected(info) end
            return
        end
        if action == "toggle" then
            action = self.config.Exists and self.config.Exists(info) and "remove" or "add"
        end
        local operation = self.config[action]
        if not operation then self.busy = false; self:Feedback("该操作未启用。"); return end
        if operation.Validate then
            local ok, message = operation.Validate(info)
            if not ok then self:Finish(false, message, generation); return end
        end
        local function Execute()
            if not self:IsCurrent(generation) then return end
            -- Revalidate at acceptance: business state may have changed while the popup was open.
            if operation.Validate then
                local ok, message = operation.Validate(info)
                if not ok then self:Finish(false, message, generation); return end
            end
            local ok, message = operation.Execute(info)
            self:Finish(ok, message, generation)
        end
        local text = operation.Confirm and operation.Confirm(info)
        if text then
            self.confirmation = Core.ItemConfirmation:Show({ text = text,
                IsCurrent = function() return self:IsCurrent(generation) end,
                OnAccept = Execute,
                OnCancel = function()
                    if self:IsCurrent(generation) then self.busy = false; self:Feedback("已取消；输入已保留。") end
                end })
            if not self.confirmation then self:Finish(false, "无法打开确认框，请重试。", generation) end
        else Execute() end
    end
    function picker:Resolve(action, retry)
        if self.busy or self.unbound then return end
        self:Invalidate()
        local generation = self.generation
        local candidates, message = Core.ItemResolver:Parse(self.input:GetText(), self.config.resolve)
        if not candidates then self:Feedback(message); return end
        self.candidates = candidates; self:UpdateCandidates()
        local selected
        if self.selected then for _, info in ipairs(candidates) do if info.itemID == self.selected then selected = info end end end
        if not selected and #candidates == 1 then selected = candidates[1] end
        if not selected then self:Feedback("找到多个物品，请明确选择候选后再操作。"); return end
        self.busy, self.lastAction = true, action
        self:Feedback("正在加载物品信息…")
        self.request = Core.ItemResolver:Request(selected.itemID, function(info, err)
            if not self:IsCurrent(generation) then return end
            if err then self.canRetry = info and info.state == "failed"; self:Finish(false, err, generation); return end
            self:Feedback((info.icon and ("|T" .. info.icon .. ":20:20|t ") or "") .. info.name .. " · " .. info.itemID)
            self:Run(action, info, generation)
        end, { retry = retry })
    end
    picker.input = Theme:CreateInput(picker, {
        placeholder = picker.config.placeholder or "物品 ID、链接或名称", maxLetters = 255,
        OnChanged = function()
            picker:Invalidate(); picker.selected = nil; picker.candidates = {}; picker.page = 1
            picker:UpdateCandidates(); picker:Feedback("")
        end,
        OnSubmit = function() picker:Resolve(picker.config.enterAction or (picker.config.add and "add" or "select")) end,
    })
    picker.dropdown = Theme:CreateDropdown(picker, 240, {})
    picker.dropdown:HookScript("OnClick", function(control)
        if control.menu:IsShown() and control.menu:GetBottom() and control.menu:GetBottom() < 16 then
            control.menu:ClearAllPoints(); control.menu:SetPoint("BOTTOMLEFT", control, "TOPLEFT", 0, 2)
        end
    end)
    picker.dropdown:SetOnValueChanged(function(value)
        if value == "next" or value == "previous" then
            picker.page = picker.page + (value == "next" and 1 or -1); picker:UpdateCandidates(); return
        end
        picker:Invalidate(); picker.selected = value
        local info = Core.ItemResolver:GetInfo(value)
        picker:Feedback((info.name or "物品") .. " · " .. value .. "；再次点击操作按钮提交。")
    end)
    picker.controls = { { control = picker.input, width = 200, flexible = true } }
    if picker.config.candidateDropdown ~= false then
        picker.controls[#picker.controls + 1] = { control = picker.dropdown, width = 200, flexible = true }
    else picker.dropdown:Hide() end
    local function Button(label, callback, style, width)
        width = math.max(width, Theme:MeasureText(Theme.Font.body, label) + Theme.Space.xs * 3)
        local button = Theme:CreateButton(picker, width, label, style or "secondary")
        button:SetScript("OnClick", callback)
        picker.controls[#picker.controls + 1] = { control = button, width = width }
        return button
    end
    if picker.config.add then Button(picker.config.add.label or "添加物品", function() picker:Resolve("add") end, nil, 112) end
    if picker.config.dropMode then
        picker.drop = Button("拖放物品到这里", function() picker:ReadCursor() end, nil, 180)
        picker.drop:RegisterForDrag("LeftButton")
        picker.drop:SetScript("OnReceiveDrag", function() picker:ReadCursor() end)
    end
    picker.retry = Button("重试加载", function() picker:Resolve(picker.lastAction or picker.config.enterAction or "select", true) end, nil, 100)
    for _, definition in ipairs(picker.config.actions or {}) do
        local action = definition
        local button = Button(action.label, function()
            if picker.busy then return end
            if action.IsEnabled and not action.IsEnabled() then picker:Feedback("当前无法执行该操作。"); return end
            picker:Invalidate()
            local ok, message = action.Execute()
            picker:Finish(ok, message, picker.generation)
        end, action.style, action.width or 160)
        button.extensionAction = action
        if action.IsEnabled then button:SetEnabled(action.IsEnabled()) end
    end
    -- Keep the destructive action last in the data-and-cache operation group.
    if picker.config.remove then
        picker.remove = Button(picker.config.remove.label or "删除自定义物品", function() picker:Resolve("remove") end, "danger", 160)
    end
    function picker:ReadCursor()
        if self.busy or self.unbound then return end
        local kind, itemID = GetCursorInfo()
        if kind ~= "item" then self:Feedback("请从背包拖动物品到这里。"); return end
        local parsed = Core.ItemResolver:Parse(itemID, { allowName = false })
        if not parsed then self:Feedback("无效物品拖放。"); return end
        self:SetValue(itemID)
        -- Cursor is cleared only after a valid item identity is captured. No item action is performed.
        if ClearCursor then ClearCursor() end
        self:Resolve(self.config.dropMode)
    end
    function picker:Layout(width)
        width = math.max(1, width); self.layoutWidth = width; self:SetWidth(width)
        -- Reserve breathing room between the operation group and the host scrollbar.
        width = math.max(1, width - (self.config.rightInset or Theme.Space.md))
        self.layoutContentWidth = width
        local y, height, gap = 0, Theme.Size.standard, Theme.Space.xs
        local rows, row = {}, { groups = {}, used = 0, flexible = 0 }
        local function IsVisible(group)
            return (group.control ~= self.dropdown or #self.candidates > 1)
                and (group.control ~= self.retry or self.canRetry == true)
        end
        local buttonWidth = 0
        for _, group in ipairs(self.controls) do
            if not group.flexible and IsVisible(group) then buttonWidth = math.max(buttonWidth, group.width) end
        end
        for _, group in ipairs(self.controls) do
            local action = group.control.extensionAction
            if action and action.IsEnabled then group.control:SetEnabled(action.IsEnabled()) end
            local visible = IsVisible(group)
            group.control:SetShown(visible)
            if visible then
                local controlWidth = math.min(group.flexible and group.width or buttonWidth, width)
                if #row.groups > 0 and row.used + gap + controlWidth > width then
                    rows[#rows + 1] = row; row = { groups = {}, used = 0, flexible = 0 }
                end
                if #row.groups > 0 then row.used = row.used + gap end
                row.groups[#row.groups + 1] = { group = group, width = controlWidth }
                row.used = row.used + controlWidth
                if group.flexible then row.flexible = row.flexible + 1 end
            end
        end
        if #row.groups > 0 then rows[#rows + 1] = row end
        for _, line in ipairs(rows) do
            local x = 0
            local extra = line.flexible > 0 and (width - line.used) / line.flexible or 0
            for _, cell in ipairs(line.groups) do
                local control = cell.group.control
                local controlWidth = cell.width + (cell.group.flexible and extra or 0)
                control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y); control:SetWidth(controlWidth)
                x = x + controlWidth + gap
            end
            y = y + height + gap
        end
        local hasFeedback = self.preview:GetText() ~= "" and self.preview:GetText() ~= nil
        self.preview:SetShown(hasFeedback)
        if hasFeedback then
            self.preview:ClearAllPoints(); self.preview:SetPoint("TOPLEFT", 0, -y); self.preview:SetWidth(width)
            self.preview:SetHeight(0)
            local feedbackHeight = math.max(Theme.Font.assist + 4, self.preview:GetStringHeight() or 0)
            self.preview:SetHeight(feedbackHeight)
            y = y + feedbackHeight + gap
        end
        local previousHeight = self.layoutHeight
        self.layoutHeight = y; self:SetHeight(y)
        if previousHeight and previousHeight ~= y and self.config.OnLayoutChanged then self.config.OnLayoutChanged(y) end
        return y
    end
    picker:SetScript("OnHide", function(control)
        control:Invalidate(); control.dropdown.menu:Hide(); control.input:ClearFocus()
    end)
    picker:UpdateCandidates()
    return picker
end
