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
UIParent = Frame(); MailFrame = Frame(UIParent); InboxFrame = Frame(MailFrame); GameTooltip = Frame()
OpenMailFrame = Frame(UIParent); OpenMailFrame:Hide()
local openedLetters = 0
function OpenMail_Update()
    assert(OpenMailFrame.updateButtonPositions == true, "Native attachment layout must refresh on each open")
    openedLetters = openedLetters + 1; OpenMailFrame.updateButtonPositions = false
end
function ShowUIPanel(control) control:Show() end
function HideUIPanel(control) control:Hide() end
YiboCore = { Capabilities = { Register = function() end } }; dofile("YiboCore/UI/Theme.lua"); dofile("YiboCore/UI/Input.lua")
-- Keep the real dropdown/buttons; scroll geometry is outside this regression.
function YiboCore.UITheme:CreateScrollFrame(parent) return Frame(parent) end
dofile("YiboMail/Namespace.lua")
local Addon = YiboMail; Addon.Core = YiboCore
Addon.db = { settings = {} }
local current = { id = "char" }
Addon.Core.Characters = { GetCurrent = function() return current end }
local opened
Addon.Core.AccountView = { NotifyPageChanged = function() end, Toggle = function(_, page) opened = page end }
Addon.GetInboxPreferences = function() return { rememberFilters = false, selectItems = true, selectMoney = true } end
Addon.SelectByDefault = function() return true end
local first = { attachmentIndex = 1, variantKey = "item:A", quantity = 2, name = "A" }
local second = { attachmentIndex = 2, variantKey = "item:B", quantity = 3, name = "B" }
local mail = { signature = "sig", inboxIndex = 1, sender = "sender", subject = "subject", money = 100, cod = 0, attachments = { first, second } }
local entry = { character = current, key = "key", actionable = true, mail = mail }
Addon.ViewModel = {
    GetMails = function(_, _, options) return options.search == "missing" and {} or { entry } end,
    GetGroups = function() return {} end,
    ActionID = function(_, _, key, slot) return key .. ":" .. tostring(slot) end,
    Escape = function(_, value) return value end,
    Money = function(_, value) return tostring(value) end,
    Expiry = function() return "20 days" end,
    ExpiryColor = function() return 0.25, 0.9, 0.35 end,
}
Addon.Items = { GetState = function() return { currentCount = 1, totalCount = 1 } end }
Addon.Scanner = { updated = true, ReadVisible = function() return { mail } end, Signature = function() return "after" end }
GetTime = function() return 0 end
local calls = 0
TakeInboxMoney = function() calls = calls + 1 end
local takenSlot
TakeInboxItem = function(index, slot) assert(index == 1); calls = calls + 1; takenSlot = slot end
GetContainerNumFreeSlots = function() return 10, 0 end
local stubView = Addon.ViewModel
dofile("YiboMail/ViewModel.lua")
stubView.ItemBorder, stubView.AttachmentBorder = Addon.ViewModel.ItemBorder, Addon.ViewModel.AttachmentBorder
Addon.ViewModel = stubView
dofile("YiboMail/Inbox.lua"); dofile("YiboMail/Queue.lua"); dofile("YiboMail/NativeUI.lua")
local native, queue = Addon.NativeUI, Addon.Queue
native:CreateInbox(); native:RefreshInbox()
local panel = native.inbox
assert(panel.collect.label:GetText() == "收取")
local function Click(control) assert(control:IsShown() and control:IsEnabled()); control:GetScript("OnClick")(control) end
assert(panel.rows[1].summary:GetText():find("附件 2 个", 1, true) and panel.rows[1].detail:GetText():find("金币", 1, true))
assert(panel.rows[1].count:GetText() == "", "Multi-attachment envelopes must not display the first stack as their total")
mail.openedByUser = true; native:RefreshInbox()
assert(panel.rows[1].title.textColor[1] == 0.60 and panel.rows[1].detail.textColor[1] == 0.65)
mail.openedByUser, mail.wasRead = false, true; native:RefreshInbox()
assert(panel.rows[1].title.textColor[1] == 1 and panel.rows[1].detail.textColor[1] == 1)
mail.attachments = { first }; native:RefreshInbox()
assert(panel.rows[1].summary:GetText():find("附件 1 个", 1, true) and panel.rows[1].count:GetText() == "2")
mail.attachments, mail.money, mail.cod = {}, 0, 250; native:RefreshInbox()
assert(panel.rows[1].summary:GetText():find("附件 0 个", 1, true) and panel.rows[1].detail:GetText():find("付款", 1, true))
mail.attachments, mail.money, mail.cod = { first, second }, 100, 0; native:RefreshInbox()
local readCalls = 0
GetInboxText = function(index) assert(index == 1); readCalls = readCalls + 1 end
assert(not mail.openedByUser and readCalls == 0)
Click(panel.rows[1]); assert(panel.expanded.key and panel.used > 1 and openedLetters == 0)
assert(mail.openedByUser and readCalls == 1)
Click(panel.rows[1]); assert(not panel.expanded.key and openedLetters == 0)
assert(readCalls == 1, "Collapsing must not read the mail again")
panel.rows[1]:GetScript("OnClick")(panel.rows[1], "RightButton"); assert(openedLetters == 1 and OpenMailFrame:IsShown() and InboxFrame.openMailID == 1 and not panel.expanded.key)
Click(panel.rows[1]); assert(panel.expanded.key and OpenMailFrame:IsShown() and openedLetters == 1)
panel.rows[1]:GetScript("OnClick")(panel.rows[1], "RightButton"); assert(not OpenMailFrame:IsShown() and panel.expanded.key and openedLetters == 1)
panel.rows[1]:GetScript("OnClick")(panel.rows[1], "RightButton"); assert(OpenMailFrame:IsShown() and openedLetters == 2)
Click(panel.rows[1]); assert(not panel.expanded.key and OpenMailFrame:IsShown())
panel.rows[1]:GetScript("OnClick")(panel.rows[1], "RightButton"); assert(not OpenMailFrame:IsShown() and not panel.expanded.key)
local function Menu(value)
    Click(panel.menu)
    assert(panel.menu.menu:GetParent() == panel)
    assert(panel.menu.menu:GetFrameLevel() > panel.rows[1]:GetFrameLevel())
    native:SuppressInboxContent(); assert(panel.menu.menu:IsShown())
    for index, option in ipairs(panel.menu.options) do
        if option.value == value then Click(panel.menu.menu.buttons[index]); return end
    end
    error("Missing menu action: " .. value)
end
Menu("select"); assert(panel.selection["key:money"] and panel.selection["key:1"] and panel.selection["key:2"])
assert(panel.collect.label:GetText() == "收取（2）", "Attachment count excludes coins and stack quantity")
assert(panel.rows[1].check:GetCheckState() == "checked")
Click(panel.rows[1].check); assert(not next(panel.selection) and panel.rows[1].check:GetCheckState() == "unchecked")
Click(panel.rows[1]); Click(panel.rows[2].check)
assert(panel.selection["key:1"] and not panel.selection["key:2"] and not panel.selection["key:money"])
assert(panel.rows[1].check:GetCheckState() == "partial" and panel.expanded.key)
assert(panel.rows[2].check:GetHeight() == 46 and panel.rows[2].check:GetFrameLevel() > panel.rows[2]:GetFrameLevel())
Click(panel.rows[1].check); assert(panel.rows[1].check:GetCheckState() == "checked")
Click(panel.rows[1].check); assert(not next(panel.selection) and not panel.collect:IsEnabled())
native:Collect(); assert(panel.notice and calls == 0)
Menu("clear"); assert(queue.state == "idle")
Menu("sort"); assert(panel.options.sort == "inbox" and panel.notice)
local hasAccount
for _, option in ipairs(panel.menu.options) do if option.value == "account" then hasAccount = true end end
assert(hasAccount)
native:InboxMenuAction("account"); assert(opened == "mail-inbox")
panel.options.search = "missing"; Menu("select"); assert(not next(panel.selection) and panel.notice)
panel.options.search = ""; Menu("select")
local changed = Addon.Copy(mail); changed.attachments[1].attachmentIndex, changed.attachments[2].attachmentIndex = 2, 1
Addon.Scanner.ReadVisible = function() return { changed } end
Click(panel.collect); assert(panel.notice and calls == 0 and queue.state == "idle")
Addon.Scanner.ReadVisible = function() return { mail } end
Menu("clear"); Click(panel.rows[2].check)
assert(panel.collect.label:GetText() == "收取（1）")
Click(panel.collect); assert(queue.pending and calls == 1 and takenSlot == 1 and #queue.actions == 1)
assert(panel.rows[1].summary:IsShown() and panel.expanded.key and not panel.rows[2].check:IsEnabled())
native:Collect(); assert(calls == 1 and panel.notice)
Menu("pause"); assert(queue.state == "paused" and queue.pending)
local pausedActions = queue.actions
native:InboxMenuAction("clear"); assert(queue.actions == pausedActions and panel.notice)
panel.rows[2].check:GetScript("OnClick")(panel.rows[2].check); assert(panel.selection["key:1"])
queue.pending = nil; native:RefreshInbox(); Menu("clear"); assert(queue.state == "idle" and not next(panel.selection))
entry.actionable, entry.restriction = false, "同签名邮件：无法唯一定位"; native:RefreshInbox()
assert(not panel.rows[1].check:IsEnabled() and panel.rows[1].check:GetAlpha() == 0.45)
entry.actionable = true; native:RefreshInbox(); Click(panel.rows[1].check); Click(panel.rows[1].check); assert(not next(panel.selection))
local ok = queue:Start({}); assert(not ok and calls == 1)
-- COD attachment clicks open the native letter and delegate payment confirmation.
mail.cod, entry.actionable, entry.restriction = 250, false, "付款取信请使用原生邮箱"
panel.expanded.key = true; native:RefreshInbox()
local confirmations, availableMoney, lastPopup = 0, 1000
local originalOpenMailUpdate = OpenMail_Update
OpenMail_Update = function() originalOpenMailUpdate(); OpenMailFrame.cod = mail.cod end
OpenMailAttachment_OnClick = function(_, slot)
    assert(OpenMailFrame:IsShown() and InboxFrame.openMailID == 1 and slot == 1)
    confirmations = confirmations + 1
    lastPopup = availableMoney < OpenMailFrame.cod and "COD_ALERT" or "COD_CONFIRMATION"
end
assert(not panel.rows[1].check:IsEnabled() and not panel.rows[2].check:IsEnabled())
Click(panel.rows[2]); assert(lastPopup == "COD_CONFIRMATION" and confirmations == 1 and calls == 1)
Click(panel.rows[2]); assert(confirmations == 2 and OpenMailFrame:IsShown() and calls == 1)
availableMoney = 0; Click(panel.rows[2]); assert(lastPopup == "COD_ALERT" and calls == 1)
panel.rows[2]:GetScript("OnClick")(panel.rows[2], "RightButton"); assert(not OpenMailFrame:IsShown())
panel.rows[2]:GetScript("OnClick")(panel.rows[2], "RightButton"); assert(OpenMailFrame:IsShown())
local codGroup = { item = first, quantity = first.quantity, sources = { { entry = entry, item = first } } }
native:ItemTile(codGroup, 1, 6); assert(panel.tiles[1]:IsEnabled())
Click(panel.tiles[1]); assert(confirmations == 4 and calls == 1)
local staleCOD = Addon.Copy(mail); staleCOD.signature = "changed"
Addon.Scanner.ReadVisible = function() return { staleCOD } end
native:CollectCOD(entry, first); assert(confirmations == 4 and panel.notice)
Addon.Scanner.ReadVisible = function() return { mail } end
queue.pending = {}; native:CollectCOD(entry, first); assert(confirmations == 4)
queue.pending = nil; mail.cod, entry.actionable = 0, true
print("PASS: COD expanded attachment opens native letter; native payment and insufficient-funds paths; repeated clicks; right-click toggle; COD grid; stale/pending guards; no direct charge")
local savedAttachments, savedMoney = mail.attachments, mail.money
mail.attachments, mail.money = {}, 0; native:RefreshInbox()
assert(panel.rows[1].delete:IsShown() and not panel.rows[1].check:IsShown())
local deleted, canDelete = 0, true
InboxItemCanDelete = function() return canDelete end
DeleteInboxItem = function(index) assert(index == 1); deleted = deleted + 1 end
Click(panel.rows[1].delete); assert(deleted == 1 and not panel.rows[1].delete:IsEnabled())
assert(not OpenMailFrame:IsShown() and InboxFrame.openMailID == nil, "Deleting the open empty letter must not leave the next mail open")
native:DeleteEmptyMail(entry); assert(deleted == 1)
native.deleting = nil; canDelete = false; native:DeleteEmptyMail(entry); assert(deleted == 1)
canDelete = true; mail.money = 1; native:DeleteEmptyMail(entry); assert(deleted == 1)
mail.money, mail.attachments = savedMoney, savedAttachments; native:RefreshInbox()
assert(not panel.rows[1].delete:IsShown() and panel.rows[1].check:IsShown())
print("PASS: empty-mail X; native deletion permission; repeat-click guard; recheck contents; pooled row restores checkbox")
Addon.Items.Events = { Register = function() end }
SendMailFrame = Frame(MailFrame)
Addon.FEATURES.send = false -- This spec stubs only the inbox-side native widgets.
local originalHeight = MailFrame:GetHeight()
native:Install(); assert(native.installed and not native.send and not native.fillPreview)
assert(MailFrame:GetHeight() == originalHeight and not Addon.Compose and not Addon.Rules and not Addon.MailUI)
MailFrame.hooks.OnHide(); SendMailFrame.hooks.OnShow()
-- Quality comes from cached item data or a saved link, and pooled tiles reset it.
local qualityItem = { itemID = 123, itemLink = "|cff0070dd|Hitem:123|h[Rare]|h|r" }
local group = { item = qualityItem, quantity = 1, sources = {} }
local requested = 0
C_Item = { RequestLoadItemDataByID = function(id) assert(id == 123); requested = requested + 1 end }
GetItemInfo = function() return nil end
native:ItemTile(group, 1, 6); native:ItemTile(group, 1, 6)
local tile = native.inbox.tiles[1]
assert(tile.borderColor[1] == 0 and tile.borderColor[2] == 112 / 255 and tile.borderColor[3] == 221 / 255 and tile.borderColor[4] == 1)
assert(tile.icon.texCoord[1] == 0.08 and tile.icon.texCoord[2] == 0.92 and requested == 1)
local refreshed = 0
local refreshInbox = native.RefreshInbox
native.RefreshInbox = function() refreshed = refreshed + 1 end
native:OnEvent("GET_ITEM_INFO_RECEIVED", 999, true); assert(refreshed == 0)
native:OnEvent("GET_ITEM_INFO_RECEIVED", 123, true); assert(refreshed == 1 and not native.pendingItemInfo[123])
native.RefreshInbox = refreshInbox
ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
GetItemInfo = function() return "Epic", nil, 4 end
native:ItemTile(group, 1, 6); assert(tile.borderColor[1] == 0.64 and tile.borderColor[3] == 0.93)
group.item = {}; GetItemInfo = function() return nil end
native:ItemTile(group, 1, 6); assert(tile.borderColor[1] == 0.55 and tile.borderColor[4] == 1)
print("PASS: checkbox toggle/partial/pooling/hit area/layers/disabled guards; one-click selected-only collection; no automatic all-selection; atomic batch validation; original letter and dropdown operations")
print("PASS: attachment quality border; link fallback; item data arrival; pooled tile color reset; cropped icon")
