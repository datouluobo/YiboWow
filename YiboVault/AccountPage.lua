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
            guilds[#guilds + 1] = { key = key, name = guild.guildName or "历史公会",
                realm = guild.realm or "未知服务器", hidden = guild.hidden == true }
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
        text = "%s", button1 = "删除缓存", button2 = "取消", timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, data)
            local ok, errorMessage = Addon:DeleteGuild(data.key)
            if not ok then Addon:Print(errorMessage); return end
            if data.refresh then data.refresh() end
        end,
    }
    local name = tostring(guild.guildName or "历史公会") .. "-" .. tostring(guild.realm or "未知服务器")
    StaticPopup_Show(DELETE_GUILD_POPUP,
        "确定删除“" .. name .. "”的全部公会银行页签、物品和容量缓存吗？\n隐藏状态也会清除。此操作不可撤销；再次访问后可重新采集。",
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

    local business = panel.business or context.createSection(panel, "业务设置", width, 166)
    panel.business = business
    business:ClearAllPoints(); business:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    business:SetWidth(width); business:Show()
    local enabled = panel.enabled or context.createCheckbox(business, "显示 Vault 物品 Tooltip 摘要")
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
    scopeLabel:SetText("物品 Tooltip 的服务器范围"); scopeLabel:Show()
    local scope = panel.scope or theme:CreateDropdown(business, 188, {})
    panel.scope = scope
    scope:ClearAllPoints(); scope:SetPoint("TOPLEFT", business, "TOPLEFT", math.max(14, math.min(214, width - 202)), -69)
    scope:SetOptions({ { value = "current", label = "当前服务器" }, { value = "all", label = "所有服务器" } })
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
    scopeNote:SetText("只影响物品悬停；仓储页面使用 Core 的范围切换。")
    scopeNote:Show()

    local data = panel.data or context.createSection(panel, "数据与缓存", width, 130)
    panel.data = data
    data:ClearAllPoints(); data:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -176)
    data:SetWidth(width); data:Show()
    local note = panel.dataNote or context.createText(data, theme.Font.assist, theme.Colors.muted, "LEFT")
    panel.dataNote = note
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", data, "TOPLEFT", 14, -39)
    note:SetPoint("RIGHT", data, "RIGHT", -14, 0)
    local stacked = width < 540
    note:SetWordWrap(true)
    note:SetHeight(stacked and 36 or 20)
    note:SetText("角色缓存在 Core 的“角色与排序”中管理。隐藏公会仍会采集，但默认不显示或统计。")
    note:Show()
    local guilds = CachedGuilds()
    panel.guildPage = math.max(1, math.min(panel.guildPage or 1, math.max(1, math.ceil(#guilds / GUILDS_PER_PAGE))))
    local visibleCount = math.min(GUILDS_PER_PAGE, math.max(0, #guilds - (panel.guildPage - 1) * GUILDS_PER_PAGE))
    local rowTop, rowPitch = stacked and 88 or 74, stacked and 60 or 42
    local footerTop = rowTop + visibleCount * rowPitch + 2
    local dataHeight = math.max(stacked and 142 or 130, footerTop + 34)
    data:SetHeight(dataHeight)
    panel:SetHeight(176 + dataHeight)
    panel.guildRows = panel.guildRows or {}
    for index = 1, GUILDS_PER_PAGE do
        local row = panel.guildRows[index]
        if not row then
            row = CreateFrame("Frame", nil, data)
            row.name = context.createText(row, theme.Font.assist, theme.Colors.text, "LEFT")
            row.view = context.createButton(row, 54, "查看", "secondary")
            row.toggle = context.createButton(row, 62, "隐藏", "secondary")
            row.delete = context.createButton(row, 90, "删除缓存", "danger")
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
            row.name:SetText(guild.name .. " · " .. guild.realm .. (guild.hidden and " · 已隐藏" or ""))
            row.view:ClearAllPoints()
            row.toggle:ClearAllPoints()
            row.delete:ClearAllPoints()
            local anchor = stacked and "BOTTOMRIGHT" or "RIGHT"
            row.view:SetPoint(anchor, row, anchor, -168, 0)
            row.toggle:SetPoint(anchor, row, anchor, -98, 0)
            row.delete:SetPoint(anchor, row, anchor, 0, 0)
            row.toggle:SetText(guild.hidden and "恢复" or "隐藏")
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
    pager:SetText(#guilds == 0 and "暂无公会银行缓存" or
        ("公会缓存 " .. #guilds .. " 项 · 第 " .. panel.guildPage .. "/" .. math.ceil(#guilds / GUILDS_PER_PAGE) .. " 页"))
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
    return 176 + dataHeight
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
        title = "物品总览",
        order = 50,
        defaultEnabled = true,
        previewEnabled = false,
        GetSurfaceMetrics = function()
            return { minContentWidth = 650, naturalContentWidth = 1000,
                minContentHeight = 490, naturalContentHeight = 630 }
        end,
        scope = { mode = "realms", allTitle = "所有服务器" },
        settings = {
            title = "物品总览",
            description = "Vault 物品悬停与缓存设置。",
            CreateSettingsPanel = function(parent, context) return Page:CreateSettingsPanel(parent, context) end,
        },
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not registered then return nil, err end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "yva", brokerName = "YiboVault", pageID = PAGE_ID,
        text = "[Yibo] 物品总览", icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon-v2",
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
