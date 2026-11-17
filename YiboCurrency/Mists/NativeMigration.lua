-- Translate the existing Mists snapshot shape into the shared discovery input.
-- This stages a directory only; callers decide when to commit it.
local Addon = _G.YiboCurrency
local Migration = {}; Addon.NativeMigration = Migration

function Migration:Stage(db, existing, stamp)
    if type(db) ~= "table" or type(db.characters) ~= "table" then return nil, "invalid-characters" end
    local facts, snapshots = {}, {}
    for characterID, record in pairs(db.characters) do
        if type(characterID) ~= "string" or type(record) ~= "table" then return nil, "invalid-character" end
        local snapshot = record.native
        if snapshot and type(snapshot) == "table" and type(snapshot.data) == "table"
            and type(snapshot.data.currencies) == "table" then
            local cells, values = {}, {}
            for id, cell in pairs(snapshot.data.currencies) do
                if type(cell) == "table" and (cell.state == "known" or cell.state == "stale") then
                    cells[id] = { name = cell.name, icon = cell.iconFileID, quantity = cell.quantity,
                        observedAt = cell.observedAt or snapshot.observedAt }
                    values[id] = { quantity = cell.quantity, observedAt = cell.observedAt or snapshot.observedAt,
                        state = "known" }
                end
            end
            facts[characterID] = cells
            snapshots[characterID] = Addon.NativeDiscovery:MergeSnapshot({}, values)
        end
    end
    return Addon.NativeDiscovery:ImportObserved(existing, facts, stamp), snapshots
end
