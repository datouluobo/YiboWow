local Addon = _G.YiboVault
local Core = _G.YiboCore
local Page = {}
Addon.AccountPage = Page
local PAGE_ID = "vault-items"
Page.ID = PAGE_ID

local function BuildScope(context)
    local ids = {}
    local characters = {}
    local realm = context and context.scope and context.scope:match("^realm:(.+)$")
    for _, character in ipairs(context and context.characters or {}) do
        if not realm or character.realm == realm then
            ids[#ids + 1] = character.id
            characters[#characters + 1] = character
        end
    end
    return { mode = "characters", characterIDs = ids }, characters
end

function Page:IsStaleForCurrentView(record, currentCharacterID)
    if record.state ~= "stale" then return false end
    if record.source == "guild-bank" then return true end
    return record.characterID ~= nil and record.characterID == currentCharacterID
end

function Page:GetScope()
    for _, definition in ipairs(Core.AccountView:GetRegisteredPages()) do
        if definition.id == PAGE_ID then
            local context = Core.AccountView:BuildContext(definition)
            return BuildScope(context)
        end
    end
    local current = Core.Characters:GetCurrent()
    if current then return { mode = "characters", characterIDs = { current.id } }, { current } end
    return { mode = "characters", characterIDs = {} }, {}
end

function Page:GetTooltipScope()
    local view = Core.AccountView
    local visible = view:GetVisibleCharacters()
    local characters = Core.CharacterSort:Sort(visible, view:GetEffectiveCharacterSort(PAGE_ID),
        Core.Characters:GetCurrentID(), view:GetCustomCharacterOrder())
    local current = Core.Characters:GetCurrent()
    local realm = current and current.realm
    local allRealms = Addon.db and Addon.db.settings and Addon.db.settings.tooltipRealmScope == "all"
    local ids, included = {}, {}
    for _, character in ipairs(characters) do
        if allRealms or (realm and character.realm == realm)
            or (not realm and current and character.id == current.id) then
            ids[#ids + 1] = character.id
            included[#included + 1] = character
        end
    end
    return { mode = "characters", characterIDs = ids }, included, allRealms
end

local GUILDS_PER_PAGE = 4
local DELETE_GUILD_POPUP = "YIBOVAULT_DELETE_GUILD_CACHE"

local function CachedGuilds()
    local guilds = {}
    for key, guild in pairs(Addon.db.byGuild or {}) do
        if type(guild) == "table" then
            guilds[#guilds + 1] = { key = key, name = guild.guildName or Addon:T("TEXT.PREVIOUS_GUILD_380DF6"),
                realm = guild.realm or Addon:T("TEXT.UNKNOWN_REALM_7EFD20"), hidden = guild.hidden == true }
        end
    end
    table.sort(guilds, function(left, right)
        local a, b = left.name .. "\001" .. left.realm, right.name .. "\001" .. right.realm
        return a == b and left.key < right.key or a < b
    end)
    return guilds
end

local function ConfirmGuildDelete(key, refresh)
    local guild = Addon.db.byGuild and Addon.db.byGuild[key]
    if not guild then return end
    StaticPopupDialogs[DELETE_GUILD_POPUP] = {
        text = "%s", button1 = Addon:T("TEXT.DELETE_CACHE_EA92B8"), button2 = Addon:T("TEXT.CANCEL_4D0B46"), timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, data)
            local ok, errorMessage = Addon:DeleteGuild(data.key)
            if not ok then Addon:Print(errorMessage); return end
            if data.refresh then data.refresh() end
        end,
    }
    local name = tostring(guild.guildName or Addon:T("TEXT.PREVIOUS_GUILD_380DF6")) .. "-" .. tostring(guild.realm or Addon:T("TEXT.UNKNOWN_REALM_7EFD20"))
    StaticPopup_Show(DELETE_GUILD_POPUP,
        Addon:T("TEXT.DELETE_017540") .. name .. Addon:T("TEXT.AND_ALL_GUILD_BANK_TABS_ITEMS_AND_CAPACITY_CD1BD3"),
        nil, { key = key, refresh = refresh })
end

function Page:CreateSettingsPanel(parent, context)
    local theme = Core.UITheme
    local panel = parent.yiboVaultSettings or CreateFrame("Frame", nil, parent)
    parent.yiboVaultSettings = panel
    local width = parent:GetWidth() or 0
    if width < 1 then width = 560 end
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    panel:SetWidth(width); panel:Show()

    local business = panel.business or context.createSection(panel, Addon:T("TEXT.BUSINESS_SETTINGS_60735B"), width, 236)
    panel.business = business
    business:ClearAllPoints(); business:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    business:SetHeight(236)
    business:SetWidth(width); business:Show()
    local enabled = panel.enabled or context.createCheckbox(business, Addon:T("TEXT.SHOW_VAULT_ITEM_TOOLTIP_SUMMARY_93E771"))
    panel.enabled = enabled
    enabled:ClearAllPoints(); enabled:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -35)
    enabled:SetWidth(width - 28); enabled:SetChecked(Addon.db.settings.tooltipEnabled ~= false)
    enabled:SetScript("OnClick", function(control)
        local value = not control:GetChecked()
        control:SetChecked(value)
        Addon.db.settings.tooltipEnabled = value
        if Addon.Tooltip then Addon.Tooltip:Invalidate() end
    end)
    enabled:Show()
    local scopeLabel = panel.scopeLabel or context.createText(business, theme.Font.assist, theme.Colors.text, "LEFT")
    panel.scopeLabel = scopeLabel
    scopeLabel:ClearAllPoints(); scopeLabel:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -76)
    scopeLabel:SetText(Addon:T("TEXT.ITEM_TOOLTIP_REALM_SCOPE_EDD971")); scopeLabel:Show()
    local scope = panel.scope or theme:CreateDropdown(business, 188, {})
    panel.scope = scope
    scope:ClearAllPoints(); scope:SetPoint("TOPLEFT", business, "TOPLEFT", math.max(14, math.min(214, width - 202)), -69)
    scope:SetOptions({ { value = "current", label = Addon:T("TEXT.CURRENT_REALM_1BC56D") }, { value = "all", label = Addon:T("TEXT.ALL_REALMS_A166AB") } })
    scope:SetValue(Addon.db.settings.tooltipRealmScope)
    scope:SetOnValueChanged(function(value)
        Addon.db.settings.tooltipRealmScope = value == "all" and "all" or "current"
        if Addon.Tooltip then Addon.Tooltip:Invalidate() end
    end)
    scope:Show()
    local scopeNote = panel.scopeNote or context.createText(business, theme.Font.assist, theme.Colors.muted, "LEFT")
    panel.scopeNote = scopeNote
    scopeNote:ClearAllPoints(); scopeNote:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -117)
    scopeNote:SetPoint("RIGHT", business, "RIGHT", -14, 0)
    scopeNote:SetText(Addon:T("TEXT.ONLY_AFFECTS_ITEM_TOOLTIPS_THE_STORAGE_PAG_6CE57D"))
    scopeNote:Show()

    local filterLabel = panel.filterLabel or context.createText(business, theme.Font.assist, theme.Colors.text, "LEFT")
    panel.filterLabel = filterLabel
    filterLabel:ClearAllPoints(); filterLabel:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -148)
    filterLabel:SetText(Addon:T("TEXT.FILTER_THE_ITEM_TOOLTIP_SUMMARY_BY_ITEM_ID_9DF46F")); filterLabel:Show()
    local UpdateItemFilter
    local itemInput = panel.itemInput or theme:CreateInput(business, {
        width = 150, height = 24, numeric = true, maxLetters = 10,
        OnSubmit = function() if UpdateItemFilter then UpdateItemFilter(true) end end,
    })
    panel.itemInput = itemInput
    itemInput:ClearAllPoints(); itemInput:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -176)
    local addButton = panel.addItemButton or context.createButton(business, 72, Addon:T("TEXT.FILTER_527086"), "secondary")
    panel.addItemButton = addButton
    addButton:ClearAllPoints(); addButton:SetPoint("LEFT", itemInput, "RIGHT", 8, 0); addButton:SetSize(72, 24); addButton:SetText(Addon:T("TEXT.FILTER_527086"))
    local removeButton = panel.removeItemButton or context.createButton(business, 110, Addon:T("TEXT.REMOVE_FILTER_91AC42"), "secondary")
    panel.removeItemButton = removeButton
    removeButton:ClearAllPoints(); removeButton:SetPoint("LEFT", addButton, "RIGHT", 6, 0); removeButton:SetSize(110, 24); removeButton:SetText(Addon:T("TEXT.REMOVE_FILTER_91AC42"))
    local filterItems = panel.filterItems or context.createText(business, theme.Font.assist, theme.Colors.muted, "LEFT")
    panel.filterItems = filterItems
    filterItems:ClearAllPoints(); filterItems:SetPoint("TOPLEFT", business, "TOPLEFT", 14, -207)
    filterItems:SetPoint("RIGHT", business, "RIGHT", -14, 0); filterItems:SetWordWrap(true); filterItems:SetHeight(24)
    local function RefreshFilteredItems()
        local ids = {}
        for id, hidden in pairs(Addon.db.settings.hiddenTooltipItems or {}) do
            if hidden then ids[#ids + 1] = tonumber(id) end
        end
        table.sort(ids)
        local labels = {}
        for _, id in ipairs(ids) do labels[#labels + 1] = tostring(id) end
        filterItems:SetText(#labels > 0 and Addon:T("TEXT.FILTERED_ITEM_IDS", table.concat(labels, Addon:T("TEXT.LIST_SEPARATOR")))
            or Addon:T("TEXT.NO_ITEMS_ARE_FILTERED_A58C1D"))
    end
    UpdateItemFilter = function(add)
        local id = tonumber(itemInput:GetText())
        if not id or id <= 0 then return end
        Addon.db.settings.hiddenTooltipItems = Addon.db.settings.hiddenTooltipItems or {}
        Addon.db.settings.hiddenTooltipItems[id] = add and true or nil
        itemInput:SetValue("")
        RefreshFilteredItems()
        if Addon.Tooltip then Addon.Tooltip:Invalidate() end
    end
    addButton:SetScript("OnClick", function() UpdateItemFilter(true) end)
    removeButton:SetScript("OnClick", function() UpdateItemFilter(false) end)
    itemInput:Show(); addButton:Show(); removeButton:Show(); RefreshFilteredItems(); filterItems:Show()

    local data = panel.data or context.createSection(panel, Addon:T("TEXT.DATA_AND_CACHE_DF7FFF"), width, 130)
    panel.data = data
    data:ClearAllPoints(); data:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -246)
    data:SetWidth(width); data:Show()
    local note = panel.dataNote or context.createText(data, theme.Font.assist, theme.Colors.muted, "LEFT")
    panel.dataNote = note
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", data, "TOPLEFT", 14, -39)
    note:SetPoint("RIGHT", data, "RIGHT", -14, 0)
    local stacked = width < 540
    note:SetWordWrap(true)
    note:SetHeight(stacked and 36 or 20)
    note:SetText(Addon:T("TEXT.MANAGE_CHARACTER_CACHES_IN_CORE_S_CHARACTE_23BC9A"))
    note:Show()
    local guilds = CachedGuilds()
    panel.guildPage = math.max(1, math.min(panel.guildPage or 1, math.max(1, math.ceil(#guilds / GUILDS_PER_PAGE))))
    local visibleCount = math.min(GUILDS_PER_PAGE, math.max(0, #guilds - (panel.guildPage - 1) * GUILDS_PER_PAGE))
    local rowTop, rowPitch = stacked and 88 or 74, stacked and 60 or 42
    local footerTop = rowTop + visibleCount * rowPitch + 2
    local dataHeight = math.max(stacked and 142 or 130, footerTop + 34)
    data:SetHeight(dataHeight)
    panel:SetHeight(246 + dataHeight)
    panel.guildRows = panel.guildRows or {}
    for index = 1, GUILDS_PER_PAGE do
        local row = panel.guildRows[index]
        if not row then
            row = CreateFrame("Frame", nil, data)
            row.name = context.createText(row, theme.Font.assist, theme.Colors.text, "LEFT")
            row.view = context.createButton(row, 54, Addon:T("TEXT.VIEW_F7ACEF"), "secondary")
            row.toggle = context.createButton(row, 62, Addon:T("TEXT.HIDE_BB0E7E"), "secondary")
            row.delete = context.createButton(row, 90, Addon:T("TEXT.DELETE_CACHE_EA92B8"), "danger")
            panel.guildRows[index] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", data, "TOPLEFT", 14, -rowTop - (index - 1) * rowPitch)
        row:SetWidth(width - 28); row:SetHeight(stacked and 54 or 32)
        local guild = guilds[(panel.guildPage - 1) * GUILDS_PER_PAGE + index]
        row:SetShown(guild ~= nil)
        if guild then
            row.name:ClearAllPoints()
            if stacked then
                row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
                row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -1)
                row.name:SetHeight(18)
            else
                row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -230, 0)
            end
            row.name:SetText(guild.name .. " · " .. guild.realm .. (guild.hidden and Addon:T("TEXT.HIDDEN_5FC6CF") or ""))
            row.view:ClearAllPoints()
            row.toggle:ClearAllPoints()
            row.delete:ClearAllPoints()
            local anchor = stacked and "BOTTOMRIGHT" or "RIGHT"
            row.view:SetPoint(anchor, row, anchor, -168, 0)
            row.toggle:SetPoint(anchor, row, anchor, -98, 0)
            row.delete:SetPoint(anchor, row, anchor, 0, 0)
            row.toggle:SetText(guild.hidden and Addon:T("TEXT.RESTORE_79748C") or Addon:T("TEXT.HIDE_BB0E7E"))
            row.view:SetScript("OnClick", function()
                Addon.StoragePage:OpenGuild(guild.key)
            end)
            row.toggle:SetScript("OnClick", function()
                Addon:SetGuildHidden(guild.key, not guild.hidden)
                if context.refreshPanel then context.refreshPanel() end
            end)
            row.delete:SetScript("OnClick", function()
                ConfirmGuildDelete(guild.key, function()
                    if context.refreshPage then context.refreshPage()
                    elseif context.refreshPanel then context.refreshPanel() end
                end)
            end)
        end
    end
    local pager = panel.guildPager or context.createText(data, theme.Font.assist, theme.Colors.muted, "LEFT")
    panel.guildPager = pager
    pager:ClearAllPoints(); pager:SetPoint("TOPLEFT", data, "TOPLEFT", 14, -footerTop - 5)
    pager:SetText(#guilds == 0 and Addon:T("TEXT.NO_GUILD_BANK_CACHES_YET_7D4D4E") or
        (Addon:T("TEXT.GUILD_CACHES_B08D11") .. #guilds .. Addon:T("TEXT.ITEMS_PAGE_2CD1D3") .. panel.guildPage .. "/" .. math.ceil(#guilds / GUILDS_PER_PAGE) .. Addon:T("TEXT.PAGES_AF8438")))
    pager:Show()
    local previous = panel.previous or context.createButton(data, 42, "‹", "secondary")
    panel.previous = previous
    previous:ClearAllPoints(); previous:SetPoint("TOPRIGHT", data, "TOPRIGHT", -69, -footerTop)
    previous:SetScript("OnClick", function()
        panel.guildPage = math.max(1, panel.guildPage - 1)
        if context.refreshPage then context.refreshPage()
        elseif context.refreshPanel then context.refreshPanel() end
    end)
    previous:SetShown(panel.guildPage > 1)
    local nextPage = panel.nextPage or context.createButton(data, 42, "›", "secondary")
    panel.nextPage = nextPage
    nextPage:ClearAllPoints(); nextPage:SetPoint("TOPRIGHT", data, "TOPRIGHT", -14, -footerTop)
    nextPage:SetScript("OnClick", function()
        panel.guildPage = panel.guildPage + 1
        if context.refreshPage then context.refreshPage()
        elseif context.refreshPanel then context.refreshPanel() end
    end)
    nextPage:SetShown(panel.guildPage * GUILDS_PER_PAGE < #guilds)
    return 246 + dataHeight
end

function Page:Create(parent)
    local ok, err = pcall(Addon.StoragePage.Create, Addon.StoragePage, parent)
    if not ok then
        local page = parent.yiboVaultStoragePage
        if page then page.createError = tostring(err) end
        error(err)
    end
end

function Page:Refresh(parent, context)
    Addon.StoragePage:Refresh(parent, context)
end

function Page:Register()
    local registered, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = PAGE_ID,
        title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"),
        order = 50,
        defaultEnabled = true,
        previewEnabled = false,
        GetSurfaceMetrics = function()
            return { minContentWidth = 650, naturalContentWidth = 1000,
                minContentHeight = 490, naturalContentHeight = 630 }
        end,
        scope = { mode = "realms", allTitle = Addon:T("TEXT.ALL_REALMS_A166AB") },
        settings = {
            title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"),
            description = Addon:T("TEXT.VAULT_ITEM_TOOLTIP_AND_CACHE_SETTINGS_03FFD9"),
            CreateSettingsPanel = function(parent, context) return Page:CreateSettingsPanel(parent, context) end,
        },
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not registered then return nil, err end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "yva", brokerName = "YiboVault", pageID = PAGE_ID,
        text = Addon:T("TEXT.YIBO_ITEM_OVERVIEW_CBF21F"), icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon",
        defaultChannels = { minimap = false, broker = false, builtinBar = false },
    })
    if not entry then return nil, entryError end
    Addon.Items.Events:Register(Page, function()
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end)
    return true
end

function Page:Open()
    Core.AccountView:Toggle(PAGE_ID)
end
