local Addon = _G.YiboAutoOpen
local Safety = {}; Addon.Safety = Safety
function Safety:SetSensitive(event, opened)
    local key = ({ MERCHANT_SHOW="merchant", BANKFRAME_OPENED="bank", MAIL_SHOW="mail", TRADE_SHOW="trade", AUCTION_HOUSE_SHOW="auction", GUILDBANKFRAME_OPENED="guildbank", VOID_STORAGE_OPEN="void" })[event]
    if key then Addon.runtime.sensitiveFrames[key] = opened == true end
end
function Safety:CanRun()
    if not (Addon.db and Addon.db.enabled) then return false, "DISABLED" end
    if not Addon.runtime.loggedIn then return false, "PLAYER_UNAVAILABLE" end
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
