local Addon, Core = _G.YiboVault, _G.YiboCore

function Addon:TooltipSourceSnapshotAvailable(source, locations, available)
    if source == "bags" or source == "bank" then
        if not next(locations) then return false end
        for _, state in pairs(locations) do
            if not available(state, source) then return false end
        end
        return true
    end
    local key = source == "equipment" and "equipment" or source == "auction" and "auction" or "inbox"
    return available(locations[key], source)
end
