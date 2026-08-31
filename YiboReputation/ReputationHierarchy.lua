local Addon = _G.YiboReputation

-- Snapshot data is keyed by canonical faction ID in current schemas.  The
-- legacy fallback below is still useful for an irregular imported snapshot,
-- but it must not scan every faction for every catalog ID that is absent. A
-- weak cache keeps the derived index out of SavedVariables and vanishes when
-- Core replaces a snapshot.
Addon._factionLookupCache = Addon._factionLookupCache or setmetatable({}, { __mode = "k" })

local function LegacyFactionLookup(snapshot, factions)
    local lookup = Addon._factionLookupCache[snapshot]
    if lookup then return lookup end
    lookup = {}
    for _, data in pairs(factions) do
        if type(data) == "table" then
            local factionID = tonumber(data.factionID)
            if factionID then lookup[factionID] = data end
        end
    end
    Addon._factionLookupCache[snapshot] = lookup
    return lookup
end

function Addon:GetFactionData(snapshot, factionID)
    local factions = snapshot and snapshot.data and snapshot.data.factions
    if not factions then return nil end
    if (tonumber(snapshot.schemaVersion) or 0) < 3 then
        -- v1/v2 used faction-window row indices as keys. Never trust those
        -- numbers, but an exact localized name can safely project an existing
        -- value onto a canonical catalog faction for this client locale.
        local canonicalName = self:GetFactionName(factionID)
        if not canonicalName or string.find(canonicalName, "未知声望 ", 1, true) == 1 then return nil end
        local matched
        for _, data in pairs(factions) do
            if type(data) == "table" and data.name == canonicalName then
                if matched then return nil end -- ambiguous names are not migrated
                matched = data
            end
        end
        if matched then
            local projected = {}; for key, value in pairs(matched) do projected[key] = value end
            projected.factionID = tonumber(factionID)
            return projected
        end
        return nil
    end
    local direct = factions[factionID] or factions[tostring(factionID)]
    if direct then return direct end
    -- Older snapshots and some client APIs serialize map keys differently.
    -- The record's own factionID remains authoritative. Build that fallback
    -- index once per snapshot instead of repeatedly walking all factions.
    return LegacyFactionLookup(snapshot, factions)[tonumber(factionID) or factionID]
end

function Addon:GetFactionState(snapshot, factionID)
    if not snapshot then return "not-yet-scanned" end
    if (tonumber(snapshot.schemaVersion) or 0) < 4 or not (snapshot.data and snapshot.data.contractVersion) then return "not-yet-scanned" end
    if self:GetFactionData(snapshot, factionID) then return "known" end
    local statuses = snapshot.data and snapshot.data.statuses or {}
    return statuses[factionID] or statuses[tostring(factionID)] or "not-yet-scanned"
end

local function FactionNode(addon, id, data, key)
    return { key = key or ("faction:" .. id), kind = "faction", factionID = id,
        title = addon:GetFactionName(id, data and data.name), icon = addon:GetFactionIcon(id), data = data, children = {} }
end

function Addon:GetTreeNodes(snapshot)
    local nodes, seen = {}, {}
    local factions = snapshot and (tonumber(snapshot.schemaVersion) or 0) >= 3 and snapshot.data and snapshot.data.factions or {}
    local function Make(id, key, guildName)
        local data = self:GetFactionData(snapshot, id)
        if not data then return nil end
        if self:GetFactionState(snapshot, id) == "unavailable" then return nil end
        if guildName and (not data or data.name ~= guildName) then return nil end
        local node = FactionNode(self, id, data, key)
        if guildName then node.title = guildName; node.guildName = guildName end
        return node
    end
    for expansionIndex = #self.Catalog, 1, -1 do
        local expansion = self.Catalog[expansionIndex]
        local expansionNode = { key = expansion.id, title = expansion.title, kind = "expansion", children = {} }
        for _, category in ipairs(expansion.categories) do
            if category.primaryFactionID then
                local primaryID = category.primaryFactionID
                local group = Make(primaryID, "group:" .. expansion.id .. ":" .. category.id)
                seen[primaryID] = true
                if group then for _, id in ipairs(category.factions) do
                    if id ~= primaryID and not seen[id] then
                        seen[id] = true
                        local child = Make(id)
                        if child then group.children[#group.children + 1] = child end
                    end
                end end
                if group then expansionNode.children[#expansionNode.children + 1] = group end
            elseif category.guild then
                seen[1168] = true
                local data = self:GetFactionData(snapshot, 1168)
                if data and data.name and data.name ~= "" then
                    local guild = Make(1168, "guild:" .. data.name, data.name)
                    if guild then expansionNode.children[#expansionNode.children + 1] = guild end
                end
            else
                local categoryNode = { key = expansion.id .. ":" .. category.id, title = category.title, kind = "category", children = {} }
                for _, id in ipairs(category.factions) do
                    if not seen[id] then
                        seen[id] = true
                        local faction = Make(id)
                        if faction then categoryNode.children[#categoryNode.children + 1] = faction end
                    end
                end
                if category.flat then
                    for _, faction in ipairs(categoryNode.children) do expansionNode.children[#expansionNode.children + 1] = faction end
                elseif #categoryNode.children > 0 then expansionNode.children[#expansionNode.children + 1] = categoryNode end
            end
        end
        if #expansionNode.children > 0 then nodes[#nodes + 1] = expansionNode end
    end

    local function FindExpansion(title)
        for _, node in ipairs(nodes) do if node.title == title then return node end end
        local node = { key = "detected:" .. tostring(title), title = title, kind = "expansion", children = {} }
        nodes[#nodes + 1] = node
        return node
    end
    local function FindCategory(expansionNode, title)
        for _, node in ipairs(expansionNode.children) do if node.kind == "category" and node.title == title then return node end end
        local node = { key = expansionNode.key .. ":detected:" .. tostring(title), title = title, kind = "category", children = {} }
        expansionNode.children[#expansionNode.children + 1] = node
        return node
    end
    for id, data in pairs(factions) do
        local stableID = tonumber(type(data) == "table" and data.factionID) or tonumber(id) or id
        if not seen[stableID] then
            seen[stableID] = true
            local metadata = self:ResolveFactionMetadata(stableID, data)
            local expansionNode = FindExpansion(metadata.expansionTitle or "其它")
            local categoryNode = FindCategory(expansionNode, metadata.categoryTitle or "其它阵营")
            local node = FactionNode(self, stableID, data)
            if not string.find(node.title, "未知声望 ", 1, true) then categoryNode.children[#categoryNode.children + 1] = node end
        end
    end
    for _, expansionNode in ipairs(nodes) do
        for _, categoryNode in ipairs(expansionNode.children or {}) do
            if categoryNode.kind == "category" and string.find(categoryNode.key, ":detected:", 1, true) then
                table.sort(categoryNode.children, function(a, b) return a.title < b.title end)
            end
        end
    end
    return nodes
end
