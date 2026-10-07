-- Lua 5.1: actual workspace/models/theme, simulated WoW frames and snapshots.
local methods = {}
local function Frame(parent)
    local frame = setmetatable({ parent = parent, children = {}, shown = true, enabled = true,
        scripts = {}, hooks = {}, points = {}, level = parent and parent.level + 1 or 1 }, { __index = methods })
    if parent then parent.children[#parent.children + 1] = frame end
    return frame
end
for _, name in ipairs({ "SetJustifyV", "SetWordWrap", "SetVertexColor", "SetTextInsets", "SetBackdrop", "EnableMouse", "SetJustifyH",
    "SetAutoFocus", "SetMaxLetters", "SetNumeric", "SetAlpha", "SetClipsChildren", "EnableMouseWheel", "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "RegisterForClicks", "SetTexture", "SetDesaturated", "SetOwner", "SetHyperlink", "AddLine",
    "Raise", "ClearFocus", "SetColorTexture", "SetToplevel", "SetBackdropColor", "SetBackdropBorderColor", "SetTexCoord" }) do methods[name] = function() end end
function methods:SetAllPoints(target) self.allPoints = target or self.parent end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetStringWidth() return #(self.text or ""):gsub("[\128-\191]", "") * (self.fontSize or 16) * 0.75 end
function methods:GetChildren() return unpack(self.children) end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameStrata(v) self.strata = v end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {}; self.allPoints = nil end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.allPoints and self.allPoints:GetWidth() or self.width or (self.parent and self.parent:GetWidth()) or 1000 end
function methods:GetHeight() return self.allPoints and self.allPoints:GetHeight() or self.height or (self.parent and self.parent:GetHeight()) or 620 end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, hook in ipairs(self.hooks[event] or {}) do hook(self, ...) end
end
function methods:SetText(v)
    self.textWrites = (self.textWrites or 0) + 1
    self.text, self.cursor, self.composing = tostring(v or ""), #tostring(v or ""), false
    self:Fire("OnTextChanged", false)
end
function methods:InputText(v)
    self.text, self.cursor = tostring(v or ""), #tostring(v or "")
    self:Fire("OnTextChanged", true)
end
function methods:IsInIMEComposition() return self.composing == true end
function methods:GetText() return self.text or "" end
function methods:SetFocus() self.focused = true; self:Fire("OnEditFocusGained") end
function methods:ClearFocus() self.focused, self.composing = false, false end
function methods:ClearLines() self.lines = {} end
function methods:NumLines() return #(self.lines or {}) end
function methods:SetHyperlink(link) self.link = link; self.lines = { { text = "Native item: " .. link } } end
function methods:AddLine(text, red, green, blue, wrap)
    self.lines = self.lines or {}; self.lines[#self.lines + 1] = { text = text, color = { red, green, blue }, wrap = wrap }
end
function methods:AddDoubleLine(label, value)
    self.lines = self.lines or {}; self.lines[#self.lines + 1] = { label = label, value = value }
end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k, v) self.hooks[k] = self.hooks[k] or {}; table.insert(self.hooks[k], v) end
function methods:CreateFontString() return Frame(self) end
function methods:CreateTexture() return Frame(self) end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Show() local was = self.shown; self.shown = true; if not was then self:Fire("OnShow") end end
function methods:Hide() local was = self.shown; self.shown = false; if was then self:Fire("OnHide") end end
function methods:SetEnabled(v) self.enabled = v end
function methods:IsEnabled() return self.enabled end
function methods:SetScrollChild(v) self.child = v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
function methods:SetMinMaxValues(low, high) self.min, self.max = low, high end
function methods:SetValue(v) if self.value ~= v then self.value = v; self:Fire("OnValueChanged", v) end end
function methods:SetThumbTexture(v) self.thumb = v end
function methods:GetThumbTexture() return self.thumb end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index]) end
function methods:SetContentHeight(v) self.contentHeight = v end
function methods:SetVerticalScroll(v) if self.offset ~= v then self.offset = v; self:Fire("OnVerticalScroll", v) end end
function methods:SetChecked(v) self.checked = not not v end
function methods:GetChecked() return self.checked end
function methods:GetBottom() return 500 end
function CreateFrame(_, _, parent) return Frame(parent) end
UIParent, GameTooltip = Frame(), Frame()
date = os.date
local now = 20000000
function GetServerTime() return now end
local nativeCalls = 0
for _, fn in ipairs({ "TakeInboxItem", "TakeInboxMoney", "ReturnInboxItem", "DeleteInboxItem", "SendMail", "GetInboxText" }) do
    _G[fn] = function() nativeCalls = nativeCalls + 1; error("Workspace must only browse cached facts") end
end
YiboCore = {}; dofile("YiboCore/UI/Theme.lua")
YiboCore.Capabilities = { Register = function() end }
STANDARD_TEXT_FONT = "font"
dofile("YiboCore/UI/Input.lua")
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, DRUID = { r = 1, g = 0.49, b = 0.04 } }
dofile("YiboMail/Namespace.lua")
local Addon = YiboMail; Addon.Core = YiboCore
local a = { id = "A", name = "Alpha", realm = "One", class = "MAGE" }
local b = { id = "B", name = "Beta", realm = "Two", class = "DRUID" }
local c = { id = "C", name = "SendOnly", realm = "One" }
local hidden = { id = "Hidden", name = "Hidden", realm = "Three" }
local chars = { a, b, c }
YiboCore.Characters = {
    GetCurrent = function() return a end,
    GetDisplayName = function(_, character) return character.name end,
    GetAllCached = function() return chars end,
}
local definition
YiboCore.AccountView = { NotifyPageChanged = function() end, RegisterPage = function(_, _, page) definition = page; return true end }
YiboCore.Entry = { RegisterBusinessEntry = function() return true end }
for _, file in ipairs({ "Store", "ViewModel", "WorkspaceState", "MailUI", "CacheModel", "HistoryModel", "AccountPage", "CacheUI" }) do dofile("YiboMail/" .. file .. ".lua") end
Addon.Items = {
    Events = { Emit = function() end },
    GetState = function(_, id) return { status = id == "B" and "stale" or "known" } end,
}
Addon:InitializeDatabase(); Addon.AccountPage:Register()
local function Item(id, quantity, variant, name)
    return { itemID = id, quantity = quantity, variantKey = variant or tostring(id), name = name or ("Item" .. id), attachmentIndex = 1 }
end
local function Mail(subject, items, expiry, cod, money)
    return { subject = subject, sender = "Sender", signature = subject, inboxIndex = 1, attachments = items or {},
        expiresAtEstimate = expiry, cod = cod or 0, money = money or 0, observedAt = now, state = "observed" }
end
local function Snapshot(character, mails, partial)
    local snapshot = { records = {}, visibleKeys = {}, history = {}, coverage = { status = partial and "partial" or "known",
        observedAt = now, currentCount = #mails, totalCount = partial and #mails + 3 or #mails, unscannedCount = partial and 3 or 0 } }
    for index, mail in ipairs(mails) do local key = character.id .. index; mail.mailKey, mail.inboxIndex = key, index; snapshot.records[key] = mail; snapshot.visibleKeys[index] = key end
    Addon.db.byCharacter[character.id] = snapshot; return snapshot
end
local sA = Snapshot(a, { Mail("Alpha mail", { Item(100, 2, "v1", "Ore"), Item(100, 3, "v2", "Ore") }, now + 86400, 0, 50000), Mail("Long | subject", {}, 0) })
local sB = Snapshot(b, { Mail("Beta mail", { Item(100, 4, "v1", "Ore"), Item(100, 5, "v1", "Ore") }, now + 259200, 25000, 90000), Mail("Expired", {}, now - 1) }, true)
Snapshot(hidden, { Mail("Ore hidden", { Item(100, 99, "v1", "Ore") }, now + 1) })
Addon:AddHistory(c.id, { state = "in-transit", recipient = "Friend-One", subject = "send", observedAt = now, attachments = { Item(900, 1) }, copper = 100, cod = true })
Addon:AddHistory(a.id, { state = "collected-archived", mail = sA.records.A1, item = Item(100, 1, "v1", "Ore"), money = 0, observedAt = now - 5 })
Addon:AddHistory(a.id, { state = "collected-archived", mail = sA.records.A1, money = 200, observedAt = now - 4 })
Addon:AddHistory(a.id, { state = "unverified", mail = sA.records.A1, observedAt = now - 31 * 86400 })
Addon:AddHistory(a.id, { state = "discovered", mail = sA.records.A1, observedAt = now - 91 * 86400 })
local shownFields = {}
local context = { characters = chars, preview = false, GetFieldVisible = function(_, id)
    if shownFields[id] ~= nil then return shownFields[id] end
    return id ~= "backlog"
end }
local eligible = definition.GetEligibleCharacters(chars, context); assert(#eligible == 3)
local metrics = definition.GetSurfaceMetrics(context)
assert(metrics.minContentWidth == 1000 and metrics.naturalContentWidth >= 1154)
assert(#definition.GetEligibleCharacters(chars, { preview = true }) == 2)
assert(#Addon.CacheModel:Characters(context) == 2)
local result = Addon.CacheModel:GetMails(context, { character = "A", search = " ore ", sort = "expiry" })
assert(#result == 2 and result[1].character.id == "A" and result[2].character.id == "B")
assert(#Addon.CacheModel:GetMails({ characters = { a } }, { search = "Ore" }) == 1)
assert(#Addon.CacheModel:GetMails(context, { search = "900" }) == 0, "Send-only history must not become mailbox content")
local groups = Addon.CacheModel:GetGroups(result, "expiry", "Ore")
assert(#groups == 2 and groups[1].normalQuantity == 2 and groups[1].codQuantity == 9 and groups[1].mailCount == 2 and #groups[1].sources == 3)
local totals = Addon.CacheModel:Totals(result); assert(totals.money == 50000 and totals.cod == 1 and totals.attachmentMails == 2)
local risk = Addon.CacheModel
assert(risk:Risk(Mail("", {}, now)) == "expired")
assert(risk:Risk(Mail("", {}, now + 86400)) == "urgent")
assert(risk:Risk(Mail("", {}, now + 86401)) == "soon")
assert(risk:Risk(Mail("", {}, now + 259200)) == "soon")
assert(risk:Risk(Mail("", {}, 0)) == "unknown" and risk:Risk(Mail("", {})) == "unknown")
assert(#risk:GetMails(context, { risk = "threeDays" }) == 2)
sA.records.A2.wasReturned = true
assert(#risk:GetMails(context, { kind = "returned" }) == 1 and risk:MailDetail({ mail = sA.records.A2 }):find("退回邮件", 1, true))
assert(Addon.ViewModel:Expiry(Mail("", {}, 0)) == "期限未知")
local history = Addon.HistoryModel:Query(context, { days = 90 })
assert(#history == 3 and history[1].character.id == "C" and history[1].result == "已发送 · 在途")
assert(Addon.HistoryModel:Content(history[1]):find("整封COD", 1, true))
local actual = Addon.HistoryModel:Query(context, { kind = "collected", search = "100" })
assert(#actual == 1 and actual[1].items[1].quantity == 1, "Actual collection must not repeat the original whole mail")
assert(#Addon.HistoryModel:Query(context, { kind = "collected", search = "900" }) == 0)
assert(#Addon.HistoryModel:Query(context, { character = "C", kind = "send" }) == 1)
assert(#Addon.HistoryModel:Query(context, { days = 7, result = "in-transit" }) == 1)
local state = Addon.WorkspaceState:Get(); local inbox = state.inbox
Addon.WorkspaceState:ValidateCharacters({ a, b }); assert(inbox.character == "A")
inbox.scroll, inbox.anchor = 46, "A2"; Addon.WorkspaceState:Search("Ore"); assert(inbox.scroll == 0)
Addon.WorkspaceState:SelectCharacter("B", { a, b }, result, 1); assert(inbox.anchor == result[2].id and inbox.character == "A")
Addon.WorkspaceState:Search(""); assert(inbox.scroll == 46 and inbox.anchor == "A2" and inbox.character == "A")
inbox.search, inbox.scroll, inbox.anchor = "", 0, nil
local host = Frame(UIParent); host:SetSize(1000, 620)
Addon.AccountPage:Create(host); Addon.AccountPage:Refresh(host, context)
local root = host.mailWorkspace
local function Click(control) assert(control:IsShown() and control:IsEnabled()); control:Fire("OnClick") end
assert(root.search.placeholder and root.search.SetValue, "Search must use Core's input control")
assert(root.tabs.activeGap:IsShown() and root.tabs.activeGap.points[1][2] == root.tabs.buttons.inbox)
assert(root.ownerRows[2]:GetHeight() == 32 and root.ownerRows[2].name.points[1][3] == root.ownerRows[2].meta.points[1][3])
Click(root.tabs.buttons.history); assert(state.tab == "history" and root.total == 3)
assert(root.tabs.activeGap.points[1][2] == root.tabs.buttons.history)
assert(root.historyCharacter.options[2].label:find("|cff", 1, true), "Character filters need class colors")
assert(root.rows[2].cells[2]:GetText():find("|cff", 1, true), "Historical character names need class colors")
-- Wubi d -> dy -> dyt is native composition text, not a search query.
root.search:SetFocus(); root.search.composing = true
local textWrites = root.search.textWrites or 0
for _, preedit in ipairs({ "d", "dy", "dyt" }) do
    root.search:InputText(preedit)
    root.refresh() -- Also cover a periodic/data refresh during composition.
    assert(root.search.composing and root.search:GetText() == preedit and root.search.focused)
    assert(state.history.search == "" and root.total == 3)
    assert((root.search.textWrites or 0) == textWrites, "Refreshing must not write back native composition text")
end
root.search:Fire("OnEnterPressed"); assert(root.search.focused and root.search.composing)
root.search:Fire("OnEscapePressed"); assert(root.search.focused and root.search.composing)
root.search:InputText("矿") -- Final text may arrive before the IME flag clears.
assert(state.history.search == "")
root.search.composing = false; root.search:Fire("OnUpdate", 0)
assert(state.history.search == "矿" and root.search:GetText() == "矿" and not root.search.imePending)
assert((root.search.textWrites or 0) == textWrites)
root.search.cursor = 0; root.refresh()
assert(root.search.cursor == 0 and (root.search.textWrites or 0) == textWrites, "Refresh must preserve the caret")
root.search:SetFocus(); root.search:InputText("Friend"); assert(state.history.search == "Friend" and root.total == 1)
assert(root.search.focused, "Filtering must retain keyboard focus in Core's input")
Click(root.tabs.buttons.inbox); assert(root.search:GetText() == "" and inbox.character == "A")
root.search:InputText("Ore"); assert(root.total == 2 and #root.ownerRows == 3)
assert(root.ownerRows[2].current:IsShown() and not root.ownerRows[3].current:IsShown())
Click(root.ownerRows[3]); assert(inbox.character == "A" and root.total == 2 and inbox.search == "Ore")
Click(root.items); assert(root.total == 2)
assert(not root.tableHeader:IsShown() and root.tiles[1].count:GetText() == "11" and root.tiles[1]:GetWidth() == 42)
root.tiles[1]:Fire("OnEnter")
local sourceLines = {}
for _, line in ipairs(GameTooltip.lines) do
    if line.text and line.text:find("发件人：", 1, true) then sourceLines[#sourceLines + 1] = line end
end
assert(GameTooltip.link == "item:100" and #sourceLines == 3)
assert(sourceLines[1].text:find("邮箱：", 1, true) and sourceLines[1].text:find("Alpha", 1, true) and sourceLines[1].text:find("发件人：Sender", 1, true))
assert(sourceLines[1].text:find("×2", 1, true) and sourceLines[2].text:find("×4", 1, true) and sourceLines[3].text:find("×5", 1, true))
for _, line in ipairs(sourceLines) do
    assert(line.wrap == false and not line.text:find("\n", 1, true), "Each source must occupy a single line")
end
local sameNameGroup = Addon.Copy(root.data[1])
for _, source in ipairs(sameNameGroup.sources) do source.entry.character.name = "Twin" end
local sameNameLines = Addon.CacheUI:AttachmentTooltip(sameNameGroup)
assert(sameNameLines[4]:find("One", 1, true) and sameNameLines[5]:find("Two", 1, true), "Sources retain each mailbox's realm even with identical display names")
root.tiles[2]:Fire("OnEnter")
local sourceCount = 0
for _, line in ipairs(GameTooltip.lines) do if line.text and line.text:find("发件人：", 1, true) then sourceCount = sourceCount + 1 end end
assert(sourceCount == 1, "Pooled item tooltips must clear the previous item's sources")
Click(root.tiles[1]); assert(inbox.detail.type == "item")
Click(root.detailRows[2]); assert(inbox.detail.type == "mail" and inbox.detailReturn.type == "item")
Click(root.back); assert(inbox.detail.type == "item")
Click(root.back); assert(inbox.detail == nil)
Click(root.tabs.buttons.overview); assert(root.total == 2)
assert(root.overview.mailRows[1].cells[3]:GetText() == "2", "Overview counts attachment slots independently of stack quantity")
Click(root.overview.mailRows[2].links[1]); assert(state.tab == "inbox" and inbox.character == "B" and inbox.risk == "expired" and root.total == 1)
Click(root.back); assert(state.tab == "overview")
inbox = state.inbox -- Return restores an independent snapshot of the prior inbox state.
local previewContext = { characters = { a, b }, preview = true, GetFieldVisible = function(_, id) return Addon.db.settings.previewColumns[id] == true end }
local before = Addon.Copy(state)
Addon.AccountPage:Refresh(host, previewContext)
assert(root:IsShown() == false and host.mailPreview:IsShown())
assert(host.mailPreview.mailRows[2].cells[3]:GetText() == root.overview.mailRows[2].cells[3]:GetText())
assert(state.tab == before.tab and state.inbox.search == before.inbox.search)
Addon.AccountPage:Refresh(host, context)
host:Hide(); host:Show(); Addon.AccountPage:Refresh(host, context); assert(state.tab == "overview")
host:SetSize(640, 480); Addon.AccountPage:Refresh(host, context)
assert(root.overview.mailRows[1]:GetWidth() <= host:GetWidth() - 30)
Click(root.tabs.buttons.inbox)
assert(root.list:GetHeight() > 0 and not root.previous:IsShown() and not root.next:IsShown())
local filterY = root.scope.points[1][3]
for _, control in ipairs({ root.kind, root.risk, root.sort, root.mail, root.items }) do
    assert(control.points[1][3] == filterY, "Filters must occupy exactly one row")
    assert(control.points[1][2] + control:GetWidth() <= host:GetWidth() - 8)
end
local matchingID = root.data[1] and root.data[1].id
host:SetSize(1100, 620); Addon.AccountPage:Refresh(host, context)
assert(inbox.anchor == matchingID)
Click(root.tabs.buttons.history); assert(root.search:GetText() == "Friend" and root.total == 1)
assert(nativeCalls == 0)
-- More than 20 roles are available through height-based overview and paged history filters.
local many = { a, b, c }
for index = 1, 23 do
    local character = { id = "Many" .. index, name = "角色" .. index, realm = "One" }
    Snapshot(character, { Mail("Many", { Item(100, 1, "v1", "Ore") }, now + 900000) }); Addon:AddHistory(character.id, { state = "in-transit", recipient = "Target", subject = "Many", observedAt = now })
    many[#many + 1] = character
end
local manyContext = { characters = many, preview = false, GetFieldVisible = context.GetFieldVisible }
Addon.AccountPage:Refresh(host, manyContext); root.search:InputText("")
assert(root.historyCharacter.menuPageSize == 8 and root.historyCharacter.menu:GetHeight() <= 300)
Click(root.historyCharacter); Click(root.historyCharacter.menu.next)
assert(root.historyCharacter.menu.buttons[1].option.value == "Many6")
Click(root.historyCharacter.menu.buttons[1]); assert(state.history.character == "Many6" and root.total == 1)
Click(root.tabs.buttons.overview); assert(root.total == 25 and root.pageCount > 1)
Click(root.next); assert(state.overview.page == 2 and root.overview.mailRows[1].cells[1]:GetText() == "角色" .. (root.overview.capacity - 1))
-- Real Core scrollbars must follow hidden viewports and retain their offsets.
Click(root.tabs.buttons.inbox); root.search:InputText("Many"); Click(root.mail)
assert(root.list.ScrollBar:IsShown() and root.owners.ScrollBar:IsShown())
root.list:SetVerticalScroll(92)
local scrollAnchor = state.inbox.anchor
assert(root.rows[1].recordID == scrollAnchor and #root.rows < root.total, "Rows are recycled within a continuous list")
root.list:SetVerticalScroll(root.list.scrollRange)
local lastID = root.data[#root.data].id
local foundLast
for _, row in ipairs(root.rows) do if row:IsShown() and row.recordID == lastID then foundLast = true end end
assert(foundLast, "The final record must remain accessible through scrolling")
root.list:SetVerticalScroll(92)
Click(root.tabs.buttons.history)
assert(not root.owners.ScrollBar:IsShown(), "Hidden role sidebar must hide its sibling scrollbar")
root.owners:UpdateScrollbar(); assert(not root.owners.ScrollBar:IsShown(), "Delayed updates must not resurrect the track")
Click(root.clear); assert(root.list.ScrollBar:IsShown())
local historyWidth = host:GetWidth()
host:SetWidth(360); root.refresh()
assert(root.panLeft == nil and root.panRight == nil and #root.listLayout.fields == 6)
assert(root.listContent:GetWidth() == root.list:GetWidth())
local fittedWidth = 0
for _, field in ipairs(root.listLayout.fields) do fittedWidth = fittedWidth + field.fittedWidth end
assert(math.abs(fittedWidth - root.list:GetWidth()) < 0.01)
host:SetWidth(historyWidth); root.refresh()
root.list:SetVerticalScroll(76); local historyAnchor = state.history.anchor
Click(root.tabs.buttons.overview)
assert(not root.list.ScrollBar:IsShown() and not root.owners.ScrollBar:IsShown())
Click(root.tabs.buttons.history); assert(root.list:GetVerticalScroll() == 76 and state.history.anchor == historyAnchor)
Click(root.tabs.buttons.inbox); assert(root.list:GetVerticalScroll() == 92 and state.inbox.anchor == scrollAnchor)
Click(root.tabs.buttons.inbox); root.search:InputText("Ore"); Click(root.items); Click(root.tiles[1])
root.detail:Fire("OnVerticalScroll", 48)
Click(root.tabs.buttons.history); Click(root.tabs.buttons.inbox)
assert(state.inbox.detail.type == "item" and root.detail.offset == 48)
Click(root.detailRows[2]); Click(root.back); assert(root.detail.offset == 48, "Source return must restore detail reading position")
Addon.AccountPage:Refresh(host, context)
state.history.search, state.history.character = "Friend", nil
-- Unverified scan projections stay separate from current holdings and actual operations.
local missing = Mail("Missing", { Item(777, 8) }, now + 1000)
missing.state, missing.stateEnteredAt = "unverified", now - 10
sB.records.missing = missing
local backlog = Addon.HistoryModel:Query(context, { result = "unverified", search = "777" })
assert(#backlog == 1 and backlog[1].event == "扫描待核实" and backlog[1].sourceKey == "missing")
assert(#Addon.CacheModel:GetMails(context, { search = "777" }) == 0)
assert(#Addon.CacheModel:GetMails(context, { search = "777", scope = "unverified" }) == 1)
-- Settings controls are pooled; decreasing retention requires the player's in-game confirmation.
local settingsHost = Frame(UIParent); settingsHost:SetWidth(600)
local helpers = { createSection = function(parent) return Frame(parent) end,
    createCheckbox = function(parent, label) return YiboCore.UITheme:CreateCheckbox(parent, label) end }
definition.settings.CreateSettingsPanel(settingsHost, helpers)
local children = #settingsHost.children
definition.settings.CreateSettingsPanel(settingsHost, helpers); assert(#settingsHost.children == children)
local business = settingsHost.mailBusinessSettings
business.groups.contacts:GetScript("OnClick")(business.groups.contacts)
assert(Addon.db.settings.recipientGroups.contacts == false)
business.shortcutRows.onValueChanged(2); business.shortcutColumns.onValueChanged(4)
assert(business.gridCount:GetText() == "当前显示：8 格")
assert(business.previewSlots[8]:IsShown() and not business.previewSlots[9]:IsShown())
settingsHost:SetWidth(400); definition.settings.CreateSettingsPanel(settingsHost, helpers)
assert(business:GetHeight() >= business.previewY + 2 * 26)
settingsHost:SetWidth(1000); definition.settings.CreateSettingsPanel(settingsHost, helpers)
assert(business.previewX > 12 and business:GetHeight() == 376)
business.shortcutRows.onValueChanged(12); business.shortcutColumns.onValueChanged(6)
assert(business.gridCount:GetText() == "当前显示：72 格" and business.previewSlots[72]:IsShown())
local previewBottom = business.previewY + 11 * 17 + business.previewSlots[72]:GetHeight()
assert(previewBottom < business:GetHeight())
StaticPopupDialogs = {}; local popupData
StaticPopup_Show = function(id, _, _, data) assert(id == "YIBOMAIL_RETENTION"); popupData = data; return {} end
local retention = settingsHost.mailCacheSettings.historyDays
retention.onValueChanged(30); assert(Addon.db.settings.historyDays == 90 and retention.value == 90 and popupData)
StaticPopupDialogs.YIBOMAIL_RETENTION.OnAccept({}, popupData); assert(Addon.db.settings.historyDays == 30 and retention.value == 30)
retention.onValueChanged(90); assert(Addon.db.settings.historyDays == 90)
assert(Addon.AccountPage:SetRetention("historyDays", -1) == false)
-- Verify grouped Core field controls address the displayed option, not index in another group.
local selections = { x = true, y = false }
local multi = YiboCore.UITheme:CreateMultiSelectDropdown(host, 180, {
    { title = "X", group = "Inbox", isSelected = function() return selections.x end, setSelected = function(v) selections.x = v end },
    { title = "Y", group = "History", isSelected = function() return selections.y end, setSelected = function(v) selections.y = v end },
})
multi.groupSelector.onValueChanged("History"); multi.menu:Show(); Click(multi.menu.checks[1])
assert(selections.y and selections.x and multi.label:GetText() == "字段 2/2")
-- Reloading state module models /reload: no persisted search or active tab.
local historyFields = {}
for _, field in ipairs(Addon.AccountPage.Fields) do
    if field.group == '历史记录' then
        assert(field.key ~= 'event')
        historyFields[#historyFields + 1] = field
        if field.key == 'result' then assert(field.title == '事件/结果') end
    end
end
assert(#historyFields == 6)
local shortHistory = { character = a, time = now, counterpart = 'Target', subject = 'Short', event = '首次发现', result = '首次发现', state = 'discovered', record = {}, items = { Item(100, 2) }, money = 0 }
local longHistory = Addon.Copy(shortHistory)
longHistory.subject = string.rep('较长的多行主题', 12)
longHistory.items = { Item(100, 2), Item(101, 3), Item(102, 4), Item(103, 5) }
local historyRoot = Frame(host)
local offsets, heights, total, fittedWidth = Addon.CacheUI:HistoryLayout(historyRoot, historyFields, 1000, { shortHistory, longHistory })
assert(heights[2] == 38 and heights[1] == 38 and offsets[2] == 38 and total == 76 and fittedWidth == 1000)
for _, width in ipairs({ 320, 1000, 1200, 1800 }) do
    local columns = Addon.Copy(historyFields)
    Addon.CacheUI:HistoryLayout(historyRoot, columns, width, { shortHistory, longHistory })
    local totalWidth = 0
    for _, field in ipairs(columns) do
        totalWidth = totalWidth + field.fittedWidth
        if field.key == 'subject' then assert(field.fittedWidth <= 240) end
        if field.key == 'content' then assert(field.fittedWidth <= 280) end
    end
    assert(#columns == 6 and math.abs(totalWidth - width) < 0.01)
end
local cappedOnly = { Addon.Copy(historyFields[4]), Addon.Copy(historyFields[5]) }
Addon.CacheUI:HistoryLayout(historyRoot, cappedOnly, 1800, { longHistory })
assert(cappedOnly[1].fittedWidth <= 240 and cappedOnly[2].fittedWidth <= 280)
local recordIndex, recordTop = Addon.CacheUI:ListIndex({ offsets = offsets, heights = heights }, offsets[2] + 10)
assert(recordIndex == 2 and recordTop == offsets[2])
local historyValues = Addon.CacheUI:HistoryValues(shortHistory)
assert(not historyValues.character:find(a.realm, 1, true) and historyValues.result == '首次发现')
shortHistory.character = b
assert(Addon.CacheUI:HistoryValues(shortHistory).character:find(b.realm, 1, true))
local historyRow = Frame(historyRoot)
Addon.CacheUI:TableRow(historyRoot, historyRow, historyFields, historyValues, 1000, heights[1] - 2)
historyRow.iconHover:Fire('OnEnter'); assert(GameTooltip.link == 'item:100')
shortHistory.items, shortHistory.money = {}, 120000
historyValues = Addon.CacheUI:HistoryValues(shortHistory)
assert(historyValues.icon == nil and historyValues.content:find('金币', 1, true) and not historyValues.content:find('\n', 1, true))
Addon.CacheUI:TableRow(historyRoot, historyRow, historyFields, historyValues, 1000, heights[1] - 2)
print('PASS: fixed single-line history; capped subject/content widths and all columns fit narrow/wide viewports; same-realm short names; item tooltips and text-only gold')
assert(Addon.db.settings.inbox == nil and Addon.db.workspace == nil)
dofile("YiboMail/WorkspaceState.lua"); assert(Addon.WorkspaceState:Get().tab == "inbox" and Addon.WorkspaceState:Get().history.search == "")
local legacy = { state = "in-transit", recipient = "Legacy", observedAt = now }
sA.history[#sA.history + 1] = legacy
Addon:InitializeDatabase(); local legacyID = legacy.eventID; assert(legacyID)
table.remove(sA.history, 1); Addon:InitializeDatabase(); assert(legacy.eventID == legacyID)
assert(Addon.db.settings.previewColumns.alert == false and Addon.db.settings.previewColumns.cod == false)
-- Scan history is written once, and known duplicate ambiguity is not a new arrival.
local scanChar = { id = "Scan", name = "Scan", realm = "One" }
local function Commit(mails) Addon:CommitScan(scanChar, mails, { status = "known", observedAt = now, currentCount = #mails, totalCount = #mails }) end
Commit({ Mail("one", { Item(1, 2) }, now + 500) })
assert(#Addon.db.byCharacter.Scan.history == 1)
Commit({ Mail("one", { Item(1, 2) }, now + 500) }); assert(#Addon.db.byCharacter.Scan.history == 1)
Commit({ Mail("one", { Item(1, 2) }, now + 500), Mail("one", { Item(1, 2) }, now + 500) })
assert(#Addon.db.byCharacter.Scan.history == 1 and Addon.db.byCharacter.Scan.records[Addon.db.byCharacter.Scan.visibleKeys[1]].discoveryUncertain)
-- Use the real Core lookup too: string field IDs must honor definition defaults.
local coreDB = { settings = {} }
YiboCore.Database = { GetDB = function() return coreDB end }
YiboCore.CharacterSort = { NormalizeSettings = function(_, value) return value or {} end, NormalizeOrder = function(_, value) return value or {} end }
YiboCore.Events = { Register = function() end }; YiboCore.Capabilities = { Register = function() end }
YiboCore.Defaults = { Copy = function(_, value) return Addon.Copy(value) end }
dofile("YiboCore/UI/AccountView.lua")
YiboCore.AccountView._pages[definition.id] = definition
assert(YiboCore.AccountView:GetFieldVisible(definition.id, "backlog") == false)
assert(YiboCore.AccountView:GetFieldVisible(definition.id, "alert") == true)
assert(YiboCore.AccountView:GetFieldVisible(definition.id, "backlog", { backlog = true }) == true)
assert(#YiboCore.AccountView:GetVisibleFields(definition.id) == 21)
assert(#YiboCore.AccountView:GetVisibleFields(definition.id, definition.GetPreviewFields()) == 6)
-- Queued geometry refreshes must respect visibility without clearing offsets.
local callbacks = {}
C_Timer = { After = function(_, callback) callbacks[#callbacks + 1] = callback end }
local scroll = YiboCore.UITheme:CreateScrollFrame(host); scroll:SetSize(100, 60)
local child = Frame(scroll); child:SetSize(100, 300); scroll:SetScrollChild(child)
scroll:SetContentHeight(300); scroll:SetVerticalScroll(80); scroll:Hide()
for _, callback in ipairs(callbacks) do callback() end
assert(not scroll.ScrollBar:IsShown() and scroll:GetVerticalScroll() == 80)
callbacks = {}; scroll:Show()
for _, callback in ipairs(callbacks) do callback() end
assert(scroll.ScrollBar:IsShown() and scroll:GetVerticalScroll() == 80)
C_Timer = nil
-- The real settings workbench must ignore stale native ranges from pooled controls.
dofile("YiboCore/UI/AccountPages/SettingsWorkbench.lua")
local workbench = Frame(UIParent)
local settingsPage = YiboCore.AccountView._pages.settings
settingsPage.Create(workbench); workbench.scroll:SetSize(1000, 600)
YiboCore.AccountView.settingsTargetPageID = definition.id
workbench.scroll.GetVerticalScrollRange = function() return 999 end
settingsPage.Refresh(workbench)
assert(workbench.scroll.contentHeight < 600 and not workbench.scroll.ScrollBar:IsShown())
workbench.scroll:SetHeight(300); settingsPage.Refresh(workbench)
assert(workbench.scroll.ScrollBar:IsShown() and workbench.scroll.scrollRange > 0)
workbench.scroll:SetHeight(600); settingsPage.Refresh(workbench)
assert(not workbench.scroll.ScrollBar:IsShown() and workbench.scroll:GetVerticalScroll() == 0)
print("PASS: workspace tabs, global scoped search, role navigation, runtime-only state, shared overview/hover, continuous scrolling, COD icon variants, factual history and Core grouped fields")

-- Exercise the actual Core shell's clamping, not a copy of its calculation.
for _, name in ipairs({ "SetMovable", "SetResizable", "SetResizeBounds", "SetClampedToScreen", "RegisterForDrag", "StopMovingOrSizing", "SetAttribute", "SetFrameRef" }) do
    methods[name] = function() end
end
function methods:SetClampRectInsets(...) self.clampInsets = { ... } end
function methods:StartMoving() self.moving = true end
function methods:GetEffectiveScale() return 2 end
function methods:GetLeft() return 100 end
function methods:GetTop() return 800 end
local cursorX, cursorY = 400, 1400
function GetCursorPosition() return cursorX, cursorY end
local combat = false
function InCombatLockdown() return combat end
function RegisterStateDriver() end
local shell = YiboCore.AccountView:CreateFrame()
shell:Fire('OnSizeChanged', 960, 880)
assert(shell.clampInsets[4] == 880 - YiboCore.UITheme.Geometry.titleBar)
UIParent:SetSize(1600, 1000); shell:SetSize(960, 880); shell:Show()
shell:Fire('OnDragStart'); assert(shell.windowDrag and not shell.moving)
cursorX, cursorY = 480, 1280; shell:Fire('OnUpdate', 0.016)
assert(shell.points[1][4] == 140 and shell.points[1][5] == 740, 'Track both cursor axes using effective UI scale')
shell:Fire('OnDragStop'); assert(not shell.windowDrag and not shell:GetScript('OnUpdate'))
assert(YiboCore.AccountView:GetSettings().x == 140 and YiboCore.AccountView:GetSettings().y == 740)
shell.preview = true; shell:Fire('OnSizeChanged', 960, 880)
assert(shell.clampInsets[4] == 0, 'Hover previews retain full-frame clamping')
combat = true; shell.preview = false; shell:Fire('OnSizeChanged', 960, 880)
assert(shell.clampInsets[4] == 0, 'Do not mutate protected clamp geometry in combat')
combat = false; shell:Fire('OnSizeChanged', 960, 720)
assert(shell.clampInsets[4] == 720 - YiboCore.UITheme.Geometry.titleBar)
print('PASS: tall Core shell can move vertically with reachable title; full preview clamp and combat guard')
shell:Fire('OnDragStart'); shell:Hide()
assert(not shell.windowDrag and not shell:GetScript('OnUpdate'), 'Hide releases cursor tracking')
print('PASS: scaled mouse tracking, saved final anchor, and drag cleanup')
