local Addon = _G.YiboBuilds
local Store = Addon.Store
local Talents = { generation = 0 }
Addon.Talents = Talents

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and Store:Plain(value) then return value end
end

local function ID(value)
    return Store:Integer(value, 1, 2147483647)
end

local function IsRank(value)
    return Store:Integer(value, 0, 2147483647)
end

local function Array(value, allowEmpty)
    if not Store:Plain(value) or type(value) ~= "table" or (#value == 0 and not allowEmpty) then return false end
    local count = 0
    for key in pairs(value) do
        if not Store:Integer(key, 1, #value) then return false end
        count = count + 1
    end
    return count == #value
end

function Talents:Valid(row)
    if type(row) ~= "table" or not Store:Integer(row.observedAt, 0, 9007199254740991)
        or not Array(row.trees) then return false end
    local seenTrees = {}
    for _, tree in ipairs(row.trees) do
        if type(tree) ~= "table" or not ID(tree.id) or seenTrees[tree.id]
            or not Store:Integer(tree.points, 0, 2147483647) or not Array(tree.nodes, true) then return false end
        seenTrees[tree.id] = true
        local seenNodes = {}
        for _, node in ipairs(tree.nodes) do
            if type(node) ~= "table" or not ID(node.id) or seenNodes[node.id] or not ID(node.rank)
                or (node.spellID ~= nil and not ID(node.spellID)) then return false end
            seenNodes[node.id] = true
        end
    end
    return true
end

local function ActiveConfig()
    return Read(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
end

local function MayReadConfig(configID)
    local hasStagedChanges = C_Traits and C_Traits.ConfigHasStagedChanges
    return type(hasStagedChanges) ~= "function" or Read(hasStagedChanges, configID) == false
end

local function ReadDefinition(definitionID)
    return Read(C_Traits and C_Traits.GetDefinitionInfo, definitionID)
end

local function ReadDefinitionID(configID, node)
    if not Array(node.entryIDs) then return nil end
    local entryID = node.entryIDs[1]
    if #node.entryIDs > 1 then
        local committed = node.entryIDsWithCommittedRanks
        if not Array(committed) or #committed ~= 1 or not ID(committed[1]) then return nil end
        entryID = nil
        for _, candidate in ipairs(node.entryIDs) do
            if ID(candidate) and candidate == committed[1] then entryID = candidate; break end
        end
    end
    if not ID(entryID) then return nil end
    local entry = Read(C_Traits.GetEntryInfo, configID, entryID)
    if type(entry) == "table" and ID(entry.definitionID) then return entry.definitionID end
end

local function ReadNodeDetails(configID, id, node)
    local details = { id = id }
    if IsRank(node.currentRank) then details.currentRank = node.currentRank end
    if IsRank(node.maxRanks) then details.maxRanks = node.maxRanks end
    details.definitionID = ReadDefinitionID(configID, node)
    local definition = details.definitionID and ReadDefinition(details.definitionID)
    if type(definition) == "table" and ID(definition.spellID) then details.spellID = definition.spellID end
    return details
end

local function Coordinate(value)
    return Store:Plain(value) and type(value) == "number" and value >= -1000000 and value <= 1000000
end

local function ReadGraphNode(details, node)
    if not Coordinate(node.posX) or not Coordinate(node.posY) then return nil end
    local targets, seen = {}, {}
    if Array(node.visibleEdges, true) then
        for _, edge in ipairs(node.visibleEdges) do
            local target = Store:Plain(edge) and type(edge) == "table" and edge.targetNode
            if ID(target) and target ~= details.id and not seen[target] then
                targets[#targets + 1] = target
                seen[target] = true
            end
        end
        table.sort(targets)
    end
    return { id = details.id, x = node.posX, y = node.posY, spellID = details.spellID,
        definitionID = details.definitionID, currentRank = details.currentRank, maxRanks = details.maxRanks, targets = targets }
end

function Talents:GetGraph(tree)
    -- Older snapshots may have ranks without coordinates.
    if not Array(tree.graph) then return nil end
    local seen = {}
    for _, node in ipairs(tree.graph) do
        if type(node) ~= "table" or not ID(node.id) or seen[node.id]
            or not Coordinate(node.x) or not Coordinate(node.y) or not Array(node.targets, true)
            or (node.spellID ~= nil and not ID(node.spellID)) then return nil end
        for _, target in ipairs(node.targets) do if not ID(target) then return nil end end
        seen[node.id] = true
    end
    for _, node in ipairs(tree.nodes) do if not seen[node.id] then return nil end end
    return tree.graph
end

function Talents:GetName(node)
    local spellID = node.spellID
    local name = spellID and (Read(C_Spell and C_Spell.GetSpellName, spellID) or Read(GetSpellInfo, spellID))
    if type(name) == "string" and name ~= "" then return name end
    return Addon:T("FOREVER.TALENT_NODE_ID", node.id)
end

local function Text(value)
    return Store:Plain(value) and type(value) == "string" and value ~= "" and value or nil
end

function Talents:GetDescription(node)
    local definition = ID(node.definitionID) and ReadDefinition(node.definitionID)
    local override = type(definition) == "table" and Text(definition.overrideDescription)
    if override then return override end
    local spellID = node.spellID
    if not ID(spellID) then return nil end
    return Text(Read(C_Spell and C_Spell.GetSpellDescription, spellID)) or Text(Read(GetSpellDescription, spellID))
end

function Talents:RequestDescription(node)
    local request=C_Spell and C_Spell.RequestLoadSpellData
    if not ID(node.spellID) or type(request)~="function" then return false end
    local ok,result=pcall(request,node.spellID)
    return ok and Store:Plain(result) and result~=false
end

function Talents:GetRankText(node, investedRank)
    local current = IsRank(node.currentRank) and node.currentRank or nil
    local maximum = IsRank(node.maxRanks) and node.maxRanks or nil
    if not current and not maximum then return Addon:T("FOREVER.TALENT_RANK_VALUE", investedRank) end
    local unknown = Addon:T("FOREVER.TALENT_RANK_UNKNOWN")
    return Addon:T("FOREVER.TALENT_RANK_DETAIL", current and tostring(current) or unknown, maximum and tostring(maximum) or unknown)
end

function Talents:GetIcon(node)
    local spellID = node.spellID
    local icon = spellID and (Read(C_Spell and C_Spell.GetSpellTexture, spellID) or Read(GetSpellTexture, spellID))
    return (type(icon) == "number" or type(icon) == "string") and icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Talents:GetTreeTitle(tree)
    if Store:Integer(tree.available, 0, 2147483647) then
        return Addon:T("FOREVER.TALENT_TREE_AVAILABLE", tree.id, tree.points, tree.available)
    end
    return Addon:T("FOREVER.TALENT_TREE_POINTS", tree.id, tree.points)
end

local function ReadTree(configID, treeID)
    local nodes = Read(C_Traits.GetTreeNodes, treeID)
    local currencies = Read(C_Traits.GetTreeCurrencyInfo, configID, treeID, true)
    if not Array(nodes) or not Array(currencies) then return nil end
    local spent, seen, purchased, observedNodeIDs = 0, {}, {}, {}
    local graph, complete = {}, true
    for _, currency in ipairs(currencies) do
        if not Store:Plain(currency) or type(currency) ~= "table"
            or not Store:Integer(currency.spentInTree, 0, 2147483647) then return nil end
        spent = spent + currency.spentInTree
    end
    for _, nodeID in ipairs(nodes) do
        if not ID(nodeID) or seen[nodeID] then return nil end
        seen[nodeID] = true
        observedNodeIDs[#observedNodeIDs + 1] = nodeID
        local node = Read(C_Traits.GetNodeInfo, configID, nodeID)
        if type(node) ~= "table" or not IsRank(node.ranksPurchased) then return nil end
        local showNode = not Store:Plain(node.isVisible) or node.isVisible ~= false or node.ranksPurchased > 0
        local details = showNode and ReadNodeDetails(configID, nodeID, node)
        if node.ranksPurchased > 0 then
            details.rank = node.ranksPurchased
            purchased[#purchased + 1] = details
        end
        if showNode then
            local graphNode = ReadGraphNode(details, node)
            if graphNode then graph[#graph + 1] = graphNode else complete = false end
        end
    end
    if not Store:Integer(spent, 0, 2147483647) then return nil end
    local available = #currencies == 1 and currencies[1].quantity
    return { id = treeID, points = spent, nodes = purchased, observedNodeIDs = observedNodeIDs,
        graph = complete and #graph > 0 and graph or nil,
        available = Store:Integer(available, 0, 2147483647) and available or nil }
end

local function ReadTrees(configID)
    local config = Read(C_Traits and C_Traits.GetConfigInfo, configID)
    if type(config) ~= "table" or not Array(config.treeIDs) then return nil end
    local trees, seen = {}, {}
    for index, treeID in ipairs(config.treeIDs) do
        if not ID(treeID) or seen[treeID] then return nil end
        seen[treeID] = true
        local tree = ReadTree(configID, treeID)
        if not tree then return nil end
        trees[index] = tree
    end
    return trees
end

local function KeepStableDetails(first, second)
    if first.currentRank ~= second.currentRank then second.currentRank = nil end
    if first.maxRanks ~= second.maxRanks then second.maxRanks = nil end
    if first.definitionID ~= second.definitionID then second.definitionID = nil end
end

local function SameGraph(first, second)
    if not first or not second then return first == second end
    if #first ~= #second then return false end
    for index, node in ipairs(first) do
        local other = second[index]
        if node.id ~= other.id or node.x ~= other.x or node.y ~= other.y
            or node.spellID ~= other.spellID or #node.targets ~= #other.targets then return false end
        for slot, target in ipairs(node.targets) do if target ~= other.targets[slot] then return false end end
        KeepStableDetails(node, other)
    end
    return true
end

local function SameTrees(first, second)
    if #first ~= #second then return false end
    for index, tree in ipairs(first) do
        local other = second[index]
        if tree.id ~= other.id or tree.points ~= other.points or #tree.nodes ~= #other.nodes then return false end
        if #tree.observedNodeIDs ~= #other.observedNodeIDs then return false end
        for slot, nodeID in ipairs(tree.observedNodeIDs) do
            if nodeID ~= other.observedNodeIDs[slot] then return false end
        end
        for slot, node in ipairs(tree.nodes) do
            local latest = other.nodes[slot]
            if node.id ~= latest.id or node.rank ~= latest.rank or node.spellID ~= latest.spellID then return false end
            KeepStableDetails(node, latest)
        end
        if tree.available ~= other.available then
            if tree.available ~= nil and other.available ~= nil then return false end
            other.available = nil
        end
        if not SameGraph(tree.graph, other.graph) then other.graph = nil end
    end
    return true
end

function Talents:Get(id)
    if not id or id ~= Addon.Core.Characters:GetCurrentID() then return nil, "unknown" end
    local row = Store.db.talents and Store.db.talents[id]
    local state = self.freshID == id and "known" or (row and "stale" or "unknown")
    return row and Addon.Core.Defaults:Copy(row) or nil, state
end

function Talents:Scan()
    if not Addon.initialized or not Addon.Scanner.inWorld or Read(IsLoggedIn) ~= true then return false end
    local id = Addon.Core.Characters:GetCurrentID()
    if not id then return false end
    local configID, stamp = ActiveConfig(), Read(GetServerTime)
    local first = ID(configID) and MayReadConfig(configID) and ReadTrees(configID)
    local second = first and ReadTrees(configID)
    if not second or not SameTrees(first, second) or ActiveConfig() ~= configID or not MayReadConfig(configID)
        or id ~= Addon.Core.Characters:GetCurrentID() or not Store:Integer(stamp, 0, 9007199254740991) then
        self.freshID = nil
        Addon:NotifyChanged()
        return false
    end
    -- Levels and point costs are separate native observations.
    for _, tree in ipairs(second) do tree.observedNodeIDs = nil end
    Store.db.talents = Store.db.talents or {}
    Store.db.talents[id] = { observedAt = stamp, trees = second }
    self.freshID = id
    Addon:NotifyChanged()
    return true
end

function Talents:Cancel()
    self.generation = self.generation + 1
    self.queued, self.freshID = nil, nil
end

function Talents:Request()
    if self.queued or not Addon.Scanner.inWorld then return end
    self.queued = true
    local generation = self.generation
    local after = C_Timer and C_Timer.After
    local remainingRetries = 2
    local function Run()
        if self.generation ~= generation then return end
        if self:Scan() or remainingRetries == 0 or type(after) ~= "function" then
            self.queued = nil
        else
            remainingRetries = remainingRetries - 1
            after(0.6, Run)
        end
    end
    if type(after) == "function" then after(0.3, Run) else Run() end
end
