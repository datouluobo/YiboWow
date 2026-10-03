local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
SlashCmdList = {}
YiboStage0ProbeDB = nil

local registeredEvents = {}
function CreateFrame()
    return {
        RegisterEvent = function(_, eventName) registeredEvents[eventName] = true end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
end

function GetServerTime() return 1790200000 end
function UnitName() return "PrivateCharacter" end
function GetRealmName() return "PrivateRealm" end
function GetBuildInfo() return "5.5.4", "60000", "Sep 24 2026", 50504 end

NUM_BAG_SLOTS = 1
NUM_BANKBAGSLOTS = 1
BANK_CONTAINER = -1
INVSLOT_FIRST_EQUIPPED = 1
INVSLOT_LAST_EQUIPPED = 2
ATTACHMENTS_MAX_RECEIVE = 2
MAX_GUILDBANK_SLOTS_PER_TAB = 2
C_Timer = { After = function(_, callback) callback() end }

local mockBankOpen = false
C_Container = {
    GetContainerNumSlots = function(bagID)
        if bagID == 0 then return 2 end
        if bagID == BANK_CONTAINER then return 2 end
        if bagID > NUM_BAG_SLOTS then return mockBankOpen and 1 or 0 end
        return 1
    end,
    GetContainerItemInfo = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then return { itemID = 100, stackCount = 5, hyperlink = "|Hitem:100:0:0:0|h[Test]|h" } end
        return nil
    end,
    GetContainerItemLink = function(bagID, slotID)
        if bagID == 0 and slotID == 1 then return "|Hitem:100:0:0:0|h[Test]|h" end
    end,
}

function GetInventoryItemID(_, slotID) return slotID == 1 and 200 or nil end
function GetInventoryItemLink(_, slotID) return slotID == 1 and "|Hitem:200:9:0:0|h[Gear]|h" or nil end

function GetNumGuildBankTabs() return 2 end
function GetCurrentGuildBankTab() return 1 end
function GetGuildBankTabInfo(tabID) return "PrivateTab" .. tabID, "icon", true, true, 10, 10 end
function GetGuildBankItemInfo(tabID, slotID) if slotID == 1 then return "icon", tabID + 2 end end
function GetGuildBankItemLink(tabID, slotID) if slotID == 1 then return "|Hitem:" .. (299 + tabID) .. ":0:0:0|h[Guild]|h" end end
function QueryGuildBankTab(tabID)
    YiboStage0Probe:HandleGuildBankSlotsChanged()
end

function GetInboxNumItems() return 1, 3 end
function GetInboxHeaderInfo()
    return "package", "stationery", "PrivateSender", "PrivateSubject", 10, 0, 4.5, 1, false, false, false, true, false
end
function GetInboxItem(_, attachmentIndex)
    if attachmentIndex == 1 then return "PrivateItemName", 400, "texture", 2, 3, true end
end
function GetInboxItemLink(_, attachmentIndex)
    if attachmentIndex == 1 then return "|Hitem:400:0:0:0|h[Mail]|h" end
end
function GetInboxInvoiceInfo() return "seller", "PrivateItemName", "PrivateBuyer", 10, 20, 1, 1 end

C_AuctionHouse = {
    GetOwnedAuctions = function()
        return { { auctionID = 7, itemKey = { itemID = 500 }, quantity = 4, buyoutAmount = 100 } }
    end,
    QueryOwnedAuctions = function(sortOrder)
        assert(type(sortOrder) == "table" and sortOrder[1].sortOrder == 1, "owned auction query uses the validated sort shape")
        YiboStage0Probe:HandleOwnedAuctionsUpdated()
    end,
}

local frames = { BankFrame = false, BankPanel = false, GuildBankFrame = true, AuctionHouseFrame = true, MailFrame = true }
for frameName in pairs(frames) do _G[frameName] = { IsShown = function() return true end } end
BankFrame.IsShown = function() return false end
BankPanel.IsShown = function() return false end

dofile("_NonRelease/YiboStage0Probe/Namespace.lua")
dofile("_NonRelease/YiboStage0Probe/Recorder.lua")
dofile("_NonRelease/YiboStage0Probe/VaultProbe.lua")
dofile("_NonRelease/YiboStage0Probe/MailProbe.lua")
dofile("_NonRelease/YiboStage0Probe/Commands.lua")
dofile("_NonRelease/YiboStage0Probe/Bootstrap.lua")

local Addon = YiboStage0Probe
Addon:InitializeDatabase()
local nilOK, nilResults = Addon:SafeCall("nil-shape", function() return 1, nil, 3 end)
assert(nilOK and nilResults.n == 3 and nilResults[1] == 1 and nilResults[2] == nil and nilResults[3] == 3, "SafeCall preserves nil return slots")
local battlePetLink = Addon:DescribeItemLink("|Hbattlepet:39:25:3:1400:260:260:0000000000000000|h[Pet]|h")
assert(battlePetLink.linkType == "battlepet" and battlePetLink.payloadHash and battlePetLink.itemID == nil, "non-item hyperlinks preserve their type and opaque payload")
local bags = Addon:ProbeBags()
assert(bags.containers[1].itemCount == 1, "bag probe should find the mocked item")
local equipment = Addon:ProbeEquipment()
assert(equipment.itemCount == 1, "equipment probe should find the mocked item")
local closedBank = Addon:ProbeBank()
assert(closedBank.accessible == false and closedBank.openEvidence == "none", "readable base bank slots do not prove the bank is open")
assert(closedBank.cachedContainersReadable == true and closedBank.containerExposure == "base-container-only", "closed bank exposure remains diagnostic only")
mockBankOpen = true
Addon.EventFrame.callback(Addon.EventFrame, "BANKFRAME_OPENED")
local bank = Addon:ProbeBank()
assert(bank.frameShown == false, "the native frame may be hidden by a replacement bag UI")
assert(bank.eventOpen == true and bank.accessible == true and bank.openEvidence == "event", "bank event is the primary open-state evidence")
assert(bank.containerExposure == "base-plus-bank-bags", "opening the bank exposes purchased bank bags")
local guildBank = Addon:ProbeGuildBank()
assert(guildBank.tabs[1].itemCount == 1, "guild bank probe should find the mocked item")
local allGuildBank = Addon:ProbeAllGuildBankTabs()
assert(allGuildBank.requestedTabs == 2 and allGuildBank.completedTabs == 2, "all-tab guild bank probe should query every viewable tab")
assert(allGuildBank.tabs[1].response == "event" and allGuildBank.tabs[2].response == "event", "all-tab queue advances on update events")
local auction = Addon:ProbeAuction(true)
local auctionSample = Addon.Session.samples[#Addon.Session.samples]
assert(auctionSample.kind == "vault.auction" and auctionSample.payload.itemCount == 1, "auction query reads owned auctions after the update event")
assert(auctionSample.payload.querySent == true and auctionSample.payload.response == "event", "auction query waits for its completion event")
local mail = Addon:ProbeMail()
assert(mail.coverage == "partial" and mail.unscannedCount == 2, "mail probe distinguishes partial coverage")
assert(mail.mails[1].header.sender.hash and mail.mails[1].header.subject.hash, "private mail strings are hashed")
assert(mail.mails[1].header.sender ~= "PrivateSender", "raw sender must not be retained")

Addon:HandleCommand("events on")
Addon:AddEvent("BAG_UPDATE", 0)
assert(#Addon.Session.events == 1, "event logging records enabled events")
Addon:HandleCommand("status")
assert(#Addon.Session.samples == 8, "all probe samples should be retained")
assert(registeredEvents.MAIL_INBOX_UPDATE and registeredEvents.BAG_UPDATE_DELAYED, "validation events should be registered")

print("YiboStage0Probe smoke passed")
