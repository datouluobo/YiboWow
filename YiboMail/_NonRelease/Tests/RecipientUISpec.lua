-- Run from the repository root: lua YiboMail/_NonRelease/Tests/NativeInboxSpec.lua
local methods = {}
methods.SetJustifyV = function() end
methods.SetWordWrap = function() end
methods.SetVertexColor = function() end
methods.SetTextInsets = function() end
function methods:SetHitRectInsets(...) self.hitRect = { ... } end
local function Frame(parent)
    local control = setmetatable({ parent = parent, children = {}, shown = true, enabled = true, width = 340, height = 400, level = parent and parent.level + 1 or 1, scripts = {}, points = {}, alpha = 1 }, { __index = methods })
    if parent then parent.children[#parent.children + 1] = control end
    return control
end
for _, name in ipairs({ "SetBackdrop", "EnableMouse", "SetJustifyH", "SetFont", "SetAllPoints", "SetAutoFocus", "SetMaxLetters", "RegisterForClicks", "SetTexture", "SetDesaturated", "SetOwner", "SetHyperlink", "AddLine", "Raise", "ClearFocus", "SetChecked", "SetColorTexture", "SetToplevel", "SetTextColor", "SetBackdropColor", "SetBackdropBorderColor" }) do methods[name] = function() end end
function methods:GetChildren() return unpack(self.children) end
function methods:SetTexCoord(...) self.texCoord = { ... } end
function methods:SetBackdropBorderColor(...) self.borderColor = { ... } end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:GetRegions() return end
function methods:GetParent() return self.parent end
function methods:SetParent(parent)
    for i, child in ipairs(self.parent.children) do if child == self then table.remove(self.parent.children, i); break end end
    self.parent = parent; parent.children[#parent.children + 1] = self
end
function methods:GetAlpha() return self.alpha end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(v) self.level = v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameStrata(v) self.strata = v end
function methods:SetText(v) self.text = v end
function methods:GetText() return self.text or "" end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k, v) self.hooks = self.hooks or {}; self.hooks[k] = v end
function methods:CreateFontString() return Frame() end
function methods:CreateTexture() return Frame() end
function methods:SetShown(v) self.shown = v end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetEnabled(v) self.enabled = v end
function methods:IsEnabled() return self.enabled end
function methods:SetScrollChild(v) self.child = v end
function methods:SetContentHeight(v) self.contentHeight = v end
function methods:SetVerticalScroll(v) self.offset = v end
function CreateFrame(_, _, parent) return Frame(parent) end

function methods:SetClampedToScreen() end
function methods:RegisterEvent() end
function methods:SetFocus() self.focused = true end
function methods:ClearFocus() self.focused = false end
function methods:HighlightText() end
function methods:GetLeft() return self.left or 400 end
function methods:GetRight() return self.right or 430 end
function methods:GetTop() return self.top or 600 end
function methods:GetBottom() return self.bottom or 572 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetText(value)
    self.text = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    if self.hooks and self.hooks.OnTextChanged then self.hooks.OnTextChanged(self) end
end
function methods:Hide()
    local shown = self.shown; self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
UIParent = Frame(); UIParent:SetSize(1280, 720)
MailFrame = Frame(UIParent); MailFrame:SetSize(420, 540)
SendMailFrame = Frame(MailFrame); GameTooltip = Frame(); UISpecialFrames = {}
SendMailNameEditBox = Frame(SendMailFrame); SendMailSubjectEditBox = Frame(SendMailFrame); SendMailBodyEditBox = Frame(SendMailFrame)
SendMailMailButton = Frame(SendMailFrame); SendMailCancelButton = Frame(SendMailFrame)
STANDARD_TEXT_FONT = 'font'; date = os.date
YiboCore = {}; dofile('YiboCore/UI/Theme.lua'); dofile('YiboMail/Namespace.lua')
local A = YiboMail; A.Core = YiboCore
local current = { id = 'a', name = 'A', realm = 'Realm' }
local other = { id = 'b', name = 'B', realm = 'Other' }
A.Core.Characters = { GetCurrent = function() return current end, GetAllCached = function() return { current, other } end }
A.Core.AccountView = { GetVisibleCharacters = function() return { current, other } end }
A.ViewModel = { Escape = function(_, s) return s end }
A.db = { contacts = { { address = 'First-Realm' }, { address = 'Second-Other' } } }
local attachments, sends = {}, 0
A.Compose = { GetAttachments = function() return attachments end }
SendMailMailButton:SetScript('OnClick', function(_, button) assert(button == 'LeftButton'); sends = sends + 1 end)
A.Print = function() end
function SendMailFrame_Update() end
function GetServerTime() return 1000 end
dofile('YiboMail/Recipients.lua'); dofile('YiboMail/RecipientUI.lua'); dofile('YiboMail/NativeUI.lua')
local R, U, N = A.Recipients, A.RecipientUI, A.NativeUI
R:Initialize(); N:CreateBasicSend(); N:RefreshBasicSend()
local function Click(control, mouse) assert(control:IsEnabled()); control:GetScript('OnClick')(control, mouse or 'LeftButton') end
local panel = N.send
N:LayoutBasicSend()
assert(SendMailNameEditBox:GetParent() == panel.recipientField, 'Recipient EditBox must belong to its visible field')
assert(SendMailNameEditBox:GetFrameLevel() > panel.recipientField:GetFrameLevel(), 'Recipient EditBox must render and receive clicks above its opaque field background')
assert(SendMailSubjectEditBox:GetParent() == panel.subjectField, 'Subject EditBox must belong to its visible field')
assert(SendMailSubjectEditBox:GetFrameLevel() > panel.subjectField:GetFrameLevel(), 'Subject EditBox must render and receive clicks above its opaque field background')
SendMailNameEditBox:SetText('Draft-Realm'); SendMailSubjectEditBox:SetText('Subject'); SendMailBodyEditBox:SetText('Body')
Click(panel.favoriteButtons[3]); assert(SendMailNameEditBox:GetText() == 'Draft-Realm' and sends == 0 and not N.favoriteEditor)
Click(panel.favoriteButtons[3], 'RightButton'); assert(U.slot == 3 and U.popup:IsShown())
assert(U:Entries()[1].custom and #U:Entries() == 7 and U.popup:GetHeight() <= 360)
U:Select({ source = 'contacts' }); assert(U.slot == 3 and U.source == 'contacts')
U:Select(U:Entries()[1]); assert(A.db.quickRecipients[3].address == 'First-Realm')
assert(SendMailNameEditBox:GetText() == 'Draft-Realm' and SendMailSubjectEditBox:GetText() == 'Subject' and sends == 0)
Click(panel.favoriteButtons[3]); assert(SendMailNameEditBox:GetText() == 'First-Realm' and sends == 0)
local recipientLevel, subjectLevel = SendMailNameEditBox:GetFrameLevel(), SendMailSubjectEditBox:GetFrameLevel()
N:LayoutBasicSend()
assert(SendMailNameEditBox:GetText() == 'First-Realm' and SendMailSubjectEditBox:GetText() == 'Subject', 'Send layout refresh must preserve the native draft fields')
assert(SendMailNameEditBox:GetFrameLevel() == recipientLevel and SendMailSubjectEditBox:GetFrameLevel() == subjectLevel, 'Repeated layout must keep stable input frame levels')
attachments = { { itemID = 1 } }; Click(panel.favoriteButtons[3]); assert(sends == 1)
attachments = {}; Click(panel.favoriteButtons[3], 'RightButton'); Click(U.popup.action)
assert(A.db.quickRecipients[3] and U.confirm); Click(U.popup.action)
assert(not A.db.quickRecipients[3] and A.db.quickRecipients[2] and #A.db.contacts == 2)
Click(panel.favoriteButtons[16], 'RightButton'); U:Select({ custom = true })
assert(N.favoriteEditor.slot == 16 and not U.popup:IsShown())
N.favoriteEditor.address:SetText('Custom'); N:SaveFavoriteFromEditor()
assert(A.db.quickRecipients[16].address == 'Custom-Realm' and #A.db.contacts == 2 and sends == 1)
SendMailNameEditBox:SetText('Draft-Realm'); Click(panel.contacts)
assert(not U.slot and U.popup:IsShown() and not U.popup.manage:IsEnabled())
assert(U.popup:GetWidth() == 200, 'Source menu should keep its compact width')
Click(U.popup.action); assert(R:FindContact('Draft') and #A.db.contacts == 3)
Click(U.popup.action); assert(U.confirm)
SendMailNameEditBox:SetText('Changed-Realm'); assert(not U.confirm)
Click(U.popup.action); assert(R:FindContact('Changed') and R:FindContact('Draft'))
SendMailNameEditBox:SetText('Draft-Realm'); Click(U.popup.action); Click(U.popup.action)
assert(not R:FindContact('Draft') and SendMailNameEditBox:GetText() == 'Draft-Realm')
SendMailNameEditBox:SetText(''); assert(not U.popup.action:IsEnabled())
for i=1,100 do R:SaveContact('Long'..i) end
U:Select({source='contacts'}); assert(U.pageCount > 1 and U.popup:GetHeight() <= 360)
assert(U.home:IsShown() and U.home:GetWidth() == 200 and U.popup:GetWidth() == 200)
assert(not U.popup.back:IsShown() and U.popup.search.points[1][2] == 6, 'Source list should give the search field the available header width')
assert(U.popup.points[1][4] == U.home.points[1][4] + 204, 'Source list should expand to the right')
local pooled = #U.popup.rows
Click(U.popup.next); assert(U.page == 2 and #U.popup.rows == pooled)
U.popup.search:SetText('Long100'); assert(U.page == 1 and #U:Entries() == 1)
assert(U.popup.rows[1].entry.address == 'Long100-Realm' and U.popup:GetHeight() < 360)
Click(U.popup.rows[1]); assert(SendMailNameEditBox:GetText() == 'Long100-Realm' and sends == 1)
Click(panel.contacts); U.popup.search:SetText('Second'); assert(#U:Entries() == 1 and #U:Entries()[1].sources == 1)
U.popup.search:GetScript('OnEscapePressed')(U.popup.search); assert(U.popup:IsShown() and U.popup.search:GetText() == '')
U.popup.search:GetScript('OnEscapePressed')(U.popup.search); assert(not U.popup:IsShown() and not U.dismiss:IsShown())
Click(panel.contacts); U:Select({source='contacts'}); Click(U.popup.filter)
local realms=U:Entries(); local chosen
assert(not U.popup.back:IsShown() and U.popup.filter.label:GetText() == '‹ 返回名单')
for _, entry in ipairs(realms) do if entry.realm == 'Other' then chosen=entry end end
assert(chosen); U:Select(chosen); assert(U.realm == 'Other' and #U:Entries() == 1)
-- Invalidated data must not leave a stale address selectable.
local stale=U:Entries()[1]; R:RemoveContact(stale.address); U:Select(stale)
assert(SendMailNameEditBox:GetText() == 'Long100-Realm')
Click(panel.favoriteButtons[1], 'RightButton'); panel.favoriteButtons[1].left=1200; panel.favoriteButtons[1].right=1230
U:Refresh(); assert(U.popup.points[1][4] < 1200 and U.popup.points[1][4] >= 12)
Click(U.dismiss); assert(not U.popup:IsShown())
Click(panel.contacts)
U.popup.rows[1]:GetScript('OnEnter')(U.popup.rows[1])
assert(U.source == 'contacts' and U.home:IsShown(), 'Hover should open the source submenu')
panel.contacts.left, panel.contacts.right = 1160, 1190
U:Refresh()
assert(U.popup.points[1][4] + U.popup:GetWidth() < U.home.points[1][4], 'Submenu should flip left at the screen edge')
Click(U.dismiss); assert(not U.home:IsShown())
panel.contacts.left, panel.contacts.right = nil, nil
-- Search covers every source even while an unrelated category is expanded.
R:RecordRecent('First-Realm')
R:CommitFriends(current, { 'LocalBuddy' }, true)
R:CommitFriends(other, { 'AccountBuddy' }, true)
R.guild = { { address = 'GuildOnly-Other' }, { address = 'First-Realm' } }; R:Changed()
Click(panel.contacts); U:Select({ source = 'characters' })
U.popup.search:SetText('GuildOnly')
assert(#U:Entries() == 1 and U:Entries()[1].sources[1] == '公会')
Click(U.popup.rows[1]); assert(SendMailNameEditBox:GetText() == 'GuildOnly-Other' and sends == 1)
Click(panel.contacts); U:Select({ source = 'characters' }); U.popup.search:SetText('First')
assert(#U:Entries() == 1 and #U:Entries()[1].sources == 3, 'Global search must merge contacts, recent and guild by address')
Click(U.home.rows[6]); assert(U.source == 'guild' and U.popup.search:GetText() == 'First' and #U:Entries() == 1)
U.popup.search:SetText('LocalBuddy'); assert(#U:Entries() == 1 and U:Entries()[1].sources[1] == '角色好友')
U.popup.search:SetText('AccountBuddy'); assert(#U:Entries() == 1 and U:Entries()[1].sources[1] == '账号好友')
Click(U.popup.filter)
local globalRealm
for _, entry in ipairs(U:Entries()) do if entry.realm == 'Other' then globalRealm = entry end end
assert(globalRealm, 'Server filter must include matching realms from every source')
U:Select(globalRealm); assert(#U:Entries() == 1)
U.popup.search:SetText('LocalBuddy'); assert(#U:Entries() == 0, 'An explicit server filter still applies to global search')
U.realm = nil; U.popup.search:SetText('B-Other'); assert(#U:Entries() == 1 and U:Entries()[1].sources[1] == '账号角色')
U.popup.search:SetText(''); assert(U.source == 'guild' and #U:Entries() == 2)
U:Hide()
Click(panel.contacts); panel:GetScript('OnHide')(); assert(not U.popup:IsShown() and not N.favoriteEditor:IsShown())
print('PASS: shared picker independent callbacks; right-click custom/sources/clear; left-click native send contract; dynamic contact actions; confirmations; all-source search; filter/paging/pooling; bounds/Esc/dismiss/lifecycle; stale result guard')
