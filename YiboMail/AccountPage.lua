local Addon = _G.YiboMail
local Core, Page = _G.YiboCore, {}
Addon.AccountPage = Page
local Theme = Core.UITheme
local fields = {
    { id = "character", title = "角色", weight = 2 }, { id = "count", title = "邮件", weight = 1 },
    { id = "attachments", title = "附件数量", weight = 1 }, { id = "money", title = "可收金币", weight = 1 },
    { id = "expires", title = "最近到期", weight = 1 }, { id = "status", title = "扫描状态", weight = 2 },
    { id = "backlog", title = "待核实", weight = 1 }, { id = "observed", title = "扫描时间", weight = 1.5 },
}
local statusNames = { known = "完整", ["known-empty"] = "空邮箱", partial = "部分可见", stale = "历史快照", error = "读取失败", ["not-yet-scanned"] = "未扫描" }
local function Escape(text) return tostring(text or ""):gsub("|", "||") end
local function Summary(character)
    local snapshot = Addon.db.byCharacter[character.id]
    local state = Addon.Items:GetState(character.id)
    local quantity, money, expiry, backlog = 0, 0, nil, 0
    for _, mail in pairs(snapshot and snapshot.records or {}) do if mail.state == "unverified" then backlog = backlog + 1 end end
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        for _, item in ipairs(mail.attachments) do quantity = quantity + item.quantity end
        if mail.cod == 0 then money = money + mail.money end
        expiry = math.min(expiry or math.huge, mail.expiresAtEstimate)
    end
    local now = Addon:Now()
    return { character = Escape(character.name) .. " · " .. Escape(character.realm),
        count = state.currentCount ~= nil and state.totalCount ~= nil and (state.currentCount .. "/" .. state.totalCount) or "—",
        attachments = state.currentCount ~= nil and tostring(quantity) or "—", money = state.currentCount ~= nil and string.format("%.2f 金", money / 10000) or "—",
        expires = expiry and string.format("%.1f 天", math.max(0, expiry - now) / 86400) or "—",
        backlog = tostring(backlog), observed = state.observedAt and date("%m-%d %H:%M", state.observedAt) or "—",
        status = (statusNames[state.status] or state.status) .. (state.status == "stale" and state.lastScanStatus and (" · " .. (statusNames[state.lastScanStatus] or state.lastScanStatus)) or "")
            .. (state.unscannedCount and state.unscannedCount > 0 and (" · 隐藏 " .. state.unscannedCount) or "") }, snapshot
end
function Page:GetSummary(character) return Summary(character) end
function Page:CreateSummary(parent)
    parent.mailRows = {}
    parent.mailScroll = Theme:CreateScrollFrame(parent)
    parent.mailScroll:SetPoint("TOPLEFT", 8, -8); parent.mailScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    parent.mailContent = CreateFrame("Frame", nil, parent.mailScroll)
    parent.mailContent:SetSize(1, 1); parent.mailScroll:SetScrollChild(parent.mailContent)
end
function Page:RefreshSummary(parent, context)
    local content, used, top = parent.mailContent, 0, 0
    local width = math.max(1, parent:GetWidth() - 30)
    local columns, weight = {}, 0
    for _, field in ipairs(fields) do if context:GetFieldVisible(field.id) then columns[#columns + 1] = field; weight = weight + field.weight end end
    local function Row(values, characterID, header, detail)
        used = used + 1
        local row = parent.mailRows[used]
        if not row then
            row = CreateFrame("Button", nil, content); row.cells = {}; row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            parent.mailRows[used] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -top); row:SetSize(width, detail and 44 or 28)
        local color = header and Theme.Colors.toolbar or Theme:GetDataRowColor(used)
        row.background:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        local left = 0
        local rendered = detail and { { id = "detail", weight = 1 } } or columns
        local total = detail and 1 or math.max(1, weight)
        for index, field in ipairs(rendered) do
            local cell = row.cells[index] or Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "LEFT"); row.cells[index] = cell
            local cellWidth = width * field.weight / total
            cell:ClearAllPoints(); cell:SetPoint("LEFT", left + 6, 0); cell:SetWidth(math.max(1, cellWidth - 12)); cell:SetHeight(detail and 42 or 24)
            cell:SetText(values[field.id] or ""); cell:Show(); left = left + cellWidth
        end
        for index = #rendered + 1, #row.cells do row.cells[index]:Hide() end
        row:SetScript("OnClick", characterID and not context.preview and function()
            parent.mailExpanded = parent.mailExpanded ~= characterID and characterID or nil
            Page:RefreshSummary(parent, context)
        end or nil)
        row:Show(); top = top + row:GetHeight() + 1
    end
    local titles = {}; for _, field in ipairs(fields) do titles[field.id] = field.title end; Row(titles, nil, true)
    for _, character in ipairs(context.characters or {}) do
        local values, snapshot = Summary(character); Row(values, character.id)
        if not context.preview and parent.mailExpanded == character.id and snapshot then
            for _, key in ipairs(snapshot.visibleKeys) do
                local mail, attachmentText = snapshot.records[key], {}
                for _, item in ipairs(mail.attachments) do attachmentText[#attachmentText + 1] = (item.itemLink or Escape(item.name or ("物品 " .. item.itemID))) .. " ×" .. item.quantity end
                local extra = mail.cod > 0 and ("付款取信 " .. string.format("%.2f 金", mail.cod / 10000)) or table.concat(attachmentText, "，")
                if mail.money > 0 then extra = extra .. " · 金币 " .. string.format("%.2f", mail.money / 10000) end
                if extra == "" then extra = "无附件" end
                Row({ detail = "    " .. mail.inboxIndex .. ". " .. Escape(mail.sender) .. " · " .. Escape(mail.subject) .. "\n    " .. extra }, nil, false, true)
            end
            local backlog = {}
            for _, mail in pairs(snapshot.records) do if mail.state == "unverified" then backlog[#backlog + 1] = mail end end
            table.sort(backlog, function(a, b) return a.mailKey < b.mailKey end)
            for _, mail in ipairs(backlog) do
                Row({ detail = "    待核实 · " .. Escape(mail.sender) .. " · " .. Escape(mail.subject) .. "\n    最后可见 " .. date("%m-%d %H:%M", mail.observedAt) .. " · 附件槽 " .. #mail.attachments }, nil, false, true)
            end
        end
    end
    if #(context.characters or {}) == 0 then Row({ detail = "在邮箱打开后完成一次扫描，即可查看角色邮件快照。" }, nil, false, true) end
    for index = used + 1, #parent.mailRows do parent.mailRows[index]:Hide() end
    content:SetSize(width, math.max(1, top)); parent.mailScroll:SetContentHeight(top)
end
function Page:Create(parent)
    parent.mailPreview = CreateFrame("Frame", nil, parent); parent.mailPreview:SetAllPoints()
    self:CreateSummary(parent.mailPreview)
    Addon.CacheUI:Create(parent)
end
function Page:Refresh(parent, context)
    parent.mailPreview:SetShown(context.preview)
    parent.mailWorkspace:SetShown(not context.preview)
    if context.preview then self:RefreshSummary(parent.mailPreview, context) else Addon.CacheUI:Refresh(parent, context) end
end
function Page:Register()
    local registered, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = "mail-inbox", title = "邮件助手", fields = fields, defaultEnabled = true, previewEnabled = true,
        settings = Addon.FEATURES.settings and { CreateSettingsPanel = function(parent, host) return Addon.Settings:Render(parent, host) end } or nil,
        scope = { mode = "realms", allTitle = "所有服务器" },
        HasCharacterSnapshot = function(character) return Addon.db.byCharacter[character.id] ~= nil end,
        GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        SetPreviewFieldVisible = function(id, visible) Addon.db.settings.previewColumns[id] = not not visible end,
        GetSurfaceMetrics = function(context)
            return { minContentWidth = 640, naturalContentWidth = 1000, minContentHeight = context and context.preview and 120 or 520,
                naturalContentHeight = context and context.preview and (45 + #(context.characters or {}) * 29) or 640 }
        end,
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not registered then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "yma", brokerName = "YiboMail", pageID = "mail-inbox", text = "[Yibo] YiboMail - 邮件助手", icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon-v1" })
end
