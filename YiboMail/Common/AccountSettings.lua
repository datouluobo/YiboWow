local Addon = _G.YiboMail
local Theme = _G.YiboCore.UITheme
local Settings = {}; Addon.AccountSettings = Settings
function Settings:GetDefinition()
    local Page = Addon.AccountPage
    return {
            title = Addon:T("UI.TEXT_0592"),
            description = Addon:T("UI.TEXT_0161"),
            CreateSettingsPanel = function(parent, host)
                local width = math.max(280, parent:GetWidth() or 600)
                local narrow = width < 600
                local columnWidth = narrow and width - 24 or (width - 48) / 2
                local businessHeight, section = 0, parent.mailBusinessSettings
                if Addon.FEATURES.send then
                businessHeight = narrow and 776 or 484
                section = section or host.createSection(parent, Addon:T("UI.TEXT_0093"), width, businessHeight)
                parent.mailBusinessSettings = section
                section:SetSize(width, businessHeight); section:Show(); section:ClearAllPoints()
                section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
                if not section.cleanupHook then
                    section.cleanupHook = true
                    section:HookScript("OnHide", function()
                        if section.shortcutRows then section.shortcutRows.menu:Hide() end
                        if section.shortcutColumns then section.shortcutColumns.menu:Hide() end
                    end)
                end
                local function Text(key, value, x, y, textWidth, height, muted)
                    local label = section[key] or Theme:CreateText(section, Theme.Font.assist, muted and Theme.Colors.muted or Theme.Colors.text, "LEFT")
                    section[key] = label; label:ClearAllPoints(); label:SetPoint("TOPLEFT", x, -y)
                    label:SetWidth(textWidth); label:SetHeight(height or 24); label:SetWordWrap(true); label:SetText(value)
                    return label
                end
                Text("groupsTitle", Addon:T("UI.TEXT_0586"), 12, 40, columnWidth)
                Text("groupsHelp", Addon:T("UI.TEXT_0583"), 12, 68, columnWidth, 24, true)
                section.groups = section.groups or {}
                for index, source in ipairs(Addon.RECIPIENT_SOURCES) do
                    local sourceID = source.id
                    local checkbox = section.groups[sourceID] or host.createCheckbox(section, source.label)
                    section.groups[sourceID] = checkbox; checkbox:ClearAllPoints()
                    checkbox:SetPoint("TOPLEFT", 12 + ((index - 1) % 2) * (columnWidth / 2), -(100 + math.floor((index - 1) / 2) * 34))
                    checkbox:SetWidth(columnWidth / 2 - 6); checkbox:SetChecked(Addon:IsRecipientSourceVisible(sourceID))
                    checkbox:SetScript("OnClick", function(control)
                        local visible = not control:GetChecked(); control:SetChecked(visible)
                        Addon.db.settings.recipientGroups = Addon.db.settings.recipientGroups or {}
                        Addon.db.settings.recipientGroups[sourceID] = visible
                        if Addon.Recipients then Addon.Recipients:Changed() end
                    end)
                end
                Text("groupsNote", Addon:T("UI.TEXT_0636"), 12, 204, columnWidth, 40, true)
                Text("reminderTitle", Addon:T("UI.TEXT_0160"), 12, 258, columnWidth)
                local checkbox = section.reminder or host.createCheckbox(section, Addon:T("UI.TEXT_0462"))
                section.reminder = checkbox; checkbox:ClearAllPoints(); checkbox:SetPoint("TOPLEFT", 12, -290)
                checkbox:SetWidth(columnWidth); checkbox:SetChecked(Addon.db.settings.loginReminderEnabled ~= false)
                checkbox.label:SetWordWrap(true)
                checkbox.label:SetHeight(32)
                checkbox:SetScript("OnClick", function(control)
                    control:SetChecked(not control:GetChecked()); Addon.db.settings.loginReminderEnabled = control:GetChecked()
                end)
                Text("reminderNote", Addon:T("UI.TEXT_0321"), 12, 322, columnWidth, 42, true)
                Text("goldConfirmationTitle", Addon:T("UI.TEXT_0673"), 12, 370, columnWidth)
                local nativeConfirmation = Addon.Target and Addon.Target.nativeMoneyConfirmation
                if nativeConfirmation then
                    if section.goldConfirmation then section.goldConfirmation:Hide() end
                else
                    local goldCheckbox = section.goldConfirmation or host.createCheckbox(section, Addon:T("UI.TEXT_0674"))
                    section.goldConfirmation = goldCheckbox; goldCheckbox:Show(); goldCheckbox:ClearAllPoints(); goldCheckbox:SetPoint("TOPLEFT", 12, -402)
                    goldCheckbox:SetWidth(columnWidth); goldCheckbox:SetChecked(Addon.db.settings.confirmGoldSend ~= false)
                    goldCheckbox.label:SetWordWrap(true); goldCheckbox.label:SetHeight(32)
                    goldCheckbox:SetScript("OnClick", function(control)
                        control:SetChecked(not control:GetChecked()); Addon.db.settings.confirmGoldSend = control:GetChecked()
                    end)
                end
                local noteY = nativeConfirmation and 402 or 434
                local goldNote = Text("goldConfirmationNote", Addon:T(nativeConfirmation and "SETTINGS.NATIVE_GOLD_CONFIRMATION" or "UI.TEXT_0675"), 12, noteY, columnWidth, 36, true)
                goldNote:SetHeight(math.max(36, goldNote:GetStringHeight()))
                local goldBottom = noteY + goldNote:GetHeight()
                local gridX, gridY = narrow and 12 or 36 + columnWidth, narrow and math.max(448, goldBottom + 12) or 40
                businessHeight = math.max(businessHeight, goldBottom + 14, narrow and gridY + 328 or 0)
                section:SetHeight(businessHeight)
                Text("gridTitle", Addon:T("UI.TEXT_0294"), gridX, gridY, columnWidth)
                local rows, columns = Addon:GetShortcutLayout()
                local function GridOption(key, title, x, maximum, current)
                    local fieldWidth = (columnWidth - 12) / 2
                    Text(key .. "Title", title, x, gridY + 32, fieldWidth)
                    local options = {}; for value = 1, maximum do options[#options + 1] = { value = value, label = value .. (key == "shortcutRows" and Addon:T("UI.TEXT_0048") or Addon:T("UI.TEXT_0029")) } end
                    local dropdown = section[key] or Theme:CreateDropdown(section, fieldWidth, options)
                    section[key] = dropdown; dropdown:ClearAllPoints(); dropdown:SetWidth(fieldWidth); dropdown:SetOptions(options)
                    dropdown:SetPoint("TOPLEFT", x, -(gridY + 58)); dropdown:SetValue(current)
                    dropdown:SetOnValueChanged(function(value)
                        Addon.db.settings[key] = value
                        if Addon.RecipientUI then Addon.RecipientUI:Hide() end
                        if Addon.NativeUI and Addon.NativeUI.readySend then
                            Addon.NativeUI:LayoutBasicSend(); Addon.NativeUI:RefreshFavoriteButtons()
                        end
                        Page:RefreshShortcutPreview(section)
                    end)
                end
                GridOption("shortcutRows", Addon:T("UI.TEXT_0376"), gridX, 12, rows)
                GridOption("shortcutColumns", Addon:T("UI.TEXT_0375"), gridX + (columnWidth + 12) / 2, 6, columns)
                section.previewSlots = section.previewSlots or {}
                for index = 1, 72 do
                    local slot = section.previewSlots[index]
                    if not slot then
                        slot = CreateFrame("Frame", nil, section, "BackdropTemplate"); section.previewSlots[index] = slot
                        Theme:ApplyPixelBackdrop(slot, { background = false }) -- Gapped tiles: standalone border.
                    end
                    slot:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
                end
                section.previewX, section.previewY = gridX, gridY + 104
                Text("gridCount", "", gridX + 114, gridY + 104, columnWidth - 114, 26, true)
                Text("gridNote", Addon:T("UI.TEXT_0147"), gridX + 114, gridY + 138, columnWidth - 114, 66, true)
                Page:RefreshShortcutPreview(section)
                elseif section then section:Hide() end
                local cache = parent.mailCacheSettings or host.createSection(parent, Addon:T("UI.TEXT_0353"), width, 156)
                parent.mailCacheSettings = cache; cache:SetSize(width, 156); cache:Show()
                if not cache.cleanupHook then
                    cache.cleanupHook = true; cache:HookScript("OnHide", function()
                        if cache.historyDays then cache.historyDays.menu:Hide() end
                        if cache.unverifiedDays then cache.unverifiedDays.menu:Hide() end
                    end)
                end
                local cacheOffset = businessHeight > 0 and businessHeight + 8 or 0
                cache:ClearAllPoints(); cache:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -cacheOffset)
                local columnWidth = (width - 36) / 2
                local function Retention(x, label, key, choices)
                    local title = cache[key .. "Title"] or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.text, "LEFT")
                    cache[key .. "Title"] = title; title:ClearAllPoints()
                    title:SetPoint("TOPLEFT", x, -36); title:SetWidth(columnWidth); title:SetText(label)
                    local found = false; for _, choice in ipairs(choices) do if choice.value == Addon.db.settings[key] then found = true end end
                    if not found then choices[#choices + 1] = { value = Addon.db.settings[key], label = Addon.db.settings[key] .. Addon:T("UI.TEXT_0212") } end
                    local dropdown = cache[key] or Theme:CreateDropdown(cache, columnWidth, choices)
                    dropdown:ClearAllPoints(); dropdown:SetWidth(columnWidth); dropdown:SetOptions(choices)
                    dropdown:SetPoint("TOPLEFT", x, -58); dropdown:SetValue(Addon.db.settings[key])
                    dropdown:SetOnValueChanged(function(value)
                        local applied = Page:SetRetention(key, value, function(accepted) dropdown:SetValue(accepted) end)
                        if not applied then dropdown:SetValue(Addon.db.settings[key]) end
                    end)
                    cache[key] = dropdown
                end
                Retention(12, Addon:T("UI.TEXT_0254"), "historyDays", { { value = 7, label = Addon:T("UI.TEXT_0064") }, { value = 30, label = Addon:T("UI.TEXT_0063") }, { value = 90, label = Addon:T("UI.TEXT_0065") }, { value = 180, label = Addon:T("UI.TEXT_0060") } })
                Retention(24 + columnWidth, Addon:T("UI.TEXT_0291"), "unverifiedDays", { { value = 7, label = Addon:T("UI.TEXT_0064") }, { value = 30, label = Addon:T("UI.TEXT_0063") }, { value = 90, label = Addon:T("UI.TEXT_0065") } })
                local note = cache.note or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.muted, "LEFT")
                cache.note = note; note:ClearAllPoints()
                note:SetPoint("TOPLEFT", 12, -98); note:SetPoint("TOPRIGHT", -12, -98); note:SetHeight(48); note:SetWordWrap(true)
                note:SetText(Addon:T("UI.TEXT_0490"))
                if Addon.FEATURES.send and Addon.SendRulesSettings then return Addon.SendRulesSettings:Host(parent, host, section, cache, width, businessHeight) end
                return cacheOffset + 156
            end,
        }
end
