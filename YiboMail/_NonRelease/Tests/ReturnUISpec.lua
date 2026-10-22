-- Exercise the actual inbox surface and shared Core confirmation lifecycle.
dofile("YiboMail/_NonRelease/Tests/NativeInboxSpec.lua")
local A = YiboMail
local N, Q, S, P = A.NativeUI, A.Queue, A.Scanner, A.NativeUI.inbox
local current = { id = "return-ui", name = "Current", realm = "Realm" }
A.Core.Characters.GetCurrent = function() return current end
local item = { attachmentIndex = 1, variantKey = "item:1", quantity = 2, name = "Item", itemID = 1 }
local function Entry(index, cod, returnable)
    return { character = current, key = "return" .. index, actionable = cod == 0,
        restriction = "COD", mail = { inboxIndex = index, sender = "Sender", subject = "Mail " .. index,
        money = 0, cod = cod, attachments = { A.Copy(item), A.Copy(item) }, state = "observed",
        signature = "signature" .. index, canReturn = returnable, canReply = true } }
end
local entries = { Entry(1, 0, true), Entry(2, 50, true), Entry(3, 0, false) }
entries[1].mail.attachments[2].attachmentIndex = 4
entries[2].mail.attachments[2].attachmentIndex = 4
entries[3].mail.attachments[2].attachmentIndex = 4
A.ViewModel.GetMails = function() return entries end
A.Items.GetState = function() return { status = "known", currentCount = #entries, totalCount = #entries } end
S.IsOpen = function() return true end
S.ReadVisible = function()
    local mails = {}; for _, entry in ipairs(entries) do mails[#mails + 1] = entry.mail end
    return mails, #mails, #mails
end
S.ReadEntry = function(_, entry) return entry.mail end
GetInboxText = function() return "Letter" end
ReturnInboxItem = function() error("UI must dispatch through the queue") end
Q.state, Q.pending, Q.actions = "idle", nil, {}
N.deleting, P.keepTilesDuringQueue = nil, nil
MailFrame:Show(); InboxFrame:Show(); P:Show()
P.mode, P.options.search, P.options.kind, P.expanded, P.selection = "mail", "", "all", {}, {}
ACCEPT, CANCEL = "Confirm", "Cancel"
StaticPopupDialogs = {}
local shown, hideCount = nil, 0
StaticPopup_Show = function(name, text, _, data) shown = { name = name, text = text, data = data }; return shown end
StaticPopup_Hide = function() hideCount = hideCount + 1 end
dofile("YiboCore/UI/ItemConfirmation.lua")
local startCount, lastPlan = 0, nil
local start = Q.StartReturn
Q.StartReturn = function(_, plan) startCount, lastPlan = startCount + 1, plan; return true end
local function Click(control)
    assert(control:IsShown() and control:IsEnabled())
    control:GetScript("OnClick")(control)
end
local function Accept() StaticPopupDialogs[shown.name].OnAccept(nil, shown.data) end
local function Cancel() StaticPopupDialogs[shown.name].OnCancel(nil, shown.data) end
local function Select(...)
    P.selection = {}
    for _, index in ipairs({ ... }) do
        for _, action in ipairs(N:GetSelectableMailActions(entries[index])) do
            if action.actionable then P.selection[action.id] = true end
        end
    end
    N:RefreshInbox()
end
N:RefreshInbox(); assert(not P.returnMail:IsShown())
Select(1); assert(P.returnMail:IsShown() and P.returnMail:IsEnabled())
assert(P.returnMail.label:GetText() == "退信 1" and P.status:GetText() == "已选 1")
assert(P.status.points[#P.status.points][2] == P.returnMail)
Click(P.returnMail); assert(startCount == 0 and N.returnConfirmation)
assert(shown.text:find("退回 1 封", 1, true) and shown.text:find("整封邮件", 1, true))
Cancel(); assert(startCount == 0 and not N.returnConfirmation and next(P.selection))
Click(P.returnMail); Accept(); assert(startCount == 1 and #lastPlan.actions == 1)
print("PASS: button appears only with selection, counts letters, reserves footer space; single return confirms and cancellation preserves selection")

Select(1, 2, 3); Click(P.returnMail)
assert(startCount == 1 and shown.text:find("退回 2 封，跳过 1 封", 1, true))
assert(shown.text:find("原生邮箱不允许退回", 1, true))
Accept(); assert(startCount == 2 and #lastPlan.actions == 2 and lastPlan.skipped == 1)
assert(lastPlan.actions[1].original.cod == 50)
Select(2); assert(not P.collect:IsEnabled() and P.returnMail:IsEnabled())
print("PASS: batch click requires a second confirmation with exact eligible/skipped counts and reason; COD return selection never enables collection")

Select(3); assert(P.returnMail:IsShown() and not P.returnMail:IsEnabled())
Select(1); Click(P.returnMail); P.selection = {}; Accept()
assert(startCount == 2 and P.notice == A:T("RETURN.CHANGED"))
Select(1); Click(P.returnMail); S.generation = (S.generation or 0) + 1; Accept()
assert(startCount == 2)
Select(1); Click(P.returnMail); P:GetScript("OnHide")(P)
assert(not N.returnConfirmation and hideCount > 0); Accept(); assert(startCount == 2)
Select(1); Click(P.returnMail); N:OnEvent("MAIL_CLOSED"); Accept(); assert(startCount == 2)
Select(1); Click(P.returnMail); N.deleting = true; Accept(); assert(startCount == 2)
N.deleting = nil
print("PASS: all-ineligible selection disables return; changed selection, mailbox generation, hiding and closing invalidate confirmation")

Select(1); Q.state = "running"; N:RefreshInbox(); assert(not P.returnMail:IsEnabled())
Q.state, Q.pending = "paused", {}; N:RefreshInbox(); assert(not P.returnMail:IsEnabled())
Q.state, Q.pending = "idle", nil
P.notice = nil
Q.operation, Q.state, Q.completed, Q.message = "return", "paused", 1, "closed"
Q.actions = { { state = "success" }, { state = "unverified" }, { state = "pending" } }
N:RefreshInbox(); assert(P.status:GetText():find("成功 1 封，待核实 1 封，未执行 1 封", 1, true))
Q.operation, Q.state, Q.actions = nil, "idle", {}
entries[1].mail.auctionMail = true
Select(1); assert(P.rows[1].check:IsEnabled() and P.collect:IsEnabled() and not P.returnMail:IsEnabled())
local muted = A.Core.UITheme.Colors.muted
for channel = 1, 3 do assert(P.returnMail.label.textColor[channel] == muted[channel]) end
assert(P.returnMail.state == "disabled" and startCount == 2 and next(P.selection))
entries[3].mail.auctionMail = true
Select(1, 3); assert(P.collect:IsEnabled() and not P.returnMail:IsEnabled())
for channel = 1, 3 do assert(P.returnMail.label.textColor[channel] == muted[channel]) end
entries[3].mail.auctionMail = false
Select(1, 2); assert(P.returnMail:IsEnabled() and P.returnMail.state == "default")
for channel = 1, 3 do assert(P.returnMail.label.textColor[channel] == A.Core.UITheme.Colors.text[channel]) end
Click(P.returnMail)
assert(#N.returnConfirmation.text > 0 and shown.text:find("退回 1 封，跳过 1 封", 1, true))
assert(shown.text:find("拍卖行邮件不参与退信", 1, true))
Cancel(); entries[1].mail.auctionMail = false
print("PASS: single/all-auction selections disable return with muted text; collection stays enabled; mixed selection restores normal style and skips auction mail")
entries[1].mail.canReply = false
Select(1); assert(not P.returnMail:IsEnabled() and P.collect:IsEnabled())
Select(1, 2); assert(P.returnMail:IsEnabled()); Click(P.returnMail)
assert(shown.text:find("来源未确认", 1, true) and shown.text:find("退回 1 封，跳过 1 封", 1, true))
Cancel(); entries[1].mail.canReply = true
print("PASS: system/unverified sender disables return independently of auction detection while collection and mixed player return stay available")
for _, language in ipairs({ "en", "zh" }) do
    A.Core.Locale.language = language
    Select(1, 2); Click(P.returnMail)
    assert(not shown.text:find("RETURN.", 1, true))
    assert(P.returnMail:GetWidth() >= P.returnMail.label:GetStringWidth() + 20)
    Cancel()
end
P.mode = "items"; N:RefreshInbox(); assert(not P.returnMail:IsShown())
P.mode, P.selection = "mail", {}; N:RefreshInbox(); assert(not P.returnMail:IsShown())
Q.StartReturn = start
print("PASS: running/pending queues disable return; Chinese/English text and button widths verified; attachment tab and cleared selection hide the button")
