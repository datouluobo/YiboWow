local Addon = _G.YiboStage0Probe or {}
_G.YiboStage0Probe = Addon

Addon.NAME = "YiboStage0Probe"
Addon.VERSION = "0.1.5"
Addon.SCHEMA_VERSION = 1
Addon.MAX_SAMPLES = 400
Addon.MAX_EVENTS = 800
Addon.Runtime = Addon.Runtime or { bankOpen = false, guildBankOpen = false, auctionHouseOpen = false, mailOpen = false }
Addon.EVENT_NAMES = {
    "BAG_UPDATE",
    "BAG_UPDATE_DELAYED",
    "UNIT_INVENTORY_CHANGED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "GUILDBANKFRAME_OPENED",
    "GUILDBANKFRAME_CLOSED",
    "GUILDBANKBAGSLOTS_CHANGED",
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "OWNED_AUCTIONS_UPDATED",
    "MAIL_SHOW",
    "MAIL_CLOSED",
    "MAIL_INBOX_UPDATE",
    "GET_ITEM_INFO_RECEIVED",
}

function Addon:Now()
    if type(GetServerTime) == "function" then
        local value = GetServerTime()
        if type(value) == "number" and value > 0 then return value, "server" end
    end
    if type(time) == "function" then return time(), "client" end
    return os.time(), "client"
end

function Addon:Print(message)
    local text = "|cff20e070[Yibo Stage0]|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif type(print) == "function" then
        print(text)
    end
end

function Addon:IsFrameShown(frameName)
    local frame = _G[frameName]
    return frame and type(frame.IsShown) == "function" and frame:IsShown() == true
end

function Addon:GetFrameVisibility(frameNames)
    local result = {}
    for _, frameName in ipairs(frameNames or {}) do
        local frame = _G[frameName]
        result[frameName] = {
            exists = frame ~= nil,
            shown = self:IsFrameShown(frameName),
        }
    end
    return result
end

function Addon:IsBankOpen()
    if self.Runtime.bankOpen then return true end
    for _, frameName in ipairs({ "BankFrame", "BankPanel", "AccountBankPanel" }) do
        if self:IsFrameShown(frameName) then return true end
    end
    return false
end

function Addon:SafeCall(label, callable, ...)
    if type(callable) ~= "function" then
        return false, { label = label, error = "missing-api" }
    end
    local function Pack(...)
        return { n = select("#", ...), ... }
    end
    local packed = Pack(pcall(callable, ...))
    local ok = packed[1]
    if not ok then
        return false, { label = label, error = tostring(packed[2]) }
    end
    local results = { n = packed.n - 1 }
    for index = 2, packed.n do results[index - 1] = packed[index] end
    return true, results
end
