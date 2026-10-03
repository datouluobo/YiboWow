local Addon = _G.YiboMail
local Settings = Addon.Settings
local Theme, Rules = _G.YiboCore.UITheme, Addon.Rules
local function Trim(v) return tostring(v or ""):match("^%s*(.-)%s*$") end
local function Confirm(text, callback)
    StaticPopupDialogs.YIBOMAIL_DATA = { text = "%s", button1 = "确认", button2 = "取消", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, data) data() end }
    StaticPopup_Show("YIBOMAIL_DATA", text, nil, callback)
end
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local function Place(control, x, y, width, height)
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y)
    if width then control:SetWidth(math.max(1, width)) end
    if height then control:SetHeight(height) end
end
local function Font(control, size)
    local path, _, flags = control:GetFont(); control:SetFont(path, size, flags)
end
local function PageOptions(entries, page, size, mapper)
    page = math.max(1, math.min(page or 1, math.max(1, math.ceil(#entries / size))))
    local result = {}
    for index = (page - 1) * size + 1, math.min(#entries, page * size) do result[#result + 1] = mapper(entries[index]) end
    if page > 1 then result[#result + 1] = { value = "__prev", label = "上一页" } end
    if page * size < #entries then result[#result + 1] = { value = "__next", label = "下一页" } end
    return result, page
end
function Settings:Render(parent, host)
    local p = parent.yiboMailSettingsPanel
    if not p then
        p = CreateFrame("Frame", nil, parent); parent.yiboMailSettingsPanel = p
        p.tab, p.rulePage, p.method, p.filterState, p.sortMode = "send", 1, "id", "all", "name"
        p.known, p.rows, p.drops, p.inputs, p.draft = {}, {}, {}, {}, { enabled = true, recipient = "" }
        p.incoming = Addon:GetInboxPreferences()
        local function Refresh(message, resize)
            if message then p.message = message end
            if resize and host.refreshPage then host.refreshPage() else Settings:Render(parent, host) end
        end
        p.refresh = Refresh
        local function Text(owner, value, size, color)
            local t = host.createText(owner, size or Theme.Font.assist, color or Theme.Colors.text, "LEFT")
            t:SetText(value or ""); t:SetHeight(20); t:SetWordWrap(false); return t
        end
        local function Button(owner, width, label, callback, kind)
            local b = host.createButton(owner, width, label, kind or "secondary"); b:SetHeight(34); b:SetScript("OnClick", callback)
            b.textWidth = Theme:MeasureText(16, label)
            b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 12, 0); b.label:SetPoint("RIGHT", -12, 0); b.label:SetWordWrap(false)
            local nativeSetEnabled = b.SetEnabled
            b.SetEnabled = function(control, enabled)
                nativeSetEnabled(control, not not enabled)
                control:SetState(enabled and (kind == "primary" and "selected" or "default") or "disabled")
            end
            if kind == "primary" then b:SetState("selected") end
            return b
        end
        local function Input(owner, hint, limit)
            local b = CreateFrame("EditBox", nil, owner, "BackdropTemplate"); b:SetBackdrop(BACKDROP)
            b:SetBackdropColor(unpack(Theme.Colors.bg)); b:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
            b:SetFontObject(GameFontHighlight); local path, _, flags = b:GetFont(); b:SetFont(path, 14, flags)
            b:SetTextInsets(12, 12, 0, 0); b:SetAutoFocus(false); b:SetMaxLetters(limit or 120); b:SetHeight(34)
            b.hint = Text(b, hint, 14, Theme.Colors.muted); b.hint:SetPoint("LEFT", 12, 0); b.hint:SetPoint("RIGHT", -12, 0)
            b:SetScript("OnTextChanged", function(control) control.hint:SetShown(control:GetText() == "") end)
            b:SetScript("OnEscapePressed", function(control) control:ClearFocus() end)
            b:SetScript("OnEditFocusGained", function(control) control:SetBackdropBorderColor(unpack(Theme.Colors.accent)) end)
            b:SetScript("OnEditFocusLost", function(control) control:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft)) end)
            host.bindTooltip(b, hint, { hint }); p.inputs[#p.inputs + 1] = b; return b
        end
        local function Drop(owner)
            local d = Theme:CreateDropdown(owner, 200, {}); d:SetHeight(34); Font(d.label, 14); d.label:SetWordWrap(false)
            local setOptions = d.SetOptions
            d.SetOptions = function(control, options)
                setOptions(control, options)
                for index, option in ipairs(control.options) do
                    local b = control.menu.buttons[index]; b:ClearAllPoints()
                    local y = -4 - (index - 1) * 36
                    b:SetPoint("TOPLEFT", 4, y); b:SetPoint("TOPRIGHT", -4, y); b:SetHeight(34)
                    b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 12, 0); b.label:SetPoint("RIGHT", -12, 0)
                    Font(b.label, 14); b.label:SetWordWrap(false)
                    host.bindTooltip(b, option.label or tostring(option.value), {})
                end
                control.menu:SetHeight(math.max(1, #control.options) * 36 + 6)
            end
            p.drops[#p.drops + 1] = d; return d
        end
        local function Check(owner, label, callback)
            local b = Theme:CreateCheckbox(owner, label); b:SetHeight(24); b.box:SetSize(20, 20); b.mark:SetSize(20, 20)
            b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 28, 0); b.label:SetPoint("RIGHT", 0, 0); Font(b.label, 14)
            b:SetScript("OnClick", function(control) control:SetChecked(not control:GetChecked()); if callback then callback(control:GetChecked()) end end); return b
        end
        local function Section(title) return host.createSection(p, title, 500, 580) end
        local function NewRule()
            p.draft, p.editRule, p.editing, p.contactMode = { enabled = true, recipient = "" }, nil, true, nil
            p.query:SetText(""); p.recipient:SetText(""); p.candidates, p.itemPage = {}, 1; Refresh("请选择物品和收件人。", true)
        end
        local function SelectItem(id, fallback)
            local item = Rules:GetItem(id, fallback or p.known[tonumber(id)])
            if not item then Refresh("请输入正整数物品 ID。"); return end
            p.draft.itemID, p.draft.item = item.itemID, item
            if not item.resolved and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item.itemID) end
            Refresh(item.resolved and ("已选定：" .. item.name) or "等待物品信息加载。")
        end
        local function EditRule(id)
            local rule = Addon.db.rules[id]; if not rule then return end
            p.draft, p.editRule, p.editing, p.contactMode = { enabled = rule.enabled ~= false, recipient = rule.recipient, itemID = id, item = Rules:GetItem(id, rule) }, id, true, nil
            p.recipient:SetText(rule.recipient); p.query:SetText(tostring(id)); p.method, p.candidates = "id", {}; Refresh("正在编辑物品 " .. id .. " 的规则。", true)
        end
        p.tabs = {}
        for index, entry in ipairs({ { "send", "发件", 112 }, { "inbox", "收件", 112 }, { "cache", "缓存管理", 144 } }) do
            local id = entry[1]
            p.tabs[index] = Button(p, entry[3], entry[2], function()
                for _, d in ipairs(p.drops) do d.menu:Hide() end
                p.tab, p.message = id, nil; Refresh(nil, true)
            end)
        end
        p.list, p.editor = Section("发件规则"), Section("新建发件规则")
        p.search = Input(p.list, "搜索物品名称 / ID / 收件人")
        p.search:HookScript("OnTextChanged", function() p.rulePage = 1; Refresh() end)
        p.new = Button(p.list, 128, "新建规则", NewRule, "primary")
        p.clear = Button(p.list, 96, "清除筛选", function() p.filterRecipient, p.filterState, p.rulePage = nil, "all", 1; p.search:SetText(""); Refresh() end)
        p.recipientFilter, p.stateFilter, p.sort = Drop(p.list), Drop(p.list), Drop(p.list)
        p.recipientFilter:SetOnValueChanged(function(v)
            if v == "__prev" or v == "__next" then p.filterPage = (p.filterPage or 1) + (v == "__next" and 1 or -1)
            else p.filterRecipient, p.rulePage = v ~= "__all" and v or nil, 1 end; Refresh()
        end)
        p.stateFilter:SetOptions({ { value = "all", label = "全部状态" }, { value = "enabled", label = "仅启用" }, { value = "disabled", label = "仅停用" } })
        p.stateFilter:SetOnValueChanged(function(v) p.filterState, p.rulePage = v, 1; Refresh() end)
        local sorting = {}; for _, entry in ipairs({ { "name", "物品名称" }, { "id", "物品 ID" }, { "recipient", "收件人" } }) do
            sorting[#sorting + 1] = { value = entry[1], label = entry[2] .. " ↑" }; sorting[#sorting + 1] = { value = entry[1] .. ":desc", label = entry[2] .. " ↓" }
        end
        p.sort:SetOptions(sorting); p.sort:SetOnValueChanged(function(v) p.sortMode, p.rulePage = v, 1; Refresh() end)
        p.header = CreateFrame("Frame", nil, p.list, "BackdropTemplate"); p.header:SetBackdrop(BACKDROP); p.header:SetBackdropColor(unpack(Theme.Colors.toolbar))
        p.headings = {}; for _, label in ipairs({ "物品 / ID", "收件人", "状态", "操作" }) do p.headings[#p.headings + 1] = Text(p.header, label, 12, Theme.Colors.muted) end
        p.empty = Text(p.list, "", 14, Theme.Colors.muted); p.empty:SetWordWrap(true)
        p.previous = Button(p.list, 72, "上一页", function() p.rulePage = p.rulePage - 1; Refresh() end)
        p.next = Button(p.list, 72, "下一页", function() p.rulePage = p.rulePage + 1; Refresh() end)
        p.pageLabel, p.range = Text(p.list, ""), Text(p.list, "", 14, Theme.Colors.muted)
        p.pageInput = Input(p.list, "页码", 5)
        p.jump = Button(p.list, 72, "跳转", function()
            local page = tonumber(p.pageInput:GetText())
            if not page or page % 1 ~= 0 or page < 1 or page > (p.totalPages or 1) then Refresh("请输入 1–" .. (p.totalPages or 1) .. " 的页码。"); return end
            p.rulePage = page; p.pageInput:ClearFocus(); Refresh()
        end)
        p.createRow = function(index)
            local row = CreateFrame("Frame", nil, p.list, "BackdropTemplate"); row:SetBackdrop(BACKDROP); row:EnableMouse(true)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(28, 28)
            row.name, row.id, row.address = Text(row, ""), Text(row, "", 12, Theme.Colors.muted), Text(row, "")
            row.toggle = Check(row, "启用"); Font(row.toggle.label, 12)
            row.edit = Button(row, 88, "编辑")
            p.rows[index] = row; return row
        end
        p.itemLabel = Text(p.editor, "物品 *", 14, Theme.Colors.muted)
        p.methods = {}; for index, entry in ipairs({ { "id", "物品 ID" }, { "name", "名字" }, { "bag", "背包" }, { "drag", "拖放" } }) do
            local method = entry[1]
            p.methods[index] = Button(p.editor, 72, entry[2], function() p.method, p.itemPage = method, 1; p.candidates = {}; p.query:SetText(""); Refresh() end)
        end
        p.query = Input(p.editor, "物品 ID 或名字", 100)
        p.lookup = Button(p.editor, 88, "查找", function()
            p.candidates, p.itemPage = {}, 1
            local q = Trim(p.query:GetText())
            if p.method == "id" then SelectItem(tonumber(q)); return end
            if q == "" then Refresh("请输入物品名字。"); return end
            for _, item in pairs(p.known) do if string.lower(item.name):find(string.lower(q), 1, true) then p.candidates[#p.candidates + 1] = item end end
            table.sort(p.candidates, function(a, b) if a.name ~= b.name then return a.name < b.name end; return a.itemID < b.itemID end)
            Refresh(#p.candidates > 0 and "请选择明确的物品候选。" or "没有已知物品匹配。可填写 ID、从背包选择或拖入物品。")
        end)
        p.query:SetScript("OnEnterPressed", function() p.lookup:Click() end)
        p.itemDrop = Button(p.editor, 40, "+", function()
            local kind, id = GetCursorInfo(); if kind == "item" then SelectItem(id); ClearCursor() else Refresh("将背包物品拖到图标区，或选择其它添加方式。") end
        end)
        p.itemDrop:SetHeight(40); p.itemDrop:RegisterForDrag("LeftButton")
        p.itemDrop:SetScript("OnReceiveDrag", function() local kind, id = GetCursorInfo(); if kind == "item" then SelectItem(id); ClearCursor() end end)
        p.itemIcon = p.itemDrop:CreateTexture(nil, "ARTWORK"); p.itemIcon:SetPoint("TOPLEFT", 2, -2); p.itemIcon:SetPoint("BOTTOMRIGHT", -2, 2)
        p.itemName, p.itemInfo = Text(p.editor, "", 16), Text(p.editor, "", 12, Theme.Colors.muted)
        p.items = Drop(p.editor); p.items:SetOnValueChanged(function(v)
            if v == "__next" or v == "__prev" then p.itemPage = (p.itemPage or 1) + (v == "__next" and 1 or -1); Refresh() else SelectItem(v) end
        end)
        p.recipientLabel = Text(p.editor, "收件人 *", 14, Theme.Colors.muted)
        p.recipients = Drop(p.editor); p.recipients:SetOnValueChanged(function(v)
            if v == "__next" or v == "__prev" then p.recipientPage = (p.recipientPage or 1) + (v == "__next" and 1 or -1); Refresh()
            else p.recipient:SetText(v); Refresh() end
        end)
        p.recipient = Input(p.editor, "角色名或角色名-服务器", 100)
        p.recipient:HookScript("OnTextChanged", function(control) p.draft.recipient = control:GetText(); Refresh() end)
        p.recipientSearch = Input(p.editor, "搜索角色 / 规则收件人", 80)
        p.recipientSearch:HookScript("OnTextChanged", function() p.recipientPage = 1; Refresh() end)
        p.findRecipient = Button(p.editor, 64, "搜索", function() p.searchRecipient = not p.searchRecipient; Refresh() end)
        p.addressInfo = Text(p.editor, "", 12, Theme.Colors.muted)
        p.enabled = Check(p.editor, "启用规则", function(value) p.draft.enabled = value end)
        p.required = Text(p.editor, "必填：物品、收件人", 12, Theme.Colors.muted)
        p.save = Button(p.editor, 128, "保存规则", function()
            local ok, value = Rules:Save(p.draft.itemID, p.draft.recipient, p.draft.enabled, p.editRule)
            if not ok then Refresh(value); return end
            p.editRule, p.draft.recipient = value, Addon.db.rules[value].recipient; p.recipient:SetText(p.draft.recipient)
            p.editing = false; p.locate = value; Refresh("规则已保存。", true); Addon.NativeUI:Refresh()
        end, "primary")
        p.cancel = Button(p.editor, 112, "取消编辑", function()
            p.editing, p.contactMode, p.editRule = false, nil, nil
            p.draft = { enabled = true, recipient = "" }; p.recipient:SetText(""); p.query:SetText(""); Refresh("已取消本次编辑。", true)
        end)
        p.contactButton = Button(p.editor, 100, "联系人", function() p.contactMode = true; Refresh(nil, true) end)
        p.contacts = Section("常用联系人")
        p.contactChoose = Drop(p.contacts); p.contactChoose:SetOnValueChanged(function(v)
            if v == "__next" or v == "__prev" then p.contactPage = (p.contactPage or 1) + (v == "__next" and 1 or -1)
            else
                p.editContact = v ~= "__new" and v or nil
                local found; for _, entry in ipairs(Addon.db.contacts) do if entry.address == v then found = entry end end
                p.contactAddress:SetText(found and found.address or ""); p.contactName:SetText(found and found.label or "")
            end; Refresh()
        end)
        p.contactAddressLabel, p.contactNameLabel = Text(p.contacts, "角色地址", 14, Theme.Colors.muted), Text(p.contacts, "显示名称（选填）", 14, Theme.Colors.muted)
        p.contactAddress, p.contactName = Input(p.contacts, "角色名或角色名-服务器"), Input(p.contacts, "默认使用完整角色地址")
        p.contactHelp = Text(p.contacts, "未填服务器默认同服；账号角色自动可选。", 12, Theme.Colors.muted)
        p.contactSave = Button(p.contacts, 128, "保存联系人", function()
            local ok, err = Addon.ViewModel:SaveContact(p.contactAddress:GetText(), p.contactName:GetText(), p.editContact)
            if ok then p.editContact = Rules:NormalizeAddress(p.contactAddress:GetText()) end
            Refresh(ok and "联系人已保存。" or err); Addon.NativeUI:Refresh()
        end, "primary")
        p.contactBack = Button(p.contacts, 112, "返回规则", function() p.contactMode = nil; Refresh(nil, true) end)
        p.contactDeleteHint = Text(p.contacts, "删除所选联系人位于「缓存管理」末尾。", 12, Theme.Colors.muted)
        p.preferences, p.collect = Section("默认视图"), Section("批量收取偏好")
        p.initialLabel = Text(p.preferences, "初始展示", 14, Theme.Colors.muted)
        p.initialMail = Button(p.preferences, 112, "邮件", function() p.incoming.mode = "mail"; Refresh() end)
        p.initialItems = Button(p.preferences, 112, "附件", function() p.incoming.mode = "items"; Refresh() end)
        p.orderLabel, p.kindLabel = Text(p.preferences, "默认排序", 14, Theme.Colors.muted), Text(p.preferences, "默认邮件类别", 14, Theme.Colors.muted)
        p.order, p.kind = Drop(p.preferences), Drop(p.preferences)
        p.order:SetOptions({ { value = "expiry", label = "临期优先" }, { value = "inbox", label = "邮箱顺序" } })
        p.kind:SetOptions({ { value = "all", label = "全部邮件" }, { value = "items", label = "含附件" }, { value = "money", label = "含金币" }, { value = "cod", label = "付款取信" }, { value = "returned", label = "退回邮件" }, { value = "urgent", label = "三天内到期" } })
        p.order:SetOnValueChanged(function(v) p.incoming.sort = v end); p.kind:SetOnValueChanged(function(v) p.incoming.kind = v end)
        p.remember = Check(p.preferences, "再次打开邮箱时保留搜索与筛选", function(v) p.incoming.rememberFilters = v end)
        p.rangeLabel = Text(p.collect, "“全选可收项目”的默认范围", 14, Theme.Colors.muted)
        p.includeItems = Check(p.collect, "物品附件", function(v) p.incoming.selectItems = v end)
        p.includeMoney = Check(p.collect, "邮件金币", function(v) p.incoming.selectMoney = v end)
        p.collectHelp = Text(p.collect, "选择结果仍可在原生邮箱中逐项调整。", 14, Theme.Colors.muted)
        p.summary = Check(p.collect, "收取完成后显示本批结果摘要", function(v) p.incoming.showSummary = v end)
        p.inboxSave = Button(p.collect, 144, "保存收件设置", function()
            if not p.incoming.selectItems and not p.incoming.selectMoney then Refresh("默认全选范围至少选择物品附件或金币。"); return end
            Addon.db.settings.inbox = Addon.Copy(p.incoming); Addon.NativeUI:ApplyInboxPreferences(true); Refresh("收件偏好已保存，下次打开邮箱使用默认视图。")
        end, "primary")
        p.inboxReset = Button(p.collect, 128, "恢复默认", function() p.incoming = Addon.Copy(Addon.INBOX_DEFAULTS); Refresh("已恢复默认草稿，点击保存后生效。") end)
        p.processing, p.flow = Section("收取处理方式"), Section("使用流程")
        p.processingLines = {}; for _, entry in ipairs({ { "操作角色", "只操作当前角色的可见邮件。" }, { "付款取信（COD）", "通过原生信件确认付款。" },
            { "身份不明确的重复邮件", "等待核实，暂不加入收取批次。" }, { "邮箱关闭或内容发生变化", "暂停队列，保留未执行项目。" }, { "背包不足或操作失败", "显示原因，核实后重新预览。" } }) do
            p.processingLines[#p.processingLines + 1] = { Text(p.processing, entry[1]), Text(p.processing, entry[2], 12, Theme.Colors.muted) }
        end
        p.flowLines = { Text(p.flow, "选择项目 → 预览批次 → 确认收取"), Text(p.flow, "暂停后：核实结果 → 重新预览剩余项目", 12, Theme.Colors.muted), Text(p.flow, "邮件历史及缓存期限在「缓存管理」页。", 12, Theme.Colors.muted) }
        p.cache = Section("数据与缓存")
        p.historyLabel, p.unverifiedLabel = Text(p.cache, "已确认历史保留（天）"), Text(p.cache, "待核实记录保留（天）")
        p.historyDays, p.unverifiedDays = Input(p.cache, "1–3650", 4), Input(p.cache, "1–3650", 4)
        p.historyDays:SetText(tostring(Addon.db.settings.historyDays)); p.unverifiedDays:SetText(tostring(Addon.db.settings.unverifiedDays))
        p.daysSave = Button(p.cache, 144, "保存保留期限", function()
            local a, b = tonumber(p.historyDays:GetText()), tonumber(p.unverifiedDays:GetText())
            if not a or not b or a % 1 ~= 0 or b % 1 ~= 0 or a < 1 or b < 1 or a > 3650 or b > 3650 then Refresh("天数应为 1–3650 的整数。"); return end
            Confirm("保存期限并清理超期本地记录？当前可见邮件保留。", function() Addon.db.settings.historyDays, Addon.db.settings.unverifiedDays = a, b; Addon:PruneHistory(); Refresh("保留期限已保存。") end)
        end)
        p.cacheStats = Text(p.cache, "", 14, Theme.Colors.muted); p.cacheStats:SetWordWrap(true)
        p.cacheHelp = Text(p.cache, "完整 100/100 稳定 60 秒清理待核实积压；角色缓存由 Core「角色与排序」管理。", 14, Theme.Colors.muted); p.cacheHelp:SetWordWrap(true)
        p.risk = Text(p.cache, "删除本地数据需确认，操作不可撤销。", 14, Theme.Colors.warning)
        p.ruleDelete = Button(p.cache, 176, "删除所选规则", function()
            local id = p.editRule; if not id or not Addon.db.rules[id] then return end
            Confirm("删除物品 " .. id .. " 的规则？", function() Addon.db.rules[id] = nil; p.editRule = nil; p.draft = { enabled = true, recipient = "" }; p.recipient:SetText(""); Refresh("规则已删除。"); Addon.NativeUI:Refresh() end)
        end, "danger")
        p.contactDelete = Button(p.cache, 176, "删除所选联系人", function()
            local address = p.editContact; if not address then return end
            Confirm("删除“" .. Addon.ViewModel:Escape(address) .. "”的收藏？规则收件地址保留。", function()
                for index = #Addon.db.contacts, 1, -1 do if Addon.db.contacts[index].address == address then table.remove(Addon.db.contacts, index) end end
                p.editContact = nil; p.contactAddress:SetText(""); p.contactName:SetText(""); Refresh("联系人已删除。"); Addon.NativeUI:Refresh()
            end)
        end, "danger")
        p.cleanup = Button(p.cache, 196, "清理过期历史记录", function()
            Confirm("删除超过保留期限的本地历史／待核实记录？当前可见邮件保留。", function() Addon:PruneHistory(); Refresh("超期本地记录已清理。") end)
        end, "danger")
        p.messageText = Text(p, "", 14, Theme.Colors.muted); p.messageText:SetWordWrap(true)
        p:SetScript("OnHide", function() for _, d in ipairs(p.drops) do d.menu:Hide() end; for _, box in ipairs(p.inputs) do box:ClearFocus() end end)
        local events = CreateFrame("Frame", nil, p); p.events = events; events:RegisterEvent("GET_ITEM_INFO_RECEIVED"); events:RegisterEvent("BAG_UPDATE_DELAYED")
        events:SetScript("OnEvent", function(_, event, itemID, success)
            if event == "GET_ITEM_INFO_RECEIVED" and itemID then
                Rules.failedItems[itemID] = success == false or nil
                if success == false and p.draft.itemID == itemID then p.message = "物品信息未找到，请核对 ID 或从背包选择。" end
            end
            if p:IsShown() and not p.scheduled then p.scheduled = true; C_Timer.After(0, function() p.scheduled = nil; if p:IsShown() then Refresh() end end) end
        end)
        Addon.Items.Events:Register(p, function()
            if p:IsShown() then Refresh() end
        end)
        p.editing = next(Addon.db.rules) == nil
        p.editRuleByID = EditRule
    end
    if p.refreshing then return p:GetHeight() end
    p.refreshing = true
    p:ClearAllPoints(); p:SetPoint("TOPLEFT", 0, 0); p:SetPoint("TOPRIGHT", 0, 0); p:Show()
    local width = math.max(1, parent:GetWidth())
    -- Budget in logical UI units: retain the list beside a complete editor
    -- even when Core's effective scale reduces the available content width.
    local wide = width >= 820
    local editorWidth = wide and 396 or width
    local listWidth = wide and width - editorWidth - 16 or width
    local available = tonumber(host.availableHeight) or 674
    local h = math.max(480, math.min(580, math.floor(available - 94)))
    local listHeight = h
    local function Section(frame, x, y, w, height, visible) Place(frame, x, y, w, height); frame:SetShown(visible) end
    local tabsX = 0; for index, b in ipairs(p.tabs) do Place(b, tabsX, 0, index == 3 and 144 or 112, 34); b:SetState(({ "send", "inbox", "cache" })[index] == p.tab and "selected" or "default"); tabsX = tabsX + b:GetWidth() + 12 end
    local send, inbox, cache = p.tab == "send", p.tab == "inbox", p.tab == "cache"
    Section(p.list, 0, 54, listWidth, listHeight, send and (wide or not p.editing and not p.contactMode))
    Section(p.editor, wide and listWidth + 16 or 0, 54, editorWidth, h, send and not p.contactMode and (wide or p.editing))
    Section(p.contacts, wide and listWidth + 16 or 0, 54, editorWidth, h, send and p.contactMode)
    p.known = Rules:GetKnownItems()
    local inner = listWidth - 32
    local compact = inner < 660
    local newWidth, clearWidth = math.max(128, p.new.textWidth + 28), math.max(96, p.clear.textWidth + 28)
    local searchWidth = compact and math.max(100, inner - newWidth - 28) or inner - newWidth - clearWidth - 20
    Place(p.search, 16, 56, searchWidth, 34); Place(p.new, compact and inner + 16 - newWidth or searchWidth + 28, 56, newWidth, 34)
    Place(p.clear, inner + 16 - clearWidth, compact and 146 or 56, clearWidth, 34)
    local filterWidth = compact and inner - 160 or inner - 316
    Place(p.recipientFilter, 16, 102, filterWidth, 34); Place(p.stateFilter, filterWidth + 28, 102, 148, 34)
    Place(p.sort, compact and 16 or inner - 128, compact and 146 or 102, compact and inner - clearWidth - 20 or 144, 34)
    local headerTop, rowsTop, rowHeight = compact and 192 or 152, compact and 192 or 180, compact and 76 or 42
    local footerHeight = compact and 94 or 50
    local capacity = math.max(1, math.floor((listHeight - footerHeight - rowsTop - 14) / rowHeight))
    if p.capacity and p.capacity ~= capacity then p.rulePage = math.floor(((p.rulePage - 1) * p.capacity) / capacity) + 1 end; p.capacity = capacity
    local itemWidth = math.floor((inner - 196) * 260 / 464); local addressWidth = inner - 196 - itemWidth
    Place(p.header, 16, headerTop, inner, 28); p.header:SetShown(not compact)
    for i, t in ipairs(p.headings) do Place(t, ({ 44, itemWidth, inner - 196, inner - 88 })[i], 7, ({ itemWidth - 48, addressWidth - 12, 100, 88 })[i], 18) end
    local ids, addresses, seen, total = {}, {}, {}, 0
    local search = string.lower(Trim(p.search:GetText()))
    for id, rule in pairs(Addon.db.rules) do
        total = total + 1; local address = Rules:NormalizeAddress(rule.recipient) or rule.recipient
        if not seen[address] then seen[address] = true; addresses[#addresses + 1] = address end
        local item = p.known[id] or Rules:GetItem(id, rule)
        local haystack = string.lower(item.name .. " " .. id .. " " .. address)
        if (search == "" or haystack:find(search, 1, true)) and (not p.filterRecipient or p.filterRecipient == address)
            and (p.filterState == "all" or p.filterState == "enabled" and rule.enabled ~= false or p.filterState == "disabled" and rule.enabled == false) then ids[#ids + 1] = id end
    end
    table.sort(addresses)
    local opts; opts, p.filterPage = PageOptions(addresses, p.filterPage, 6, function(address) return { value = address, label = Addon.ViewModel:Escape(address) } end)
    table.insert(opts, 1, { value = "__all", label = "全部收件人" }); p.recipientFilter:SetOptions(opts); p.recipientFilter:SetText(p.filterRecipient and Addon.ViewModel:Escape(p.filterRecipient) or "全部收件人")
    p.stateFilter:SetValue(p.filterState); p.sort:SetValue(p.sortMode)
    local descending = p.sortMode:find(":desc", 1, true) ~= nil; local sorting = p.sortMode:match("^([^:]+)")
    table.sort(ids, function(a, b)
        local va = sorting == "id" and a or sorting == "recipient" and Addon.db.rules[a].recipient or p.known[a].name
        local vb = sorting == "id" and b or sorting == "recipient" and Addon.db.rules[b].recipient or p.known[b].name
        if va == vb then return a < b end
        if descending then return va > vb end; return va < vb
    end)
    p.totalPages = math.max(1, math.ceil(#ids / capacity)); p.rulePage = math.max(1, math.min(p.rulePage, p.totalPages))
    if p.locate then
        local found; for index, id in ipairs(ids) do if id == p.locate then p.rulePage = math.ceil(index / capacity); found = true; break end end
        if not found then p.message = "规则已保存，当前筛选隐藏了该规则。" end; p.locate = nil
    end
    for index = 1, capacity do
        local id = ids[(p.rulePage - 1) * capacity + index]; local row = p.rows[index] or p.createRow(index); row:SetShown(id ~= nil)
        if id then
            local rule, item = Addon.db.rules[id], p.known[id]
            Place(row, 16, rowsTop + (index - 1) * rowHeight, inner, rowHeight)
            row:SetBackdropColor(unpack(p.editRule == id and Theme.Colors.selected or (index % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))); row:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
            row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", 8, 7); row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            Place(row.name, 44, 4, compact and inner - 144 or itemWidth - 56, 18); Place(row.id, 44, 23, compact and inner - 144 or itemWidth - 56, 16)
            Place(row.address, compact and 8 or itemWidth, compact and 48 or 13, compact and inner - 128 or addressWidth - 12, 20)
            Place(row.toggle, inner - 196, compact and 47 or 9, 100, 24); Place(row.edit, inner - 88, 4, 88, 34)
            if compact then Place(row.toggle, inner - 108, 46, 108, 24) end
            row.name:SetText(Addon.ViewModel:Escape(item.name)); row.id:SetText(tostring(id)); row.address:SetText(Addon.ViewModel:Escape(Rules:NormalizeAddress(rule.recipient) or rule.recipient))
            row.toggle.label:SetText(rule.enabled == false and "停用" or "启用"); row.toggle:SetChecked(rule.enabled ~= false)
            row.toggle:SetScript("OnClick", function() rule.enabled = rule.enabled == false; if p.editRule == id then p.draft.enabled = rule.enabled end; p.message = rule.enabled and "规则已启用。" or "规则已停用。"; p.refresh(); Addon.NativeUI:Refresh() end)
            row.edit:SetScript("OnClick", function() p.editRuleByID(id) end)
            host.bindTooltip(row, item.name, { "物品 ID：" .. id, "收件人：" .. Addon.ViewModel:Escape(rule.recipient) })
        end
    end
    for index = capacity + 1, #p.rows do p.rows[index]:Hide() end
    Place(p.empty, 16, rowsTop + 16, inner, 64); p.empty:SetShown(#ids == 0); p.empty:SetText(total == 0 and "尚无规则。点击新建，选择物品和收件人即可。" or "没有匹配规则，请调整或清除筛选。")
    local footerY = listHeight - footerHeight
    local previousWidth = math.max(72, p.previous.textWidth + 28); local nextWidth = math.max(72, p.next.textWidth + 28)
    local nextX = 16 + previousWidth + 8; local pageX = nextX + nextWidth + 16
    local inputX = pageX + 112; local jumpX = inputX + 68; local rangeX = jumpX + 92
    Place(p.previous, 16, footerY, previousWidth, 34); Place(p.next, nextX, footerY, nextWidth, 34); Place(p.pageLabel, pageX, footerY + 8, 100, 20)
    Place(p.pageInput, inputX, footerY, 56, 34); Place(p.jump, jumpX, footerY, 72, 34); Place(p.range, rangeX, footerY + 8, math.max(1, inner + 16 - rangeX), 20)
    local narrowFooter = inner < 600
    p.pageInput:Show(); p.jump:Show()
    if narrowFooter then
        Place(p.pageInput, 16, footerY + 44, 56, 34); Place(p.jump, 84, footerY + 44, 72, 34)
        Place(p.range, 168, footerY + 52, inner - 152, 20)
    end
    p.previous:SetEnabled(p.rulePage > 1); p.next:SetEnabled(p.rulePage < p.totalPages)
    p.pageLabel:SetText(p.rulePage .. " / " .. p.totalPages .. " 页"); if not p.pageInput:HasFocus() then p.pageInput:SetText(tostring(p.rulePage)) end
    p.range:SetText(#ids == 0 and "0 / " .. total .. " 条" or ("显示 " .. ((p.rulePage - 1) * capacity + 1) .. "–" .. math.min(#ids, p.rulePage * capacity) .. " / " .. #ids .. " 条"))
    p.list.title:SetText("发件规则 · 共 " .. total .. " 条")
    local e = editorWidth - 32
    local tight = h < 580
    Place(p.itemLabel, 16, tight and 44 or 58, e, 20)
    local methodWidths = { 88, 72, 72, 96 }; local mx = 16
    for index = 1, 4 do methodWidths[index] = methodWidths[index] + (e - 364) / 4 end
    for index, b in ipairs(p.methods) do Place(b, mx, tight and 68 or 90, methodWidths[index], 34); b:SetState(({ "id", "name", "bag", "drag" })[index] == p.method and "selected" or "default"); mx = mx + methodWidths[index] + 12 end
    Place(p.query, 16, tight and 112 or 144, e - 100, 34); Place(p.lookup, e - 72, tight and 112 or 144, 88, 34)
    p.query.hint:SetText(p.method == "id" and "输入物品 ID" or "输入物品名字")
    p.query:SetShown(p.method == "id" or p.method == "name"); p.lookup:SetShown(p.method == "id" or p.method == "name")
    Place(p.itemDrop, 16, tight and 158 or 208, 40, 40); Place(p.itemName, 68, tight and 158 or 210, e - 52, 20); Place(p.itemInfo, 68, tight and 180 or 233, e - 52, 18); Place(p.items, 16, tight and 210 or 268, e, 34)
    if p.draft.itemID then p.draft.item = Rules:GetItem(p.draft.itemID, p.known[p.draft.itemID] or p.draft.item) end
    local selectedItem = p.draft.item
    p.itemName:SetText(selectedItem and Addon.ViewModel:Escape(selectedItem.name) or "请选择物品 / 拖入物品")
    p.itemInfo:SetText(selectedItem and ("物品 ID " .. selectedItem.itemID .. (selectedItem.resolved and " · 已选定" or " · 等待信息")) or "支持 ID、名字、背包和拖放")
    p.itemIcon:SetTexture(selectedItem and selectedItem.texture); p.itemIcon:SetShown(selectedItem and selectedItem.texture ~= nil or false)
    p.itemDrop:SetText(selectedItem and selectedItem.texture and "" or "+")
    host.bindTooltip(p.itemDrop, selectedItem and selectedItem.name or "物品拖入区", { "拖入只读取物品，不移动或寄送。", selectedItem and ("物品 ID：" .. selectedItem.itemID) or "请选择明确物品。" })
    local candidates = p.candidates or {}
    if p.method == "bag" then
        candidates = {}; local seenBag = {}
        for _, item in ipairs(Addon.Compose:BagItems()) do if not seenBag[item.itemID] then seenBag[item.itemID] = true; candidates[#candidates + 1] = Rules:GetItem(item.itemID, item) end end
        table.sort(candidates, function(a,b) return a.itemID < b.itemID end)
    end
    opts, p.itemPage = PageOptions(candidates, p.itemPage, 6, function(item)
        item = p.known[item.itemID] or Rules:GetItem(item.itemID, item)
        return { value = item.itemID, label = Addon.ViewModel:Escape(item.name) .. " · " .. item.itemID }
    end)
    p.items:SetOptions(opts); p.items:SetText(p.method == "bag" and "从背包选择物品" or #candidates > 0 and ("搜索结果 · " .. #candidates .. " 项") or "请选择候选，或将物品拖到图标区")
    Place(p.recipientLabel, 16, tight and 256 or 324, e, 20); Place(p.recipients, 16, tight and 280 or 352, e - 76, 34); Place(p.findRecipient, e - 48, tight and 280 or 352, 64, 34)
    Place(p.recipient, 16, tight and 322 or 402, e, 34); Place(p.recipientSearch, 16, tight and 244 or 310, e, 34)
    p.recipientSearch:SetShown(p.searchRecipient == true); p.recipientLabel:SetShown(not p.searchRecipient)
    local recipients = {}; local recipientQuery = string.lower(Trim(p.recipientSearch:GetText()))
    for _, contact in ipairs(Rules:GetRecipients()) do if recipientQuery == "" or string.lower(contact.label):find(recipientQuery, 1, true) then recipients[#recipients + 1] = contact end end
    opts, p.recipientPage = PageOptions(recipients, p.recipientPage, 6, function(entry) return { value = entry.address, label = Addon.ViewModel:Escape(entry.label) } end)
    p.recipients:SetOptions(opts); p.recipients:SetText("选择其它角色 / 规则收件人")
    Place(p.addressInfo, 16, tight and 364 or 452, e, 18); local address, addressErr = Rules:NormalizeAddress(p.draft.recipient)
    p.addressInfo:SetText(address and ("保存地址：" .. Addon.ViewModel:Escape(address)) or (p.draft.recipient == "" and "未填服务器默认当前角色所在服务器。" or addressErr))
    Place(p.enabled, 16, tight and 390 or 484, 128, 24); p.enabled:SetChecked(p.draft.enabled)
    Place(p.required, 168, tight and 393 or 487, e - 152, 18)
    Place(p.save, 16, h - 50, 128, 34); Place(p.cancel, 156, h - 50, 112, 34); Place(p.contactButton, e - 84, h - 50, 100, 34)
    p.save:SetEnabled(selectedItem ~= nil and selectedItem.resolved and address ~= nil)
    p.editor.title:SetText(p.editRule and "编辑发件规则" or "新建发件规则")
    Place(p.contactChoose, 16, 58, e, 34); Place(p.contactAddressLabel, 16, 112, e, 20); Place(p.contactAddress, 16, 142, e, 34)
    Place(p.contactNameLabel, 16, 198, e, 20); Place(p.contactName, 16, 228, e, 34); Place(p.contactHelp, 16, 284, e, 20)
    Place(p.contactSave, 16, h - 50, 128, 34); Place(p.contactBack, 156, h - 50, 112, 34); Place(p.contactDeleteHint, 16, h - 98, e, 20)
    opts, p.contactPage = PageOptions(Addon.db.contacts, p.contactPage, 6, function(contact) return { value = contact.address, label = Addon.ViewModel:Escape(contact.label) } end)
    table.insert(opts, 1, { value = "__new", label = "新建收藏联系人" }); p.contactChoose:SetOptions(opts); p.contactChoose:SetText(p.editContact and Addon.ViewModel:Escape(p.editContact) or "新建收藏联系人")
    local left = wide and listWidth or width; local rightX = wide and left + 16 or 0; local right = wide and editorWidth or width
    local denseInbox = wide and tight
    local preferenceHeight = denseInbox and 248 or 276
    local collectHeight = denseInbox and h - preferenceHeight - 16 or 288
    local processingHeight = denseInbox and h - 156 or 380
    Section(p.preferences, 0, 54, left, preferenceHeight, inbox)
    Section(p.collect, 0, 54 + preferenceHeight + 16, left, collectHeight, inbox)
    Section(p.processing, rightX, wide and 54 or 650, right, processingHeight, inbox)
    Section(p.flow, rightX, wide and 54 + processingHeight + 16 or 1046, right, denseInbox and 140 or 184, inbox)
    local prefInner = left - 32; local dropdownWidth = math.floor((prefInner - 12) / 2)
    Place(p.initialLabel, 16, 58, prefInner, 20); Place(p.initialMail, 16, 84, 112, 34); Place(p.initialItems, 140, 84, 112, 34)
    p.initialMail:SetState(p.incoming.mode == "mail" and "selected" or "default"); p.initialItems:SetState(p.incoming.mode == "items" and "selected" or "default")
    Place(p.orderLabel, 16, 140, dropdownWidth, 20); Place(p.kindLabel, 28 + dropdownWidth, 140, dropdownWidth, 20)
    Place(p.order, 16, 168, dropdownWidth, 34); Place(p.kind, 28 + dropdownWidth, 168, dropdownWidth, 34); p.order:SetValue(p.incoming.sort); p.kind:SetValue(p.incoming.kind)
    Place(p.remember, 16, 232, prefInner, 24); p.remember:SetChecked(p.incoming.rememberFilters)
    Place(p.rangeLabel, 16, 58, prefInner, 20); Place(p.includeItems, 16, 92, 180, 24); Place(p.includeMoney, 228, 92, math.max(100, prefInner - 212), 24)
    p.includeItems:SetChecked(p.incoming.selectItems); p.includeMoney:SetChecked(p.incoming.selectMoney)
    Place(p.collectHelp, 16, 140, prefInner, 20); Place(p.summary, 16, 174, prefInner, 24); p.summary:SetChecked(p.incoming.showSummary)
    Place(p.inboxSave, 16, 238, 144, 34); Place(p.inboxReset, 172, 238, 128, 34)
    for index, pair in ipairs(p.processingLines) do Place(pair[1], 16, 58 + (index - 1) * 58, right - 32, 20); Place(pair[2], 16, 82 + (index - 1) * 58, right - 32, 18) end
    for index, t in ipairs(p.flowLines) do Place(t, 16, ({54,92,134})[index], right - 32, 20) end
    if denseInbox then
        Place(p.initialLabel, 16, 44, prefInner, 20); Place(p.initialMail, 16, 68, 112, 34); Place(p.initialItems, 140, 68, 112, 34)
        Place(p.orderLabel, 16, 116, dropdownWidth, 20); Place(p.kindLabel, 28 + dropdownWidth, 116, dropdownWidth, 20)
        Place(p.order, 16, 140, dropdownWidth, 34); Place(p.kind, 28 + dropdownWidth, 140, dropdownWidth, 34)
        Place(p.remember, 16, 202, prefInner, 24)
        Place(p.rangeLabel, 16, 44, prefInner, 20)
        Place(p.includeItems, 16, 76, 156, 24); Place(p.includeMoney, 184, 76, prefInner - 168, 24)
        Place(p.collectHelp, 16, 112, prefInner, 20); Place(p.summary, 16, 142, prefInner, 24)
        Place(p.inboxSave, 16, collectHeight - 50, 144, 34); Place(p.inboxReset, 172, collectHeight - 50, 128, 34)
        for index, pair in ipairs(p.processingLines) do
            Place(pair[1], 16, 44 + (index - 1) * 50, right - 32, 20)
            Place(pair[2], 16, 68 + (index - 1) * 50, right - 32, 18)
        end
        for index, t in ipairs(p.flowLines) do Place(t, 16, ({44,78,108})[index], right - 32, 20) end
    end
    Section(p.cache, 0, 54, width, 460, cache)
    Place(p.historyLabel, 16, 58, 232, 20); Place(p.historyDays, 260, 50, 112, 34)
    Place(p.unverifiedLabel, 16, 108, 232, 20); Place(p.unverifiedDays, 260, 100, 112, 34); Place(p.daysSave, 16, 152, 144, 34)
    local cached, visible, backlog, history = 0, 0, 0, 0
    for _, snapshot in pairs(Addon.db.byCharacter) do
        cached = cached + 1; visible = visible + #(snapshot.visibleKeys or {}); history = history + #(snapshot.history or {})
        for _, mail in pairs(snapshot.records or {}) do if mail.state == "unverified" then backlog = backlog + 1 end end
    end
    Place(p.cacheStats, 16, 212, width - 32, 54); p.cacheStats:SetText("已缓存 " .. cached .. " 个角色 · 当前可见记录 " .. visible .. " 封 · 待核实 " .. backlog .. " 封 · 历史 " .. history .. " 条")
    Place(p.cacheHelp, 16, 276, width - 32, 50); Place(p.risk, 16, 348, width - 32, 20)
    Place(p.ruleDelete, 16, 390, 176, 34); Place(p.contactDelete, 204, 390, 176, 34); Place(p.cleanup, 392, 390, 196, 34)
    if width < 620 then Place(p.cleanup, 16, 440, 196, 34); p.cache:SetHeight(490) end
    p.ruleDelete:SetEnabled(p.editRule ~= nil and Addon.db.rules[p.editRule] ~= nil); p.contactDelete:SetEnabled(p.editContact ~= nil)
    host.bindTooltip(p.ruleDelete, "删除所选规则", { p.editRule and ("物品 ID：" .. p.editRule) or "在发件页点击规则编辑后，切换到本页删除。" })
    host.bindTooltip(p.contactDelete, "删除所选联系人", { p.editContact or "在发件页联系人管理中选择收藏后，切换到本页删除。" })
    local contentHeight = cache and p.cache:GetHeight() or inbox and (wide and h or 1176) or ((wide or p.editing or p.contactMode) and h or listHeight)
    local height = 54 + contentHeight + 40
    p:SetHeight(height); Place(p.messageText, 0, height - 38, width, 38)
    p.messageText:SetText(p.message or (send and "物品、收件人为必填；原生发件箱每封最多 12 个附件。" or inbox and "偏好只影响默认视图与全选范围；每批先预览，再确认收取。" or "保留期限不清理当前可见邮件；破坏性操作需要确认。"))
    p.refreshing = nil
    return height
end
