local _, P = ...
function P.ScanTalents()
    local sample = P.Begin("talents")
    if not sample then return end
    sample.inventory = {}
    for path in pairs(P.reads) do
        if path:match("^C_Traits%.") or path:match("^C_ClassTalents%.") or path:match("^C_SpecializationInfo%.") then
            sample.inventory[path] = type(P.Resolve(path)) == "function"
        end
    end
    sample.activeConfig = P.Call("C_ClassTalents.GetActiveConfigID")
    sample.specialization = P.Call("C_SpecializationInfo.GetSpecialization")
    local configID = P.First(sample.activeConfig)
    sample.trees, sample.entries, sample.definitions, sample.conditions = {}, {}, {}, {}
    if P.Integer(configID, 1, 2147483647) then
        sample.config = P.Call("C_Traits.GetConfigInfo", configID)
        local config = P.First(sample.config)
        local treeIDs, treeState = P.IDs(type(config) == "table" and config.treeIDs, 8)
        sample.treeEnumeration = treeState
        local nodeCount, entryCount, conditionCount = 0, 0, 0
        for _, treeID in ipairs(treeIDs) do
            local tree = {
                treeID = treeID, info = P.Call("C_Traits.GetTreeInfo", configID, treeID),
                currencyIncludingStaged = P.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, false),
                currencyExcludingStaged = P.Call("C_Traits.GetTreeCurrencyInfo", configID, treeID, true),
                nodeIDs = P.Call("C_Traits.GetTreeNodes", treeID), nodes = {},
            }
            local nodeIDs, nodeState = P.IDs(P.First(tree.nodeIDs), math.max(0, 256 - nodeCount))
            tree.enumeration = nodeState
            for _, nodeID in ipairs(nodeIDs) do
                nodeCount = nodeCount + 1
                local node = { nodeID = nodeID, info = P.Call("C_Traits.GetNodeInfo", configID, nodeID),
                    cost = P.Call("C_Traits.GetNodeCost", configID, nodeID) }
                local info = P.First(node.info)
                local entryIDs, entryState = P.IDs(type(info) == "table" and info.entryIDs, 16)
                node.entryEnumeration = entryState
                for _, entryID in ipairs(entryIDs) do
                    if not sample.entries[entryID] then
                        if entryCount >= 512 then node.entryEnumeration = "global_limit_reached"; break end
                        entryCount = entryCount + 1
                        local entry = P.Call("C_Traits.GetEntryInfo", configID, entryID)
                        sample.entries[entryID] = entry
                        local entryInfo = P.First(entry)
                        local definitionID = type(entryInfo) == "table" and entryInfo.definitionID
                        if P.Integer(definitionID, 1, 2147483647) and not sample.definitions[definitionID] then
                            sample.definitions[definitionID] = P.Call("C_Traits.GetDefinitionInfo", definitionID)
                        end
                    end
                end
                local conditions, conditionState = P.IDs(type(info) == "table" and info.conditionIDs, 32)
                node.conditionEnumeration = conditionState
                for _, conditionID in ipairs(conditions) do
                    if not sample.conditions[conditionID] then
                        if conditionCount >= 512 then node.conditionEnumeration = "global_limit_reached"; break end
                        conditionCount = conditionCount + 1
                        sample.conditions[conditionID] = P.Call("C_Traits.GetConditionInfo", configID, conditionID)
                    end
                end
                tree.nodes[#tree.nodes + 1] = node
            end
            sample.trees[#sample.trees + 1] = tree
        end
        sample.nodeCount = nodeCount
    else sample.treeEnumeration = "active_config_unreadable_or_not_positive" end
    sample.activeConfigAfter = P.Call("C_ClassTalents.GetActiveConfigID")
    sample.sameActiveConfig = P.Integer(configID, 1, 2147483647) and configID == P.First(sample.activeConfigAfter)
    sample.nextCheck = "Compare native talent UI, committed ranks, point totals, edges, gates and manual changes; inheritance scope remains unverified"
    return P.Finish(sample)
end
