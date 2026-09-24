local Addon = _G.YiboAutoOpen
local Safety = {}; Addon.Safety = Safety
local FRAME_BY_KEY = {
    merchant = { "MerchantFrame" },
    bank = { "BankFrame" },
    mail = { "MailFrame" },
    trade = { "TradeFrame" },
    auction = { "AuctionHouseFrame", "AuctionFrame" },
    guildbank = { "GuildBankFrame" },
    void = { "VoidStorageFrame" },
}
function Safety:SetSensitive(event, opened)
    local key = ({ MERCHANT_SHOW="merchant", BANKFRAME_OPENED="bank", MAIL_SHOW="mail", TRADE_SHOW="trade", AUCTION_HOUSE_SHOW="auction", GUILDBANKFRAME_OPENED="guildbank", VOID_STORAGE_OPEN="void" })[event]
    if key then Addon.runtime.sensitiveFrames[key] = opened == true end
end
function Safety:ReconcileSensitiveFrames()
    Addon.runtime.sensitiveFrames = Addon.runtime.sensitiveFrames or {}
    for key, frameNames in pairs(FRAME_BY_KEY) do
        local frame, known
        for _, frameName in ipairs(frameNames) do
            frame = _G[frameName]
            if frame then known = true; break end
        end
        if known then
            local visible
            if frame.IsVisible then visible = frame:IsVisible()
            elseif frame.IsShown then visible = frame:IsShown() end
            if visible ~= nil then Addon.runtime.sensitiveFrames[key] = visible == true end
        else
            -- These globals are available for the UI events supported by this
            -- client. A remembered event without its frame is stale state.
            Addon.runtime.sensitiveFrames[key] = nil
        end
    end
end
function Safety:CanRun()
    self:ReconcileSensitiveFrames()
    if not (Addon.db and Addon.db.enabled) then return false, "DISABLED" end
    if not Addon.runtime.loggedIn then return false, "PLAYER_UNAVAILABLE" end
    if Addon.runtime.worldLoading then return false, "WORLD_LOADING" end
    if InCombatLockdown and InCombatLockdown() then return false, "IN_COMBAT" end
    if UnitIsDeadOrGhost("player") or UnitInVehicle("player") then return false, "PLAYER_UNAVAILABLE" end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return false, "CASTING" end
    if LootFrame and LootFrame:IsShown() then return false, "LOOT_OPEN" end
    for _, open in pairs(Addon.runtime.sensitiveFrames) do if open then return false, "SENSITIVE_UI" end end
    local freeSlots, bagDataComplete = Addon.BagAdapter:GetGenericFreeSlots()
    if freeSlots < Addon.db.minFreeSlots and not bagDataComplete then return false, "BAG_DATA_PENDING" end
    if freeSlots < Addon.db.minFreeSlots then return false, "INSUFFICIENT_SPACE" end
    return true
end
