local Addon = _G.YiboMail
local UI = {}; Addon.CacheUI = UI
local Theme, View, Model = _G.YiboCore.UITheme, Addon.ViewModel, Addon.CacheModel
local function Text(parent, size, color)
    local t = Theme:CreateText(parent, size or Theme.Font.body, color or Theme.Colors.text, "LEFT")
    t:SetWordWrap(false); return t
end
local function Place(control, x, y, width, height)
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y); control:SetSize(math.max(1, width), height)
end
local function Stamp(mail) return mail.observedAt and date("%m-%d %H:%M", mail.observedAt) or "—" end
local function Character(entry) return View:Escape(entry.character.name .. " · " .. entry.character.realm) end
function UI:Create(parent)
    local root = CreateFrame("Frame", nil, parent); root:SetAllPoints(); parent.mailWorkspace = root
    root.mode, root.page, root.rows, root.expanded = Addon.db.settings.cacheBrowserMode or "mail", 1, {}, {}
    root.options = { scope = "latest", search = "", sort = "character" }
    local function Refresh(reset)
        if reset then root.page = 1 end
        if root.context then UI:Refresh(parent, root.context) end
    end
    local function Button(label, callback)
        local b = Theme:CreateButton(root, 112, label, "secondary"); b:SetHeight(32); b:SetScript("OnClick", callback); return b
    end
    root.mail = Button("邮件列表", function() root.mode = "mail"; Addon.db.settings.cacheBrowserMode = root.mode; Refresh(true) end)
    root.items = Button("附件集中", function() root.mode = "items"; Addon.db.settings.cacheBrowserMode = root.mode; Refresh(true) end)
    root.search = Addon.MailUI:Input(root, 280, "搜索角色、发件人、主题、物品 / ID", 120)
    root.search:HookScript("OnTextChanged", function(control) root.options.search = control:GetText(); Refresh(true) end)
    root.character = Theme:CreateDropdown(root, 210, {})
    root.character:SetOnValueChanged(function(value)
        if value == "__prev" or value == "__next" then
            root.characterPage = (root.characterPage or 1) + (value == "__prev" and -1 or 1); Refresh(); return
        end
        root.options.character = value ~= "all" and value or nil; Refresh(true)
    end)
    root.scope = Theme:CreateDropdown(root, 150, {
        { value = "latest", label = "最新邮箱快照" }, { value = "unverified", label = "待核实缓存" } })
    root.scope:SetOnValueChanged(function(value) root.options.scope = value; Refresh(true) end)
    root.sort = Theme:CreateDropdown(root, 140, {
        { value = "character", label = "角色 / 邮件顺序" }, { value = "expiry", label = "估算临期优先" } })
    root.sort:SetOnValueChanged(function(value) root.options.sort = value; Refresh(true) end)
    root.summary = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.note = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.previous = Button("上一页", function() root.page = root.page - 1; Refresh() end)
    root.next = Button("下一页", function() root.page = root.page + 1; Refresh() end)
    root.pages = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.empty = Text(root, Theme.Font.body, Theme.Colors.muted)
    root:SetScript("OnHide", function() root.character.menu:Hide(); root.scope.menu:Hide(); root.sort.menu:Hide(); root.search:ClearFocus() end)
end
function UI:Refresh(parent, context)
    local root = parent.mailWorkspace; root.context = context
    local width, height = math.max(1, parent:GetWidth() - 16), math.max(260, parent:GetHeight())
    Place(root.mail, 8, 8, 112, 32); Place(root.items, 128, 8, 112, 32)
    Place(root.search, 254, 11, width - 254, 26)
    Place(root.character, 8, 48, width - 320, 30); Place(root.scope, width - 304, 48, 150, 30)
    Place(root.sort, width - 146, 48, 154, 30)
    root.mail:SetState(root.mode == "mail" and "selected" or "default")
    root.items:SetState(root.mode == "items" and "selected" or "default")
    local characters = { { value = "all", label = "全部角色（当前 Core 范围）" } }
    local valid, hidden, scanned = not root.options.character, 0, 0
    for _, c in ipairs(context.characters or {}) do
        characters[#characters + 1] = { value = c.id, label = c.name .. " · " .. c.realm }
        if c.id == root.options.character then valid = true end
    end
    if not valid then root.options.character, root.page = nil, 1 end
    local choices, totalPages = { characters[1] }, math.max(1, math.ceil((#characters - 1) / 8))
    root.characterPage = math.max(1, math.min(root.characterPage or 1, totalPages))
    for index = (root.characterPage - 1) * 8 + 2, math.min(#characters, root.characterPage * 8 + 1) do
        local choice = characters[index]
        local c = context.characters[index - 1]
        local summary = Addon.AccountPage:GetSummary(c)
        choices[#choices + 1] = { value = choice.value, label = choice.label .. " · " .. summary.count }
    end
    if root.characterPage > 1 then choices[#choices + 1] = { value = "__prev", label = "上一页角色" } end
    if root.characterPage < totalPages then choices[#choices + 1] = { value = "__next", label = "下一页角色" } end
    root.character:SetOptions(choices); root.character:SetValue(root.options.character or "all")
    if root.options.character then
        for _, choice in ipairs(characters) do if choice.value == root.options.character then root.character:SetText(choice.label); break end end
    end
    root.scope:SetValue(root.options.scope); root.sort:SetValue(root.options.sort)
    local entries = Model:GetMails(context, root.options)
    local groups = root.mode == "items" and Model:GetGroups(entries, root.options.sort, root.options.search) or nil
    local quantity, money, cod = 0, 0, 0
    for _, entry in ipairs(entries) do
        for _, item in ipairs(entry.mail.attachments or {}) do quantity = quantity + (item.quantity or 0) end
        if (entry.mail.cod or 0) == 0 then money = money + (entry.mail.money or 0) else cod = cod + 1 end
    end
    if groups then quantity = 0; for _, group in ipairs(groups) do quantity = quantity + group.quantity end end
    for _, c in ipairs(context.characters or {}) do
        if not root.options.character or c.id == root.options.character then
            local state = Addon.Items:GetState(c.id)
            if state.observedAt then scanned = scanned + 1 end
            hidden = hidden + (state.unscannedCount or 0)
        end
    end
    Place(root.summary, 8, 86, width, 22)
    root.summary:SetText((root.options.scope == "latest" and "最新快照" or "待核实缓存") .. " · 筛选结果 " .. #entries .. " 封 · 附件 " .. quantity .. " 件 · 金币 " .. View:Money(money) .. " · COD " .. cod .. " 封")
    Place(root.note, 8, 110, width, 20)
    root.note:SetText(root.options.scope == "unverified" and "待核实记录是曾经可见的邮件，当前是否仍在邮箱需重新扫描确认。"
        or ("已扫描 " .. scanned .. " 个角色 · 隐藏 " .. hidden .. " 封 · 数量与到期时间基于各角色最后一次扫描。"))
    if root.options.character and root.options.scope == "latest" then
        for _, c in ipairs(context.characters or {}) do if c.id == root.options.character then
            local summary = Addon.AccountPage:GetSummary(c)
            root.note:SetText("邮箱 " .. summary.count .. " · " .. summary.status .. " · 扫描 " .. summary.observed .. " · 到期时间为估算")
            break
        end end
    end
    Theme:BindTooltip(root.note, "缓存范围", { "从未可见的隐藏邮件只有数量；曾经扫描过的邮件保留缓存。", "待核实缓存独立浏览，不计入最新快照附件数量。", "在游戏邮箱打开后扫描可更新缓存。" })
    local data = {}
    local function Add(row) data[#data + 1] = row end
    if root.mode == "mail" then
        for _, entry in ipairs(entries) do
            local mail, id = entry.mail, "mail:" .. entry.id
            local summary = Addon.AccountPage:GetSummary(entry.character)
            Add({ id = id, icon = mail.attachments[1] and mail.attachments[1].texture,
                title = (root.expanded[id] and "− " or "+ ") .. Character(entry) .. " · " .. View:Escape(mail.sender) .. " · " .. View:Escape(mail.subject),
                detail = Model:MailDetail(entry) .. " · 扫描 " .. Stamp(mail) .. " · " .. summary.status,
                tooltip = { Character(entry), "邮箱 " .. summary.count .. " · " .. summary.status, "扫描时间 " .. summary.observed, Model:MailDetail(entry) } })
            if root.expanded[id] then
                for _, item in ipairs(mail.attachments or {}) do
                    Add({ icon = item.texture, item = item, title = "    " .. View:Escape(item.name or ("物品 " .. tostring(item.itemID))) .. " ×" .. (item.quantity or 0),
                        detail = "    邮件序号 " .. (mail.inboxIndex or "—") .. " · 附件槽 " .. (item.attachmentIndex or "—") .. " · ID " .. tostring(item.itemID) })
                end
                if #mail.attachments == 0 then Add({ title = "    无物品附件", detail = Model:MailDetail(entry) }) end
            end
        end
    else
        for _, group in ipairs(groups or {}) do
            local id, count = "item:" .. tostring(group.id), 0
            for _ in pairs(group.characters) do count = count + 1 end
            Add({ id = id, icon = group.item.texture, item = group.item,
                title = (root.expanded[id] and "− " or "+ ") .. View:Escape(group.item.name or ("物品 " .. tostring(group.item.itemID))) .. " ×" .. group.quantity,
                detail = count .. " 个角色 · " .. #group.sources .. " 个附件来源 · 最近 " .. View:Expiry(group) .. " · ID " .. tostring(group.item.itemID) })
            if root.expanded[id] then
                for _, source in ipairs(group.sources) do
                    local entry, item = source.entry, source.item
                    local summary = Addon.AccountPage:GetSummary(entry.character)
                    Add({ icon = item.texture, item = item,
                        title = "    " .. Character(entry) .. " · " .. View:Escape(entry.mail.sender) .. " · " .. View:Escape(entry.mail.subject) .. " ×" .. (item.quantity or 0),
                        detail = "    邮件 " .. (entry.mail.inboxIndex or "—") .. " / 槽 " .. (item.attachmentIndex or "—") .. " · 扫描 " .. Stamp(entry.mail) .. ((entry.mail.cod or 0) > 0 and (" · COD " .. View:Money(entry.mail.cod)) or ""),
                        tooltip = { "物品来源", Character(entry), "邮箱 " .. summary.count .. " · " .. summary.status, Model:MailDetail(entry) } })
                end
            end
        end
    end
    local size = math.max(1, math.floor((height - 184) / 62))
    local pages = math.max(1, math.ceil(#data / size)); root.page = math.max(1, math.min(root.page, pages))
    local first, used = (root.page - 1) * size + 1, 0
    for index = first, math.min(#data, first + size - 1) do
        used = used + 1; local row, value = root.rows[used], data[index]
        if not row then
            row = CreateFrame("Button", nil, root)
            row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("LEFT", 10, 0); row.icon:SetSize(40, 40)
            row.title = Text(row); row.detail = Text(row, Theme.Font.assist, Theme.Colors.muted)
            root.rows[used] = row
        end
        Place(row, 8, 140 + (used - 1) * 62, width, 60)
        row.background:SetColorTexture(unpack(Theme:GetDataRowColor(used)))
        row.icon:SetTexture(value.icon or "Interface\\Icons\\INV_Letter_15")
        Place(row.title, 62, 8, width - 74, 22); Place(row.detail, 62, 32, width - 74, 20)
        row.title:SetText(value.title); row.detail:SetText(value.detail or "")
        row:SetScript("OnClick", value.id and function() root.expanded[value.id] = not root.expanded[value.id]; UI:Refresh(parent, context) end or nil)
        row:SetScript("OnEnter", function()
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if value.item and value.item.itemLink then GameTooltip:SetHyperlink(value.item.itemLink) else GameTooltip:AddLine(value.title, 1, 1, 1, true) end
            for _, line in ipairs(value.tooltip or { value.detail }) do if line then GameTooltip:AddLine(line, .7, .8, .8, true) end end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end); row:Show()
    end
    for index = used + 1, #root.rows do root.rows[index]:Hide() end
    Place(root.empty, 20, 160, width - 24, 28); root.empty:SetShown(#data == 0)
    root.empty:SetText(root.options.search ~= "" and "没有匹配的缓存，请调整搜索或角色范围。"
        or (root.options.scope == "unverified" and "此范围内没有待核实缓存。"
        or (root.mode == "items" and "此范围内没有物品附件缓存。"
        or (scanned > 0 and "此范围内的最新快照没有邮件。" or "请打开对应角色邮箱完成首次扫描。"))))
    Place(root.previous, 8, height - 40, 90, 32); Place(root.next, 106, height - 40, 90, 32)
    root.previous:SetEnabled(root.page > 1); root.previous:SetState(root.page > 1 and "default" or "disabled")
    root.next:SetEnabled(root.page < pages); root.next:SetState(root.page < pages and "default" or "disabled")
    Place(root.pages, 210, height - 36, width - 212, 24)
    root.pages:SetText(root.page .. " / " .. pages .. " 页 · " .. #data .. " 行（含展开来源）")
end
