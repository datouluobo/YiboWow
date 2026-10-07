-- Real rule model, compose adapter and controller; no live mail is sent.
function CreateFrame() return {} end
dofile('YiboMail/Namespace.lua')
local A = YiboMail
local current = { id = 'a', name = 'A', realm = 'Realm', faction = 'Alliance' }
A.Core = { Characters = { GetCurrent = function() return current end, GetAllCached = function() return { current } end },
    AccountView = { NotifyPageChanged = function() end } }
A.db = { rules = { [9] = { recipient = 'Old-Realm' } }, sendRules = {}, sendRuleRevision = 0 }
A.Queue = { state = 'idle' }; A.Scanner = { IsOpen = function() return true end }
local bags, attached, cursor, sends, histories, hooks, clock = {}, {}, nil, 0, {}, {}, 1
NUM_BAG_SLOTS, ATTACHMENTS_MAX_SEND = 0, 2
local function Link(id) return '|Hitem:' .. id .. '|h[Item' .. id .. ']|h' end
function GetItemInfo(value)
    local id = tonumber(value) or tonumber(tostring(value):match('item:(%d+)'))
    if not id or id == 99 then return end
    return 'Item' .. id, Link(id), 1, 1, 1, 'Trade', 'Ore', 20, '', 123, 1, 7, id == 4 and 9 or 7
end
function GetItemClassInfo(id) if id == 7 then return 'Trade' end end
function GetItemSubClassInfo(class, id) if class == 7 and id == 7 then return 'Ore' elseif class == 7 and id == 9 then return 'Herb' end end
function GetTime() return clock end
function GetServerTime() return clock end
function GetContainerNumSlots() return 10 end
function GetContainerItemInfo(_, slot)
    local item = bags[slot]; if not item then return end
    return 123, item.quantity, false, nil, nil, nil, Link(item.id), nil, nil, item.id, false
end
function PickupContainerItem(_, slot) cursor = bags[slot]; bags[slot] = nil end
function CursorHasItem() return cursor ~= nil end
function ClickSendMailItemButton(slot, clear)
    if clear then
        local item = attached[slot]; if item then for i = 1, 10 do if not bags[i] then bags[i] = { id = item.id, quantity = item.quantity }; break end end end
        attached[slot] = nil
    else attached[slot], cursor = cursor, nil end
end
function GetSendMailItem(slot) local item = attached[slot]; if item then return 'Item' .. item.id, item.id, 123, item.quantity end end
function GetSendMailItemLink(slot) local item = attached[slot]; return item and Link(item.id) end
local function Box() return { text = '', SetText = function(self, text) self.text = text end, GetText = function(self) return self.text end } end
SendMailNameEditBox, SendMailSubjectEditBox = Box(), Box()
local modernBody = Box()
MailEditBox = { GetEditBox = function() return modernBody end }
SendMailBodyEditBox = nil
SendMailFrame = { IsShown = function() return true end }
function MailFrameTab_OnClick() end
function SendMailFrame_Update() end
SendMailMailButton = { IsEnabled = function() return true end, GetScript = function() return function()
    sends = sends + 1; hooks.SendMail(SendMailNameEditBox:GetText(), SendMailSubjectEditBox:GetText())
end end }
function SendMail() end
function hooksecurefunc(name, fn) hooks[name] = fn end
function A:AddHistory(_, history) histories[#histories + 1] = history end
A.FEATURES.account = false
dofile('YiboMail/Recipients.lua'); A.Recipients:Initialize()
dofile('YiboMail/Compose.lua'); dofile('YiboMail/SendRules.lua'); dofile('YiboMail/RuleSendController.lua')
local R, C = A.SendRules, A.RuleSendController
R:Initialize(); assert(A.db.rules[9] and #R:List() == 1); R:Initialize(); assert(#R:List() == 1)
A.db.sendRules = {}
local ok, category = R:Save({ kind = 'category', classID = 7, recipient = 'Warehouse-Realm', excluded = { [2] = true }, characters = { legacy = true } }); assert(ok)
assert(not A.db.sendRules[category].characters)
A.db.sendRules[category].characters = { legacy = true }
local _, item = R:Save({ kind = 'item', itemID = 2, recipient = 'Smith-Realm' }); assert(item)
local _, herb = R:Save({ kind = 'category', classID = 7, subclassID = 9, recipient = 'Herb-Realm' }); assert(herb)
bags = { { id = 1, quantity = 20 }, { id = 2, quantity = 8 }, { id = 3, quantity = 10 }, { id = 4, quantity = 7 }, { id = 1, quantity = 5 } }
for _, address in ipairs({ 'Warehouse-Realm', 'Smith-Realm', 'Herb-Realm', 'Other-Realm' }) do assert(A.Recipients:SetFaction(address, 'Alliance')) end
local match = C:Scan(); assert(#match.items == 5 and #match.conflicts == 0)
assert(match.groups[A.Recipients:Key('Warehouse-Realm')], 'Legacy sender restrictions do not filter account-wide rules')
assert(match.groups[A.Recipients:Key('Warehouse-Realm')].stacks == 3)
local skipped = R:Match(A.Compose:BagItems(), { [item] = true }); assert(#skipped.items == 4)
assert(not R:Save({ kind = 'item', itemID = 2, recipient = 'Other-Realm' }))
-- Runtime conflict protection handles incompatible imported data too.
A.db.sendRules.conflict = { id = 'conflict', kind = 'item', itemID = 2, recipient = 'Other-Realm', enabled = true }
match = C:Scan(); assert(#match.conflicts == 1 and #match.items == 4)
A.db.sendRules.conflict = nil
-- A specific category exclusion cannot fall through to the broad category.
A.db.sendRules[herb].excluded = { [4] = true }; match = C:Scan(); assert(#match.items == 4)
A.db.sendRules[herb].excluded = {}
A.Compose:Install()
local beforeRuleClicks = A.Copy(bags)
PickupContainerItem(0, 2); ClickSendMailItemButton(1)
SendMailSubjectEditBox:SetText('manual attachment subject')
local detach = ClickSendMailItemButton
ClickSendMailItemButton = function() end
assert(not C:Select({ kind = 'rule', value = category }) and #A.Compose:GetAttachments() == 1 and sends == 0)
ClickSendMailItemButton = detach
assert(C:Select({ kind = 'rule', value = category }) and SendMailNameEditBox:GetText() == 'Warehouse-Realm')
for _, attachment in ipairs(A.Compose:GetAttachments()) do assert(attachment.itemID ~= 2) end
assert(C:Select({ kind = 'rule', value = item }) and C.state == 'ready' and sends == 0)
SendMailSubjectEditBox:SetText('manually changed staged draft')
assert(C:Select({ kind = 'rule', value = category }) and C.state == 'ready' and sends == 0)
assert(C:Select({ kind = 'rule', value = category }) and C.state == 'sending' and sends == 1)
assert(not C:Select({ kind = 'rule', value = category }) and sends == 1)
attached = {}; SendMailSubjectEditBox:SetText('')
A.Compose:OnEvent('MAIL_SEND_SUCCESS'); C:OnEvent('MAIL_SEND_SUCCESS')
-- Keep the existing history scenarios independent of the rule-row scenario.
sends, histories = 0, {}
bags = beforeRuleClicks
C:OnEvent('MAIL_CLOSED')
assert(C:Contact('Warehouse-Realm')); assert(C.state == 'ready' and #A.Compose:GetAttachments() == 2 and sends == 0)
assert(SendMailNameEditBox:GetText() == 'Warehouse-Realm')
assert(C:Contact('Warehouse-Realm')); assert(C.state == 'sending' and sends == 1)
assert(not C:Primary() and not C:Contact('Smith-Realm') and sends == 1)
attached = {}; SendMailSubjectEditBox:SetText('')
A.Compose:OnEvent('MAIL_SEND_SUCCESS'); C:OnEvent('MAIL_SEND_SUCCESS')
assert(#histories == 1 and histories[1].state == 'in-transit' and #histories[1].ruleIDs > 0)
assert(C:Primary() and C.state == 'ready' and #A.Compose:GetAttachments() == 1 and sends == 1)
-- Switching target stages that target, without sending the previous packet.
assert(C:Contact('Smith-Realm')); assert(sends == 1 and SendMailNameEditBox:GetText() == 'Smith-Realm')
local originalSubject = SendMailSubjectEditBox:GetText()
SendMailSubjectEditBox:SetText('edited'); assert(not C:Send() and sends == 1)
assert(not C:Undo()); SendMailSubjectEditBox:SetText(originalSubject); assert(C:Undo())
assert(C:Skip(item)); match = C:Scan(); assert(not match.byRule[item])
assert(C:Skip(item, true)); assert(C.match.byRule[item])
assert(not C:Contact('Nobody-Realm') and #A.Compose:GetAttachments() == 0 and sends == 1)
assert(C:Contact('Smith-Realm')); assert(C:Send()); A.Compose:OnEvent('MAIL_FAILED'); C:OnEvent('MAIL_FAILED')
assert(C.state == 'invalid' and sends == 2); assert(not C:Primary() and sends == 2)
assert(C:Undo()); assert(C:Contact('Smith-Realm')); assert(C:Send()); clock = clock + 16; C:Tick()
assert(C.state == 'invalid' and not C:Primary() and sends == 3)
A.Compose:OnEvent('MAIL_CLOSED'); C:OnEvent('MAIL_CLOSED'); assert(not next(C.skipped) and C.state == 'idle')
-- Recipient gates affect matching without rewriting independent rule settings.
bags = { { id = 1, quantity = 20 }, { id = 2, quantity = 8 }, { id = 3, quantity = 10 }, { id = 4, quantity = 7 }, { id = 1, quantity = 5 } }
attached, cursor = {}, nil
SendMailSubjectEditBox:SetText(''); modernBody:SetText('')
assert(R:SetRecipientEnabled('Warehouse-Realm', false))
match = C:Scan(); assert(not match.groups[A.Recipients:Key('Warehouse-Realm')] and #match.items == 2)
assert(A.db.sendRules[category].enabled and A.db.sendRules[item].enabled)
R:Initialize(); assert(not R:IsRecipientEnabled('Warehouse-Realm'))
R:SetEnabled(category, false); R:SetRecipientEnabled('Warehouse-Realm', true)
match = C:Scan(); assert(not match.byRule[category] and A.db.sendRules[category].enabled == false)
R:SetEnabled(category, true); match = C:Scan(); assert(#match.items == 5)
assert(C:Contact('Warehouse-Realm') and C.state == 'ready')
R:SetRecipientEnabled('Warehouse-Realm', false)
assert(C.state == 'invalid' and not C:Send() and sends == 3, 'Master disable invalidates an already staged rule packet')
print('PASS: recipient gate persists, filters matching, preserves disabled individual rules, and prevents sending stale staged packets')
print('PASS: migration preserved; category/explicit precedence, exclusion without fallback, runtime conflicts, skip/restore; grouped packets and overflow; mixed controls, repeat-click exclusion, recipient switching; fingerprints, failed/timeout send without retry, one existing history')

-- Global blocks take precedence over item and category rules, and persist.
assert(C:Undo())
R:SetRecipientEnabled('Warehouse-Realm', true)
assert(R:SetBlockedItem(2, true)); match = C:Scan()
assert(#match.items == 4 and not match.byRule[item])
assert(R:SetBlockedItem(1, true)); match = C:Scan(); assert(#match.items == 2)
R:Initialize(); assert(A.db.sendBlacklist.items[1] and A.db.sendBlacklist.items[2])
assert(R:SetBlockedItem(1, false)); match = C:Scan(); assert(#match.items == 4)
assert(R:SetBlockedItem(2, false)); match = C:Scan(); assert(#match.items == 5)
assert(not R:SetBlockedSender('missing', true))
assert(R:SetBlockedSender(current.id, true)); match = C:Scan()
assert(#match.items == 0 and #match.conflicts == 0 and match.blockedSender)
R:Initialize(); assert(A.db.sendBlacklist.senders[current.id])
local identityChanged
A.Core.Events = { Register = function(_, event, _, callback) assert(event == 'CHARACTER_ID_CHANGED'); identityChanged = callback end }
R:Initialize(); assert(identityChanged)
identityChanged(R, 'a', 'renamed'); current.id = 'renamed'
assert(not A.db.sendBlacklist.senders.a and A.db.sendBlacklist.senders.renamed and C:Scan().blockedSender)
assert(R:SetBlockedSender(current.id, false)); assert(#C:Scan().items == 5)
current.id = 'a'
C:Undo(); attached = {}; SendMailSubjectEditBox:SetText(''); modernBody:SetText('')
assert(C:Contact('Warehouse-Realm') and C.state == 'ready')
R:SetBlockedSender(current.id, true)
assert(C.state == 'invalid' and not C:Send() and sends == 3)
R:SetBlockedSender(current.id, false)
print('PASS: global item/sender blocks precede every rule; persistence, unknown-sender validation, removal and staged-send invalidation')

assert(C:Undo()); C.scope, C.skipped = nil, {}; attached = {}
SendMailSubjectEditBox:SetText(''); modernBody:SetText('')
A.db.sendRules = {}; bags = { { id = 2, quantity = 8 } }
local opposing = { id = 'h', name = 'H', realm = 'Realm', faction = 'Horde' }
A.Core.Characters.GetAllCached = function() return { current, opposing } end
assert(A.Recipients:GetFaction('H-Realm') == 'Horde')
assert(not A.Recipients:SetFaction('H-Realm', 'Alliance'))
local _, allianceRule = R:Save({ kind = 'item', itemID = 2, recipient = 'Smith-Realm' })
local _, hordeRule = R:Save({ kind = 'item', itemID = 2, recipient = 'H-Realm' })
assert(allianceRule and hordeRule)
match = C:Scan(); assert(#match.items == 1 and match.byRule[allianceRule] and not match.byRule[hordeRule] and #match.conflicts == 0)
current.faction = 'Horde'; match = C:Scan()
assert(match.byRule[hordeRule] and not match.byRule[allianceRule])
current.faction = 'Alliance'; assert(C:Contact('Smith-Realm') and C.state == 'ready')
current.faction = 'Horde'; assert(not C:Send() and sends == 3 and C.state == 'invalid')
assert(C:Undo()); current.faction = 'Alliance'
assert(A.Recipients:SetFaction('Smith-Realm', 'Horde'))
assert(#C:Scan().conflicts == 0 and #C.match.items == 0)
local _, unknown = R:Save({ kind = 'item', itemID = 3, recipient = 'Unknown-Realm' }); assert(unknown)
bags = { { id = 2, quantity = 8 }, { id = 3, quantity = 9 } }
match = C:Scan(); assert(#match.items == 0 and #match.factionIssues == 1 and match.factionIssues[1].rule.id == unknown)
assert(A.Recipients:SetFaction('Unknown-Realm', 'Alliance')); match = C:Scan(); assert(#match.items == 1 and #match.factionIssues == 0)
assert(not R:Save({ kind = 'item', itemID = 3, recipient = 'Other-Realm' }))
A.Recipients:ObserveSuccessfulMail('Learned-Realm', 'Alliance', false); assert(not A.Recipients:GetFaction('Learned-Realm'))
A.Recipients:ObserveSuccessfulMail('Learned-Realm', 'Alliance', true); assert(A.Recipients:GetFaction('Learned-Realm') == 'Alliance')
assert(not A.Recipients:GetFaction('Failed-Realm'))
print('PASS: Core faction authority; opposite-faction duplicate rules and role switching; stale staged-send rejection; unknown confirmation and ordinary-mail evidence')
local _, broad = R:Save({ kind = 'category', classID = 7, recipient = 'Other-Realm' })
local _, uncertain = R:Save({ kind = 'item', itemID = 4, recipient = 'Mystery-Realm' })
assert(broad and uncertain)
bags = { { id = 4, quantity = 1 }, { id = 1, quantity = 2 } }
match = C:Scan(); assert(#match.items == 1 and match.items[1].itemID == 1 and #match.factionIssues == 1)
assert(match.factionIssues[1].rule.id == uncertain, 'Unconfirmed explicit ownership cannot fall through to a broad category')
bags = {}; assert(#C:Scan().factionIssues == 0, 'No confirmation noise for rules without matching bags')
local eventCallbacks, deferred = {}, {}
A.Core.Events.Register = function(_, event, _, callback) eventCallbacks[event] = callback end
C_Timer = { After = function(_, callback) deferred[#deferred + 1] = callback end }
A.Recipients:Initialize()
local revision = A.db.sendRuleRevision
eventCallbacks.DATA_DOMAIN_UPDATED(A.Recipients, { domainID = 'identity' })
assert(#deferred == 1 and A.db.sendRuleRevision == revision)
current.faction = 'Horde'; deferred[1]()
assert(A.db.sendRuleRevision > revision and C.state == 'invalid')
C_Timer = nil
print('PASS: unknown-rule priority reservation, only relevant confirmation rows, and deferred Core identity refresh')
-- Current Classic uses MailEditBox:GetEditBox(), without the legacy global.
C:OnEvent('MAIL_CLOSED'); attached = {}; SendMailSubjectEditBox:SetText('')
assert(A.Compose:GetBodyEditBox() == modernBody and SendMailBodyEditBox == nil)
modernBody:SetText('Manual body'); assert(not C:DraftEmpty())
local withBody = C:Fingerprint(); modernBody:SetText('')
assert(C:Fingerprint() ~= withBody)
local modernWrapper = MailEditBox; MailEditBox = nil
local fillOK, fillError = C:Fill()
assert(not fillOK and fillError == '当前客户端发件界面未就绪。' and C.state == 'idle' and #attached == 0)
MailEditBox = modernWrapper
A.Compose.draft = { recipient = 'Warehouse-Realm', subject = '', body = 'Modern body', copper = 0, cod = false }
assert(A.Compose:ApplyDraft() and modernBody:GetText() == 'Modern body')
MailEditBox, SendMailBodyEditBox = nil, Box()
A.Compose.draft.body = 'Legacy body'
assert(A.Compose:ApplyDraft() and SendMailBodyEditBox:GetText() == 'Legacy body')
print('PASS: Classic body adapter stages/sends/undoes without legacy global; body fingerprints and draft guards; missing fields do not enter filling; legacy draft compatibility')
