local Addon = _G.YiboAutoOpen
Addon.Target = { id = "Mists", savedVariable = "YiboAutoOpenDB",
    supported = type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC }

local tooltipName = "YiboAutoOpenContainerTooltip"
local tooltip
local PICK_LOCK_SPELL_ID = 1804
function Addon.Target.ReadContainerLock(bag, slot)
    if not tooltip then tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate") end
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)

    -- Only the bag-slot tooltip reflects whether this copy of the item is locked.
    local prefix = tooltipName .. "TextLeft"
    local title = _G[prefix .. "1"]
    local titleText = title and title:GetText()
    local lineCount = tooltip:NumLines()
    local locked
    if lineCount > 0 and titleText and titleText ~= RETRIEVING_ITEM_INFO then
        locked = false
        for index = 2, lineCount do
            local line = _G[prefix .. index]
            if line and line:GetText() == LOCKED then
                locked = true
                break
            end
        end
    end
    tooltip:Hide()
    return locked
end

function Addon.Target.GetContainerRescanDelay(event, unit, _, spellID)
    if event == "TRADE_CLOSED" or (event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == PICK_LOCK_SPELL_ID) then
        -- The bag tooltip can still show the old lock state when the event fires.
        return 0.5
    end
end

Addon.Target.catalog = {
    version = 1,
    defaultOrder = { 39883,44751,45724,199210,200239,200238,45328,46007,44113,52676,44663,54535,37586,54516,20393,34077,45072,34863,35348,33857,33844,25419,25423,35512,54536,52340,72201,90735,86623,87391,92960,95601,95602,90839,90840,98133,93724,95469,104272,104273 },
    -- These clams are spell-use items on MoP Classic. Calling their use action
    -- from an addon is forbidden, while ordinary container items remain safe.
    manualOnly = { [52340] = true, [24476] = true },
    excludedFromCatalog = { [24476] = true },
    migrations = {},
}
