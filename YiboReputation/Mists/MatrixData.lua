local Addon = _G.YiboReputation
Addon.MatrixExtraFields = { { id = "session", label = "MATRIX.FIELD_SESSION", defaultVisible = true } }
local function Faction(snapshot, id) return Addon:GetFactionData(snapshot, id) end

local function FactionData(Snapshot, id, characters, guildName, guildRealm)
    for _, character in ipairs(characters) do
        local data = Faction(Snapshot(character), id)
        if data and (not guildName or data.name == guildName)
            and (not guildRealm or tostring(character.realm or "") == tostring(guildRealm)) then return data end
    end
end

function Addon:IsMonitored(factionID)
    for _, id in ipairs(self:GetSettings().monitoredFactionIDs) do if id == factionID then return true end end
    return false
end
function Addon:ToggleMonitored(factionID)
    local list = self:GetSettings().monitoredFactionIDs
    for index, id in ipairs(list) do if id == factionID then table.remove(list, index); self:NotifyChanged(); return true end end
    if #list >= 10 then self:Print(self:T("MATRIX.ADD_LIMIT")); return nil end
    list[#list + 1] = factionID; self:NotifyChanged(); return true
end

function Addon:GetMatrixNodes(characters, Snapshot)
    local nodes, seen = {}, {}
    local function MakeFaction(id, key, guildName, guildRealm)
        local data = FactionData(Snapshot, id, characters, guildName, guildRealm)
        -- Do not manufacture rows for catalog IDs absent from every retained
        -- snapshot.  Those only produce “未知声望 ####” and add no comparison
        -- value; a future scan will naturally add the row when data exists.
        if not data then return nil end
        local available = false
        for _, character in ipairs(characters) do
            local snapshot = Snapshot(character)
            if self:GetFactionState(snapshot, id) ~= "unavailable" and (not guildName or (Faction(snapshot, id) and Faction(snapshot, id).name == guildName))
                and (not guildRealm or tostring(character.realm or "") == tostring(guildRealm)) then available = true; break end
        end
        if not available then return nil end
        return { key = key or ("matrix:faction:" .. id), kind = "faction", factionID = id, guildName = guildName, guildRealm = guildRealm,
            title = guildName and (guildName .. " · " .. tostring(guildRealm or self:T("MATRIX.UNKNOWN_REALM"))) or self:GetFactionName(id, data and data.name),
            icon = self:GetFactionIcon(id), children = {} }
    end
    for expansionIndex = #self.Catalog, 1, -1 do
        local expansion = self.Catalog[expansionIndex]
        local node = { key = "matrix:" .. expansion.id, kind = "expansion", title = self:GetExpansionTitle(expansion), defaultExpanded = expansion.id == "mop", children = {} }
        for _, category in ipairs(expansion.categories) do
            if category.primaryFactionID then
                local primary = MakeFaction(category.primaryFactionID, "matrix:group:" .. expansion.id .. ":" .. category.id); seen[category.primaryFactionID] = true
                if primary then for _, id in ipairs(category.factions) do if id ~= category.primaryFactionID and not seen[id] then seen[id] = true; local child=MakeFaction(id);if child then primary.children[#primary.children + 1] = child end end end end
                -- The primary faction is both the group label and the real
                -- reputation.  Rendering a category wrapper here created an
                -- identical extra level for 黑王子、阡陌客 and 垂钓翁.
                if primary then node.children[#node.children + 1] = primary end
            elseif category.guild then
                seen[1168] = true
                local guilds = {}
                for _, character in ipairs(characters) do
                    local data = Faction(Snapshot(character), 1168)
                    if data and data.name and data.name ~= "" then
                        local realm = tostring(character.realm or self:T("MATRIX.UNKNOWN_REALM"))
                        local key = realm .. "\31" .. data.name
                        guilds[key] = { name = data.name, realm = realm }
                    end
                end
                local guildKeys = {}; for key in pairs(guilds) do guildKeys[#guildKeys + 1] = key end; table.sort(guildKeys)
                for _, identity in ipairs(guildKeys) do
                    local guildIdentity = guilds[identity]
                    local guild = MakeFaction(1168, "matrix:guild:" .. identity, guildIdentity.name, guildIdentity.realm)
                    if guild then node.children[#node.children + 1] = guild end
                end
            else
                local container = { key = node.key .. ":" .. category.id, kind = "category", title = self:GetCategoryTitle(expansion, category), children = {} }
                for _, id in ipairs(category.factions) do if not seen[id] then seen[id] = true; local faction=MakeFaction(id);if faction then container.children[#container.children + 1] = faction end end end
                if category.flat then for _, faction in ipairs(container.children) do node.children[#node.children+1]=faction end elseif #container.children > 0 then node.children[#node.children + 1] = container end
            end
        end
        if #node.children > 0 then nodes[#nodes + 1] = node end
    end
    local facts = {}
    for _, character in ipairs(characters) do
        local snapshot = Snapshot(character)
        local trustworthy = snapshot and (tonumber(snapshot.schemaVersion) or 0) >= 3
        for id, data in pairs((trustworthy and snapshot.data and snapshot.data.factions) or {}) do
            local stableID = tonumber(type(data) == "table" and data.factionID) or tonumber(id) or id
            if not facts[stableID] then facts[stableID] = data end
        end
    end
    local function FindExpansion(title)
        for _, node in ipairs(nodes) do if node.title == title then return node end end
        local node = { key="matrix:detected:"..tostring(title), kind="expansion", title=title, children={} }
        nodes[#nodes + 1] = node
        return node
    end
    local function FindCategory(expansionNode, title)
        for _, node in ipairs(expansionNode.children) do if node.kind=="category" and node.title==title then return node end end
        local node = { key=expansionNode.key..":detected:"..tostring(title), kind="category", title=title, children={} }
        expansionNode.children[#expansionNode.children + 1] = node
        return node
    end
    for stableID, data in pairs(facts) do
        if not seen[stableID] then
            seen[stableID] = true
            local metadata = self:ResolveFactionMetadata(stableID, data)
            local expansionNode = FindExpansion(metadata.expansionTitle or self:T("MATRIX.OTHER"))
            local categoryNode = FindCategory(expansionNode, metadata.categoryTitle or self:T("MATRIX.OTHER_FACTIONS"))
            local title = self:GetFactionName(stableID,data.name)
            if not self:IsUnknownFactionName(title) then categoryNode.children[#categoryNode.children + 1] = { key="matrix:faction:"..stableID, kind="faction", factionID=stableID, title=title, icon=self:GetFactionIcon(stableID), children={} } end
        end
    end
    for _, expansionNode in ipairs(nodes) do
        for _, categoryNode in ipairs(expansionNode.children or {}) do
            if categoryNode.kind=="category" and string.find(categoryNode.key,":detected:",1,true) then table.sort(categoryNode.children,function(a,b)return a.title<b.title end) end
        end
    end
    return nodes
end


function Addon:GetMatrixExpansion()
    return self:EnsureDB().matrixExpanded
end

function Addon:GetMonitoredFactions()
    return self:GetSettings().monitoredFactionIDs
end

function Addon:HasMatrixSnapshot(character)
    local snapshot = self:GetSnapshot(character.id)
    return snapshot and snapshot.state ~= "unavailable" and snapshot.data
        and type(snapshot.data.factions) == "table" and next(snapshot.data.factions) ~= nil
end

function Addon:GetMatrixFaction(snapshot, node, character)
    local data = self:GetFactionData(snapshot, node.factionID)
    if node.guildName and (not data or data.name ~= node.guildName) then return nil end
    if node.guildRealm and node.guildRealm ~= tostring(character.realm or "") then return nil end
    return data
end

function Addon:GetMatrixCell(snapshot, node, character)
    if snapshot and snapshot.state == "error" then return { state = "error" } end
    if snapshot and snapshot.state == "unavailable" then return { state = "unavailable" } end
    if snapshot and ((tonumber(snapshot.schemaVersion) or 0) < 5 or not (snapshot.data and snapshot.data.contractVersion)) then
        return { state = "rescan" }
    end
    local data = self:GetMatrixFaction(snapshot, node, character)
    if not data then
        local state = self:GetFactionState(snapshot, node.factionID)
        return { state = (node.guildName or state == "unavailable") and "unavailable" or "missing" }
    end
    local state = snapshot.state == "stale" and "stale" or nil
    local session = not state and self.Scanner:GetSessionChange(character.id, data)
    local friend = self:GetFriendship(data)
    if friend then
        local current, minimum, maximum = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
        local friendshipTotal = self:GetSettings().showFriendshipTotal and tonumber(friend.totalMax)
        if friendshipTotal and friendshipTotal > 0 then minimum, maximum = 0, friendshipTotal end
        return { state = state, observedAt = snapshot.updatedAt, session = session, rankLabel = data.factionID == 1359 and self:GetNomiDisplay(data) or friend.name,
            colorRank = friend.rank and math.min(8, friend.rank + 2),
            current = current and minimum and current - minimum, maximum = maximum and minimum and maximum - minimum,
            complete = self:IsComplete(data), completeLabel = self:T("FRIENDSHIP.FALLBACK_6") }
    end
    local value, minimum, maximum = tonumber(data.value), tonumber(data.min), tonumber(data.max)
    return { state = state, observedAt = snapshot.updatedAt, session = session, rank = tonumber(data.standingID),
        current = value and minimum and value - minimum, maximum = maximum and minimum and maximum - minimum,
        complete = self:IsComplete(data) }
end

function Addon:BindMatrixRow(row, node, characters)
    self.GoalTargets:BindRow(row, node, characters)
end

function Addon:RefreshCurrentReputation()
    self:ScanCurrent("manual")
end
