-- Reuse the native-frame test harness and then exercise the new real UI modules.
dofile('YiboMail/_NonRelease/Tests/RecipientUISpec.lua')
local A, methods = YiboMail, getmetatable(MailFrame).__index
local modernBody = SendMailBodyEditBox
MailEditBox = CreateFrame('Frame', nil, SendMailFrame)
MailEditBox.GetEditBox = function() return modernBody end
local bodyScrollRange = 0
MailEditBox.ScrollBox = CreateFrame('Frame', nil, MailEditBox)
MailEditBox.ScrollBox.GetDerivedScrollRange = function() return bodyScrollRange end
modernBody:SetParent(MailEditBox)
MailEditBoxScrollBar = CreateFrame('Frame', nil, SendMailFrame)
SendMailBodyEditBox = nil
function methods:SetID(value) self.id = value end
function methods:GetID() return self.id end
function methods:SetNumeric() end
function methods:IsVisible() return self:IsShown() end
function methods:GetStringHeight() return 18 end
function methods:GetStringWidth() return #(self.text or '') * 7 end
for _, name in ipairs({ 'SetClipsChildren', 'EnableMouseWheel', 'SetOrientation', 'SetValueStep' }) do methods[name] = function() end end
function methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function methods:SetValue(value) self.value = value end
function methods:SetThumbTexture(texture) self.thumb = texture end
function methods:GetThumbTexture() return self.thumb end
function methods:GetVerticalScrollRange() return 0 end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index]) end
function GetItemClassInfo(id) if id == 7 then return '交易材料' end end
function GetItemSubClassInfo(class, id) if class == 7 and id == 7 then return '金属和矿石' end end
function GetItemInfo(value) local id = tonumber(value) or tonumber(tostring(value):match('item:(%d+)')); if id then return '物品' .. id, '|Hitem:' .. id .. '|h[物品]|h', 1, 1, 1, '交易材料', '金属和矿石', 20, '', 1, 1, 7, 7 end end
A.db.rules = {}; A.Queue = { state = 'idle' }; A.Scanner = { IsOpen = function() return true end }
A.Compose.BagItems = function() return {} end
MailFrameTab1, MailFrameTab2, SendMailAttachment1 = CreateFrame('Button', nil, MailFrame), CreateFrame('Button', nil, MailFrame), CreateFrame('Button', nil, SendMailFrame)
MailFrameTab1:SetSize(70, 30); MailFrameTab2:SetSize(70, 30)
function MailFrameTab_OnClick() end
local secureCalls, showHooks = 0, 0
function securecallfunction(callback, ...) secureCalls = secureCalls + 1; return callback(...) end
function PanelTemplates_SetNumTabs() error('Addon must not change Blizzard tab registry') end
function PanelTemplates_SetTab() error('Addon must not write Blizzard selectedTab') end
function PanelTemplates_TabResize() error('Addon tab must not use Blizzard templates') end
local nativeCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    assert(name ~= 'MailFrameTab3' and template ~= 'CharacterFrameTabButtonTemplate', 'Addon must own its tab')
    return nativeCreateFrame(kind, name, parent, template)
end
local nativeHookScript = methods.HookScript
function methods:HookScript(event, callback)
    if self == MailFrame and event == 'OnShow' then showHooks = showHooks + 1 end
    return nativeHookScript(self, event, callback)
end
A.Core.ItemResolver = {
    Parse = function(_, value) local id = tonumber(value); if id then return { { itemID = id, name = '物品' .. id } } end return nil, '请选择物品' end,
    Request = function(_, id, callback) callback({ itemID = id, name = '物品' .. id, icon = 1 }); return { Cancel = function() end } end,
}
A.Core.ItemConfirmation = { Show = function(_, options) A.confirmation = options; return options end }
dofile('YiboCore/UI/ItemPicker.lua')
dofile('YiboMail/SendRules.lua'); A.SendRules:Initialize()
for _, character in ipairs(A.Core.Characters:GetAllCached()) do character.faction = 'Alliance' end
A.Core.Characters.GetCurrent = function() return A.Core.Characters:GetAllCached()[1] end
for _, address in ipairs({ 'First-Realm', 'Second-Other' }) do assert(A.Recipients:SetFaction(address, 'Alliance')) end
dofile('YiboMail/RuleSendController.lua'); dofile('YiboMail/SendRulesSettings.lua'); dofile('YiboMail/RuleSendUI.lua')
local S, U, C = A.SendRulesSettings, A.RuleSendUI, A.RuleSendController
-- Login with a hidden mailbox must leave native mailbox controls uninitialized.
InboxFrame = CreateFrame('Frame', nil, MailFrame)
MailFrame.shown = false
A.NativeUI:Install(); A.NativeUI:Install()
assert(not A.NativeUI.installed and A.NativeUI.waitingForMailbox and showHooks == 1 and not U.root)
MailFrame.shown = true
MailFrame.numTabs, MailFrame.selectedTab = 2, 1
U:Install(); U:Open(); assert(U.active and U.root:IsShown() and not SendMailMailButton:IsShown())
assert(MailFrame.numTabs == 2 and MailFrame.selectedTab == 1 and secureCalls == 1)
U:SetActive(false); assert(not U.root:IsShown() and SendMailMailButton:IsShown())
-- Exercise every directed transition, including native page 2's early return.
local N, oldRefreshInbox = A.NativeUI, A.NativeUI.RefreshInbox
N.inbox = { mode = 'mail', scroll = CreateFrame('Frame'), filter = { menu = CreateFrame('Frame') }, menu = { menu = CreateFrame('Frame') } }
N.RefreshInbox = function() end
local nativeChanges = 0
InboxFrame:Show(); SendMailFrame:Hide()
SendMailNameEditBox:SetText('Draft-Realm'); SendMailSubjectEditBox:SetText('Draft subject')
function MailFrameTab_OnClick(_, page)
    if MailFrame.selectedTab == page then return end
    nativeChanges = nativeChanges + 1
    MailFrame.selectedTab = page
    InboxFrame:SetShown(page == 1); SendMailFrame:SetShown(page == 2)
end
local tabs = { 'mail', 'items', 'send', 'rules' }
local labels = { '收件箱', '附件箱', '发件箱', '规则寄' }
local function ClickTab(key)
    local tab = N.mailboxTabs[key]; tab:GetScript('OnClick')(tab)
end
for index, key in ipairs(tabs) do
    local tab = N.mailboxTabs[key]
    assert(tab:GetWidth() == (MailFrame:GetWidth() - 6) / 4 and tab:GetHeight() == A.Core.UITheme.Size.compact and tab.kind == 'secondary')
    assert(tab.label:GetText() == labels[index])
    assert(tab.points[1][2] == MailFrame and tab.points[1][3] == 'BOTTOMLEFT')
    assert(tab.points[1][4] == (index - 1) * (tab:GetWidth() + 2) and tab.points[1][5] == 0)
end
local originalMailboxWidth = MailFrame:GetWidth()
MailFrame:SetWidth(412); MailFrame.hooks.OnSizeChanged(MailFrame)
assert(N.mailboxTabs.rules.points[1][4] + N.mailboxTabs.rules:GetWidth() == 412)
assert(N.mailboxTabs.mail.points[1][4] == 0)
MailFrame:SetWidth(originalMailboxWidth); N:LayoutMailboxTabs()
assert(not MailFrameTab1:IsShown() and not MailFrameTab2:IsShown())
N:InstallMailboxTabs(); assert(N.mailboxTabs.rules == U.tab)
for _, from in ipairs(tabs) do
    for _, to in ipairs(tabs) do
        ClickTab(from)
        local previousChanges = nativeChanges
        ClickTab(to)
        local page = (to == 'send' or to == 'rules') and 2 or 1
        assert(N.activePage == page and MailFrame.selectedTab == page)
        assert(U.active == (to == 'rules') and U.root:IsShown() == (to == 'rules'))
        assert(N.send.recipientField.shown == (to ~= 'rules') and N.send.subjectField.shown == (to ~= 'rules'))
        assert(SendMailNameEditBox.shown == (to ~= 'rules') and SendMailSubjectEditBox.shown == (to ~= 'rules'))
        assert(MailEditBox.shown == (to ~= 'rules') and not MailEditBoxScrollBar.shown)
        assert(modernBody.shown == (to ~= 'rules'))
        assert(SendMailNameEditBox:GetText() == 'Draft-Realm' and SendMailSubjectEditBox:GetText() == 'Draft subject')
        assert(N.send.favoritesPanel:GetHeight() == MailFrame:GetHeight())
        assert(U.status:GetHeight() == 20 and U.action:GetHeight() == A.Core.UITheme.Size.compact)
        assert(N.mailboxTabs[to].indicator.shown)
        assert(SendMailMailButton:IsShown() == (to == 'send'))
        assert(InboxFrame:IsShown() == (page == 1) and SendMailFrame:IsShown() == (page == 2))
        if to == 'mail' or to == 'items' then assert(N.inbox.mode == to) end
        for _, key in ipairs(tabs) do assert(N.mailboxTabs[key].state == (key == to and 'selected' or 'default')) end
        if from == 'rules' and to == 'send' then assert(nativeChanges == previousChanges) end
    end
end
N:SelectMailboxTab('items'); N:SelectMailboxTab('send'); N:SelectMailboxTab('items')
N:RestoreBrowsePage(); assert(N.inbox.mode == 'items' and N.mailboxTabs.items.state == 'selected')
N:SelectMailboxTab('send'); assert(not MailEditBoxScrollBar:IsShown())
bodyScrollRange = 120; N:RefreshBodyScrollBar(); assert(MailEditBoxScrollBar:IsShown())
N:SelectMailboxTab('rules'); assert(not MailEditBoxScrollBar:IsShown())
N:SelectMailboxTab('send'); assert(MailEditBoxScrollBar:IsShown())
bodyScrollRange = 0; N:RefreshBodyScrollBar(); assert(not MailEditBoxScrollBar:IsShown())
N.inbox, N.RefreshInbox = nil, oldRefreshInbox
print('PASS: four aligned navigation tabs; all 16 transitions; compose fields restored with intact drafts; full-height shortcuts; compact rule footer; attachment-page restoration')
local parent = CreateFrame('Frame', nil, UIParent); parent:SetWidth(900)
local business, cache = CreateFrame('Frame', nil, parent), CreateFrame('Frame', nil, parent)
local host = { availableHeight = 500 }; host.refreshPanel = function() return S:Host(parent, host, business, cache, parent:GetWidth(), 376) end
assert(host.refreshPanel() == 420)
S:OpenTab('rules'); assert(S.panel:IsShown() and not business:IsShown() and not cache:IsShown())
S:Edit(); local p = S.panel
p.item:SetValue('1'); p.item:Resolve('select'); assert(S.draft.itemID == 1)
p.target:SetValue('First-Realm', true); p.save:GetScript('OnClick')(p.save)
assert(S.editID and A.db.sendRules[S.editID].recipient == 'First-Realm')
local id = S.editID
S.dirty = true; S:OpenTab('cache'); assert(S.tab == 'rules' and A.confirmation)
A.confirmation.OnAccept(); assert(S.tab == 'cache' and cache.ruleDelete:IsEnabled())
U:OpenSettings(id); assert(S.requestedTab == 'rules' and S.requestedRule == id)
host.refreshPanel(); assert(S.tab == 'rules' and S.editID == id)
parent:SetWidth(400); S.editing = true; host.refreshPanel(); assert(S.panel.list:IsShown() and S.panel.editor:IsShown())
-- Settings picker callbacks choose the editor recipient, without changing a native draft.
SendMailNameEditBox:SetText('Native-Realm')
p.contacts:GetScript('OnClick')(p.contacts)
local UPicker = A.RecipientUI; UPicker.popup.search:SetText('First'); UPicker:Select(UPicker:Entries()[1])
assert(S.draft.recipient == 'First-Realm' and SendMailNameEditBox:GetText() == 'Native-Realm')
-- A persistent editor on the left; plain grouped rules and search on the right.
local function Click(control) control:GetScript('OnClick')(control) end
Click(p.cancel); assert(S.dirty and A.confirmation)
A.confirmation.OnAccept(); assert(not S.editID and S.editing and p.editor:IsShown())
parent:SetWidth(1104); host.refreshPanel()
assert(p.editor.points[1][2] == 0 and p.list.points[1][2] > p.editor:GetWidth())
assert(p.editor.points[1][3] == p.list.points[1][3])
assert(not p.new and not p.filters and not p.more and not p.scope)
assert(p.editor:GetWidth() == math.floor((1104 - 24) * 0.58))
assert(not p.exclude:IsShown() and p.blockItem:IsShown() and p.blockSenderInput:IsShown())
local function FindRow(kind, predicate)
    for _, row in ipairs(p.rows) do if row:IsShown() and row.kind == kind and (not predicate or predicate(row)) then return row end end
end
local function SelectRow(row) row:GetScript('OnMouseUp')(row, 'LeftButton') end
local header = FindRow('group')
assert(header.group.recipient == 'First-Realm' and header.header:GetText() == 'First · 1 条')
assert(not header.header.kind and not header.add and not header.edit, 'Names are text; no per-group add or per-item edit buttons')
assert(header.fold.label:GetText() == '-' and header.toggle:GetChecked())
Click(header.fold); assert(S.collapsed['first-realm'] and not FindRow('rule') and p.editor:IsShown())
p.target:SetValue('Draft-Realm', true); local dirtyDraft = S.draft
Click(FindRow('group').fold); assert(S.draft == dirtyDraft and S.dirty and p.target:GetText() == 'Draft-Realm')
p.search:SetValue('First', true); assert(FindRow('rule'))
p.search:SetValue('', true); assert(FindRow('rule'))
SelectRow(FindRow('rule')); assert(A.confirmation and S.draft == dirtyDraft)
A.confirmation.OnAccept(); assert(S.editID == id and p.save.label:GetText() == '保存修改')
assert(FindRow('rule').icon.texture == A.SendRules:Icon(A.db.sendRules[id]))
local function OperationButton(picker)
    for _, group in ipairs(picker.controls) do
        if group.control ~= picker.input and group.control ~= picker.dropdown and group.control ~= picker.retry and group.control ~= picker.drop then return group.control end
    end
end
assert(p.item.drop:IsShown() and p.item.drop.label:GetText() == '拖放到此')
assert(OperationButton(p.item):GetWidth() == 72 and p.item.drop:GetWidth() == 80)
assert(OperationButton(p.item).points[1][3] == p.item.drop.points[1][3], 'Left-column picker actions share a line')
assert(p.item.input.points[1][3] == p.item.drop.points[1][3])
assert(p.target.points[1][3] == p.contacts.points[1][3] and p.contacts:GetWidth() == 96)
assert(p.kind.points[1][3] == p.item.points[1][3] and not p.kind.menu)
assert(p.item.input:GetHeight() == p.save:GetHeight())
Click(p.cancel); assert(not S.editID and p.save.label:GetText() == '添加规则')
p.target:SetValue('First-Realm', true); p.kind.onValueChanged('category'); p.class.onValueChanged(7); p.subclass.onValueChanged(7)
assert(p.excludeTitle:IsShown() and p.exclude.input:IsEnabled() and not p.item:IsShown())
p.exclude:SetValue('99'); Click(OperationButton(p.exclude)); assert(S.draft.excluded[99])
Click(p.excludes[1].remove); assert(not S.draft.excluded[99])
p.exclude:SetValue('99'); p.exclude:Resolve('add')
Click(p.save); local categoryID = S.editID
assert(categoryID and A.db.sendRules[categoryID].excluded[99] and not A.db.sendRules[categoryID].characters)
assert(p.editor:IsShown() and p.list:IsShown())
assert(FindRow('rule', function(row) return row.rule.id == categoryID end).icon.texture:find('INV_Ingot_02'))
-- The recipient gate preserves each rule's own enable flag and survives initialization.
A.SendRules:SetEnabled(categoryID, false); host.refreshPanel()
Click(FindRow('group').toggle)
assert(not A.SendRules:IsRecipientEnabled('First-Realm') and A.db.sendRules[id].enabled and not A.db.sendRules[categoryID].enabled)
A.SendRules:Initialize(); assert(not A.SendRules:IsRecipientEnabled('First-Realm'))
Click(FindRow('group').toggle)
assert(A.SendRules:IsRecipientEnabled('First-Realm') and A.db.sendRules[id].enabled and not A.db.sendRules[categoryID].enabled)
local catRow = FindRow('rule', function(row) return row.rule.id == categoryID end)
Click(catRow.toggle); assert(A.db.sendRules[categoryID].enabled and S.draft.enabled)
SelectRow(catRow); p.exclude:SetValue('101'); p.exclude:Resolve('add'); Click(p.cancel); A.confirmation.OnAccept()
assert(not A.db.sendRules[categoryID].excluded[101] and A.db.sendRules[categoryID].excluded[99] and not S.editID)
-- An unresolved item query cannot save the previous identity.
S:Edit(id); p.item.input:SetValue('4', true); Click(p.save)
assert(S.editID == id and A.db.sendRules[id].itemID == 1 and S.notice)
p.item:Resolve('add'); Click(p.save); assert(A.db.sendRules[id].itemID == 4)
Click(p.cancel); p.target:SetValue('First-Realm', true); p.item:SetValue('4'); p.item:Resolve('add'); Click(p.save)
assert(not S.editID and S.dirty and S.notice); Click(p.cancel); A.confirmation.OnAccept()
function GetCursorInfo() return 'item', 7 end
local cleared = false; function ClearCursor() cleared = true end
p.target:SetValue('First-Realm', true); p.item.drop:GetScript('OnReceiveDrag')(p.item.drop)
assert(cleared and S.draft.itemID == 7 and p.item.input:GetText() == '7'); Click(p.save); local dropID = S.editID
assert(A.db.sendRules[dropID].recipient == 'First-Realm')
A.SendRules:Delete(dropID); S.dirty=nil; Click(p.cancel)
for itemID = 10, 18 do assert(A.SendRules:Save({ kind = 'item', itemID = itemID, recipient = 'First-Realm' })) end
assert(A.SendRules:Save({ kind = 'item', itemID = 100, recipient = 'Second-Other' }))
host.availableHeight = 350; host.refreshPanel(); assert(#S.groupPages == 2 and p.next:IsShown())
local rendered = 0; for _, row in ipairs(p.rows) do if row:IsShown() and row.kind == 'rule' then rendered = rendered + 1 end end
assert(rendered == 11)
Click(p.next); assert(FindRow('group').header:GetText() == 'Second-Other · 1 条', 'Other-realm recipients retain the realm')
Click(FindRow('group').fold); assert(not FindRow('rule') and p.editor:IsShown())
p.search:SetValue('Second', true); assert(FindRow('rule'))
p.search:SetValue('', true); assert(not FindRow('rule') and S.page == 2)
Click(FindRow('group').fold)
SelectRow(FindRow('rule')); assert(S.editID and p.editor:IsShown())
Click(p.cancel); assert(not S.editID and S.page == 2)
-- Changing editor context invalidates late item loads.
local request, pending = A.Core.ItemResolver.Request
A.Core.ItemResolver.Request = function(_, _, callback) pending=callback; return {Cancel=function() end} end
S:Edit(id); p.item:SetValue('121'); p.item:Resolve('add'); S:Edit(categoryID)
pending({itemID=121,name='物品121'}); assert(S.draft.kind=='category' and S.draft.itemID~=121)
A.Core.ItemResolver.Request=request; Click(p.cancel)
parent:SetWidth(400); host.refreshPanel()
assert(p.editor:IsShown() and p.list:IsShown() and p.list.points[1][3] < -p.editor:GetHeight())
for _, group in ipairs(p.item.controls) do
    if group.control:IsShown() then local point=group.control.points[1]; assert(point[2]>=0 and point[2]+group.control:GetWidth()<=p.item:GetWidth()) end
end
p.kind.onValueChanged('category'); assert(p.exclude.input:IsEnabled() and not p.scope)
Click(p.cancel); A.confirmation.OnAccept()
local collapsed = S.collapsed; S.panel=nil; host.refreshPanel(); p=S.panel; assert(S.collapsed==collapsed)
assert(p.editor:IsShown())
S:OpenTab('business'); assert(business:IsShown() and host.refreshPanel()==420)
S:OpenTab('cache'); assert(cache:IsShown() and host.refreshPanel()==242)
S:OpenTab('rules')
print('PASS: persistent two-column editor/list; plain rows and icons; ASCII folding independent of drafts; recipient gate preserves individual flags; same-realm labels; category blacklist; single add/save action; async cancellation; paging/narrow bounds; other tabs unchanged')
-- Drag routes are deliberately distinct. Rule drag stores identity only.
function GetCursorInfo() return 'item', 2 end
local held = true
function ClearCursor() held = false end
function CursorHasItem() return held end
U.active = true; U:Drop({ address = 'Second-Other' }); assert(not held and A.confirmation)
A.confirmation.OnAccept()
local found
for _, rule in ipairs(A.SendRules:List()) do if rule.itemID == 2 then found = rule end end
assert(found and found.recipient == 'Second-Other')
-- Native drop stages one exact cursor stack and attempts at most one send.
U.active = false; held = true
SendMailSubjectEditBox:SetText(''); modernBody:SetText('')
local dropped, attempts = {}, 0
A.Compose.GetAttachments = function() return dropped end
function ClickSendMailItemButton() dropped = { { itemID = 2, quantity = 3, slot = 1 } }; held = false end
SendMailMailButton:SetScript('OnClick', function() attempts = attempts + 1; A.Compose.pendingSend = { recipient = SendMailNameEditBox:GetText() } end)
U:Drop({ address = 'Second-Other' })
assert(attempts == 1 and dropped[1].quantity == 3 and A.Compose.pendingSend.recipient == 'Second-Other')
held = true; U:Drop({ address = 'First-Realm' }); assert(attempts == 1 and SendMailNameEditBox:GetText() == 'Second-Other')
A.Compose.pendingSend = nil; dropped = {}; held = true; SendMailSubjectEditBox:SetText('')
SendMailMailButton:SetEnabled(false); U:Drop({ address = 'First-Realm' })
assert(attempts == 1 and #dropped == 1 and SendMailNameEditBox:GetText() == 'First-Realm')
print('PASS: mailbox rule tab and native send visibility; settings tabs, actual item picker and save; dirty-navigation confirmation, deep link, narrow list/editor; shared contact picker independent draft')
print('PASS: drag-to-rule confirmation; exact cursor stack native drop, one send attempt, pending guard and staged fallback')
print('PASS: hidden mailbox login defers initialization; addon tab avoids Blizzard name/template/registry writes; secure native-tab dispatch')

-- Core may replace a pooled settings row when changing navigation sections.
local replacement = CreateFrame('Frame', nil, UIParent); replacement:SetWidth(1104)
parent:Hide(); S.tab = 'rules'; S.dirty = nil
local replacementBusiness, replacementCache = CreateFrame('Frame', nil, replacement), CreateFrame('Frame', nil, replacement)
local replacementHost = { availableHeight = 500 }
replacementHost.refreshPanel = function() return S:Host(replacement, replacementHost, replacementBusiness, replacementCache, 1104, 376) end
replacementHost.refreshPanel()
assert(S.panel:GetParent() == replacement and S.panel:IsShown())
assert(S.panel.editor:IsShown() and S.panel.list:IsShown())
S.panel.contacts:GetScript('OnClick')(S.panel.contacts)
assert(A.RecipientUI.popup:IsShown() and A.RecipientUI.popup:GetFrameStrata() == 'FULLSCREEN_DIALOG')
assert(A.RecipientUI.dismiss.level < A.RecipientUI.popup.level)
A.RecipientUI:Hide()
print('PASS: compact input/action alignment, retained dropped ID; replaced settings host remains visible; shared address book above Core')

-- Global edits apply immediately and do not modify the open rule draft.
p = S.panel; S.dirty = nil
p.blockItem:SetValue('7'); p.blockItem:Resolve('add')
assert(A.db.sendBlacklist.items[7] and not S.dirty)
function GetCursorInfo() return 'item', 205 end
p.blockItem.drop:GetScript('OnReceiveDrag')(p.blockItem.drop)
assert(A.db.sendBlacklist.items[205] and not S.dirty)
assert(A.SendRules:SetBlockedItem(205, false)); S:Refresh()
Click(p.blockCurrent); assert(A.db.sendBlacklist.senders.a and not S.dirty)
p.blockSenderInput:SetValue('B-Other'); Click(p.blockSender)
assert(A.db.sendBlacklist.senders.b and p.blockSenderInput:GetText() == '')
p.blockSenderInput:SetValue('Missing-Realm'); Click(p.blockSender)
assert(S.blacklistNotice and not A.db.sendBlacklist.senders.missing)
for _, row in ipairs(p.blacklistRows) do
    if row:IsShown() and row.entry.kind == 'item' and row.entry.id == 7 then Click(row.remove); break end
end
assert(not A.db.sendBlacklist.items[7] and A.db.sendBlacklist.senders.a)
for itemID = 200, 208 do A.SendRules:SetBlockedItem(itemID, true) end
S:Refresh(); assert(p.blacklistNext:IsShown())
Click(p.blacklistNext); assert(S.blacklistPage == 2)
local visible = 0; for _, row in ipairs(p.blacklistRows) do if row:IsShown() then visible = visible + 1 end end
assert(visible <= 6)
print('PASS: global blacklist item/drop and sender/current-role actions; immediate save independent of rule draft; removal and bounded pagination')
S.dirty = nil; S:Edit()
p.target:SetValue('Unconfirmed-Realm', true)
assert(p.factionAlliance:IsShown() and p.factionHorde:IsShown())
Click(p.factionAlliance)
assert(A.Recipients:GetFaction('Unconfirmed-Realm') == 'Alliance' and not p.factionAlliance:IsShown())
p.contacts:GetScript('OnClick')(p.contacts, 'RightButton')
assert(p.factionHorde:IsShown()); Click(p.factionHorde)
assert(A.Recipients:GetFaction('Unconfirmed-Realm') == 'Horde' and not p.factionHorde:IsShown())
print('PASS: contextual faction confirmation and correction hidden after completion')
-- Unskinned Blizzard controls: retain interaction scripts, replace their art.
local function NativeArt(control, kind)
    local art = CreateFrame('Frame', nil, control)
    art.GetObjectType = function() return kind or 'Texture' end
    control.GetRegions = function() return art end
    return art
end
local parchment = NativeArt(MailEditBox)
local sendDecoration = NativeArt(SendMailFrame)
SendStationeryBackgroundLeft = CreateFrame('Frame', nil, MailEditBox)
SendStationeryBackgroundRight = CreateFrame('Frame', nil, MailEditBox)
SendMailMoneyInset = CreateFrame('Frame', nil, SendMailFrame)
SendMailMoneyBg = CreateFrame('Frame', nil, SendMailFrame)
SendMailMoneyFrame = CreateFrame('Frame', nil, SendMailFrame)
SendMailFrameLockSendMail = CreateFrame('Frame', nil, SendMailFrame)
SendMailMoney = CreateFrame('Frame', nil, SendMailFrame)
for _, unit in ipairs({ 'Gold', 'Silver', 'Copper' }) do
    local input = CreateFrame('EditBox', nil, SendMailMoney)
    _G['SendMailMoney' .. unit] = input
    input.nativeBorder = NativeArt(input)
    input.texture = CreateFrame('Frame', nil, input)
    input:SetText(unit == 'Gold' and '1234' or '12')
end
SendMailSendMoneyButton = CreateFrame('CheckButton', nil, SendMailFrame)
SendMailCODButton = CreateFrame('CheckButton', nil, SendMailFrame)
for _, radio in ipairs({ SendMailSendMoneyButton, SendMailCODButton }) do
    radio.nativeBorder = NativeArt(radio)
    radio.GetChecked = function(self) return self.checked end
end
SendMailSendMoneyButton.checked = true
local attachmentArt = NativeArt(SendMailAttachment1)
local slotClick, slotDrag = function() end, function() end
SendMailAttachment1:SetScript('OnClick', slotClick); SendMailAttachment1:SetScript('OnReceiveDrag', slotDrag)
local slotItem = true
local savedGetSendMailItem = GetSendMailItem
GetSendMailItem = function(index) if slotItem and index == 1 then return 'Ore', 100, 12345, 20 end end
N:SelectMailboxTab('send'); N:LayoutBasicSend()
assert(parchment:GetAlpha() == 0 and sendDecoration:GetAlpha() == 0 and attachmentArt:GetAlpha() == 0)
assert(not SendStationeryBackgroundLeft:IsShown() and not SendStationeryBackgroundRight:IsShown())
assert(not SendMailMoneyInset:IsShown() and not SendMailMoneyBg:IsShown() and not SendMailMoneyFrame:IsShown())
local skin = SendMailAttachment1.yiboMailAttachment
assert(skin and skin.icon:IsShown() and skin.count:GetText() == '20')
assert(SendMailAttachment1:GetScript('OnClick') == slotClick and SendMailAttachment1:GetScript('OnReceiveDrag') == slotDrag)
assert(SendMailFrameLockSendMail:GetFrameLevel() > skin:GetFrameLevel())
assert(SendMailMoneyGold:GetText() == '1234' and SendMailMoneyGold.nativeBorder:GetAlpha() == 0 and SendMailMoneyGold.texture:GetAlpha() == 1)
assert(SendMailSendMoneyButton.yiboMailRadio.mark:IsShown() and not SendMailCODButton.yiboMailRadio.mark:IsShown())
SendMailSendMoneyButton.checked, SendMailCODButton.checked = false, true
N:LayoutSendMoney(); assert(SendMailCODButton.yiboMailRadio.mark:IsShown() and not SendMailSendMoneyButton.yiboMailRadio.mark:IsShown())
N:SelectMailboxTab('rules'); assert(not MailEditBox.yiboMailBodySurface:IsShown() and not SendMailMoneyGold.yiboMailInput:IsShown())
assert(skin:IsShown())
N:SelectMailboxTab('send'); assert(MailEditBox.yiboMailBodySurface:IsShown() and SendMailMoneyGold:GetText() == '1234')
slotItem = false; N:RefreshSend(); assert(not skin.icon:IsShown() and skin.count:GetText() == '' and SendMailAttachment1.yiboMailAttachment == skin)
GetSendMailItem = savedGetSendMailItem
print('PASS: unskinned compose art suppressed; themed body, attachment quantity/empty states, input values and radio state; native slot scripts retained; rule visibility and modal layering')
-- Blizzard initially exposes only seven empty slots; Mail owns the full grid.
local savedAttachmentLimit = ATTACHMENTS_MAX_SEND
ATTACHMENTS_MAX_SEND = 12
for index = 2, 16 do
    _G['SendMailAttachment' .. index] = CreateFrame('Button', nil, SendMailFrame)
    _G['SendMailAttachment' .. index]:SetShown(index <= 7)
end
for _, tab in ipairs({ 'send', 'rules', 'send' }) do
    N:SelectMailboxTab(tab)
    for index = 1, 16 do
        local slot = _G['SendMailAttachment' .. index]
        assert(slot:IsShown() == (index <= 12))
        if index <= 12 then
            assert(slot.yiboMailAttachment)
            local point = slot.points[1]
            assert(point[4] == 8 + ((index - 1) % 8) * (slot:GetWidth() + 4))
            assert(point[5] == 80 + (1 - math.floor((index - 1) / 8)) * (slot:GetHeight() + 4))
        end
    end
    for index = 8, 12 do _G['SendMailAttachment' .. index]:Hide() end
    N:RefreshSend()
    for index = 8, 12 do assert(_G['SendMailAttachment' .. index]:IsShown()) end
end
ATTACHMENTS_MAX_SEND = savedAttachmentLimit
print('PASS: full 12-slot eight-plus-four send/rule grid; native seven-slot visibility refreshed; unsupported extra slots hidden')
