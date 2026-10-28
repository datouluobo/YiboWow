local Core, Theme = _G.YiboCore, _G.YiboCore.UITheme
local icons, known
local function LoadIcons()
    if icons then return end
    icons, known = {}, {}
    local function Add(icon)
        if type(icon) == "string" and tonumber(icon) then icon = tonumber(icon) end
        if type(icon) == "string" then
            if not icon:find("\\", 1, true) then icon = "Interface\\Icons\\" .. icon end
            if icon:lower():sub(1, 16) ~= "interface\\icons\\" then return end
        elseif type(icon) ~= "number" or icon <= 0 then return end
        if not known[icon] then known[icon] = true; icons[#icons + 1] = icon end
    end
    local native, state = Core.Client:ReadBuiltinIcons()
    for _, icon in ipairs(native or {}) do Add(icon) end
    -- Do not retain a partial catalog after a native error.
    if state ~= "known" then icons, known = nil, nil; return end
    if #icons == 0 then icons, known = nil, nil end -- Retry when client data becomes ready.
end
function Core:IsBuiltinIcon(icon)
    LoadIcons(); return known and known[icon] == true or false
end
function Core:HideIconPicker()
    if self.iconPicker then self.iconPicker:Hide() end
end
function Core:ShowIconPicker(config)
    config = config or {}
    LoadIcons()
    local picker = self.iconPicker
    if not picker then
        picker = CreateFrame("Frame", "YiboCoreIconPicker", UIParent, "BackdropTemplate"); self.iconPicker = picker
        picker:SetFrameStrata("DIALOG"); picker:SetFrameLevel(1100); picker:SetClampedToScreen(true)
        picker:EnableMouse(true); picker:SetToplevel(true)
        picker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        picker:SetBackdropColor(unpack(Theme.Colors.bg)); picker:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
        if UISpecialFrames then table.insert(UISpecialFrames, "YiboCoreIconPicker") end
        picker.title = Theme:CreateText(picker, Theme.Font.section, Theme.Colors.text, "LEFT")
        picker.title:SetPoint("TOPLEFT", 12, -12); picker.title:SetText(Core:Text("CORE.CHOOSE_GAME_ICON"))
        picker.preview = picker:CreateTexture(nil, "ARTWORK"); picker.preview:SetSize(36, 36); picker.preview:SetPoint("TOPLEFT", 12, -44)
        picker.hint = Theme:CreateText(picker, Theme.Font.assist, Theme.Colors.muted, "LEFT")
        picker.hint:SetPoint("TOPLEFT", 60, -44); picker.hint:SetPoint("TOPRIGHT", -12, -44); picker.hint:SetWordWrap(true)
        picker.pageLabel = Theme:CreateText(picker, Theme.Font.assist, Theme.Colors.muted, "CENTER")
        picker.pageLabel:SetPoint("BOTTOM", 0, 57)
        local function Button(label, x, action)
            local width = math.max(80, Theme:MeasureText(Theme.Font.body, label) + 18)
            local button = Theme:CreateButton(picker, width, label); button:SetPoint("BOTTOMLEFT", x, 12); button:SetScript("OnClick", action); return button
        end
        picker.auto = Button(Core:Text("CORE.AUTOMATIC_ICON"), 12, function() picker.selected = nil; picker:Refresh() end)
        picker.confirm = Button(Core:Text("CORE.CONFIRM"), 98, function()
            local callback, selected = picker.config.onConfirm, picker.selected
            picker:Hide(); if callback then callback(selected) end
        end)
        picker.cancel = Button(Core:Text("CORE.CANCEL"), 184, function() picker:Hide() end)
        picker.confirm:ClearAllPoints(); picker.confirm:SetPoint("LEFT", picker.auto, "RIGHT", 6, 0)
        picker.cancel:ClearAllPoints(); picker.cancel:SetPoint("LEFT", picker.confirm, "RIGHT", 6, 0)
        picker.prev = Theme:CreateButton(picker, 72, Core:Text("CORE.PREVIOUS")); picker.prev:SetPoint("BOTTOMLEFT", 12, 48)
        picker.next = Theme:CreateButton(picker, 72, Core:Text("CORE.NEXT")); picker.next:SetPoint("BOTTOMRIGHT", -12, 48)
        picker.prev:SetScript("OnClick", function() picker.page = picker.page - 1; picker:Refresh() end)
        picker.next:SetScript("OnClick", function() picker.page = picker.page + 1; picker:Refresh() end)
        picker.buttons = {}
        picker:SetScript("OnHide", function() picker.config = nil end)
        function picker:Refresh()
            local list = icons or {}
            self.hint:SetText(#list == 0 and Core:Text("CORE.CLIENT_ICON_LIST_IS_UNAVAILABLE_USE_AN") or (self.selected and Core:Text("CORE.ICON_SELECTED_CONFIRM_TO_SAVE") or Core:Text("CORE.AUTOMATIC_ICON_USE_THE_RECIPIENT_S_CLASS")))
            local gridTop = math.max(96, 56 + self.hint:GetStringHeight())
            local columns = math.max(1, math.floor((self:GetWidth() - 24) / 40))
            local rows = math.max(1, math.floor((self:GetHeight() - gridTop - 84) / 40))
            local capacity = columns * rows
            self.capacity = capacity
            local pages = math.max(1, math.ceil(#list / capacity))
            self.page = math.max(1, math.min(self.page, pages))
            for index = 1, capacity do
                local button = self.buttons[index]
                if not button then
                    button = Theme:CreateButton(self, 36, ""); button:SetHeight(36)
                    button.icon = button:CreateTexture(nil, "ARTWORK"); button.icon:SetPoint("TOPLEFT", 3, -3); button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
                    button:SetScript("OnClick", function(control) self.selected = control.texture; self:Refresh() end)
                    self.buttons[index] = button
                end
                button.texture = list[(self.page - 1) * capacity + index]
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", 12 + ((index - 1) % columns) * 40, -(gridTop + math.floor((index - 1) / columns) * 40))
                button.icon:SetTexture(button.texture); button:SetShown(button.texture ~= nil)
                button:SetState(button.texture and button.texture == self.selected and "selected" or "default")
            end
            for index = capacity + 1, #self.buttons do self.buttons[index]:Hide() end
            self.preview:SetTexture(self.selected or self.config.autoTexture or "Interface\\Icons\\INV_Misc_GroupLooking")
            if not self.selected and self.config.autoCoords then self.preview:SetTexCoord(unpack(self.config.autoCoords))
            else self.preview:SetTexCoord(0, 1, 0, 1) end
            self.pageLabel:SetText(self.page .. " / " .. pages .. " · " .. #list .. Core:Text("CORE.ICONS"))
            self.prev:SetEnabled(self.page > 1); self.next:SetEnabled(self.page < pages)
        end
    end
    picker.config, picker.selected, picker.page = config, config.icon, 1
    picker:SetSize(math.max(280, math.min(512, UIParent:GetWidth() - 32)), math.max(260, math.min(420, UIParent:GetHeight() - 32)))
    picker:Refresh()
    local capacity = picker.capacity
    for index, icon in ipairs(icons or {}) do if icon == config.icon then picker.page = math.ceil(index / capacity); break end end
    picker:ClearAllPoints(); picker:SetPoint("CENTER"); picker:Refresh(); picker:Show()
    return picker
end
