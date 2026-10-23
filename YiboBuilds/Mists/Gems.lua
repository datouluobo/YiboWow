local Addon = _G.YiboBuilds
if not Addon:HasCompatibleCore() then return end
local Gems = {}
Addon.Gems = Gems

local ORDINARY_GEM_SUBCLASSES = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [8] = true }
local ORDINARY_SOCKET_TYPES = { red = true, yellow = true, blue = true, prismatic = true }
-- A color subclass alone also includes uncut crafting materials.
-- Confirm socketability independently of recipe availability and client language.
function Gems:MatchesSocket(itemID, subclassID, socketType)
    if not (Addon.GemCatalog and Addon.GemCatalog[tonumber(itemID)]) then return false end
    -- Ordinary colors determine socket-bonus eligibility, not insertion validity.
    if ORDINARY_SOCKET_TYPES[socketType] then return ORDINARY_GEM_SUBCLASSES[subclassID] or false end
    if socketType == "meta" then return subclassID == 6 end
    if socketType == "sha" then return subclassID == 9 end
    return false
end

function Gems:BagCandidates(socketType)
    local candidates = {}
    if socketType == "unknown" then return candidates end
    local getCount = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local getInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if not (getCount and getLink and getInfo and GetItemInfo) then return candidates end
    for bag = 0, 4 do
        for bagSlot = 1, (getCount(bag) or 0) do
            local link = getLink(bag, bagSlot)
            if link then
                local name, _, _, _, _, _, _, _, _, icon, _, classID, subclassID = GetItemInfo(link)
                local itemID = tonumber(link:match("item:(%d+)"))
                if classID == 3 and self:MatchesSocket(itemID, subclassID, socketType) then
                    local info, count = getInfo(bag, bagSlot)
                    count = type(info) == "table" and info.stackCount or select(2, getInfo(bag, bagSlot))
                    candidates[#candidates + 1] = {
                        bag = bag, bagSlot = bagSlot, link = link, name = name or link,
                        icon = icon, count = tonumber(count) or 1,
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return (a.name or "") < (b.name or "") end)
    return candidates
end
