local Probe = {}
_G.YiboCraftingStage0Probe = Probe

Probe.VERSION = 1
Probe.MAX_SNAPSHOTS = 24
Probe.MAX_EVENTS = 200
Probe.eventsEnabled = true

local function Now()
    if type(GetServerTime) == "function" then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" and value > 0 then return value end
    end
    return type(time) == "function" and time() or 0
end

local function Call(owner, key, ...)
    local fn = owner and owner[key]
    if type(fn) ~= "function" then return nil, "missing" end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil, "error:" .. tostring(a) end
    return a, nil, b, c, d, e, f
end

local function ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
end

local function RecipeID(link)
    if type(link) ~= "string" then return nil end
    local family, id = link:match("|H([^:|]+):(%d+)")
    if family == "spell" or family == "enchant" or family == "trade" then return tonumber(id), family end
end

local function Count(map)
    local count = 0
    for _ in pairs(map) do count = count + 1 end
    return count
end

local function LegacyFilterOptions(listKey, checkKey)
    local result = { checked = {}, count = nil }
    local list = _G[listKey]
    if type(list) ~= "function" then result.error = "missing-" .. listKey; return result end
    local ok, names = pcall(function() return { list() } end)
    if not ok then result.error = "error-" .. listKey; return result end
    result.count = #names
    result.all = Call(_G, checkKey, 0)
    for index = 1, #names do
        if Call(_G, checkKey, index) == 1 then result.checked[#result.checked + 1] = index end
    end
    return result
end

local function Hash(value)
    local hash = 5381
    for index = 1, #value do hash = (hash * 33 + value:byte(index)) % 4294967296 end
    return string.format("%08x", hash)
end

function Probe:Print(message)
    local line = "|cff20e070[Yibo Crafting 0]|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line)
    elseif type(print) == "function" then print(line) end
end

function Probe:Initialize()
    local db = _G.YiboCraftingStage0DB
    if type(db) ~= "table" or db.schemaVersion ~= self.VERSION then
        db = { schemaVersion = self.VERSION, sessions = {} }
        _G.YiboCraftingStage0DB = db
    end
    db.sessions = db.sessions or {}
    local version, build, buildDate, interface = nil, nil, nil, nil
    if type(GetBuildInfo) == "function" then version, build, buildDate, interface = GetBuildInfo() end
    local guid = type(UnitGUID) == "function" and UnitGUID("player") or nil
    local name = type(UnitName) == "function" and UnitName("player") or "unknown"
    local realm = type(GetRealmName) == "function" and GetRealmName() or "unknown"
    local session = {
        startedAt = Now(),
        characterKeyHash = Hash(tostring(guid or (tostring(name) .. "-" .. tostring(realm)))),
        client = { version = version, build = build, buildDate = buildDate, interface = interface, locale = type(GetLocale) == "function" and GetLocale() or nil },
        capabilities = self:Capabilities(),
        snapshots = {}, events = {},
    }
    db.sessions[#db.sessions + 1] = session
    while #db.sessions > 4 do table.remove(db.sessions, 1) end
    self.session = session
    return session
end

function Probe:Capabilities()
    local names = {
        "GetAllRecipeIDs", "GetFilteredRecipeIDs", "GetRecipeInfo", "GetRecipeSchematic",
        "GetRecipeItemLink", "GetRecipeOutputItemData", "GetTradeSkillLine",
        "GetBaseProfessionInfo", "IsTradeSkillLinked", "IsTradeSkillGuild",
        "GetShowLearned", "GetShowUnlearned",
    }
    local modern = {}
    for _, key in ipairs(names) do modern[key] = type(C_TradeSkillUI and C_TradeSkillUI[key]) == "function" end
    local legacy = {}
    for _, key in ipairs({ "GetProfessions", "GetProfessionInfo", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillLine", "GetTradeSkillRecipeLink", "GetTradeSkillItemLink", "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink", "GetTradeSkillSubClasses", "GetTradeSkillSubClassFilter", "GetTradeSkillInvSlots", "GetTradeSkillInvSlotFilter", "GetTradeSkillItemNameFilter", "GetTradeSkillItemLevelFilter", "GetOnlyShowMakeable", "GetOnlyShowSkillUps", "IsTradeSkillLinked", "IsTradeSkillGuild" }) do
        legacy[key] = type(_G[key]) == "function"
    end
    return { modern = modern, legacy = legacy }
end

function Probe:Professions()
    local result = { entries = {} }
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        result.error = "missing-api"
        return result
    end
    local ok, first, second, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
    if not ok then result.error = "error:" .. tostring(first); return result end
    local slots = { first, second, archaeology, fishing, cooking, firstAid }
    for slot = 1, 6 do
        local index = slots[slot]
        if index then
            local infoOK, name, icon, skillLevel, maxSkillLevel, _, _, skillLineID = pcall(GetProfessionInfo, index)
            if infoOK then
                result.entries[#result.entries + 1] = {
                    slot = slot, index = index, name = name, icon = icon,
                    skillLevel = skillLevel, maxSkillLevel = maxSkillLevel, skillLineID = skillLineID,
                }
            else result.entries[#result.entries + 1] = { slot = slot, index = index, error = tostring(name) } end
        end
    end
    return result
end

function Probe:AddEvent(name, ...)
    if not self.eventsEnabled or not self.session then return end
    local args = {}
    for i = 1, math.min(select("#", ...), 3) do
        local value = select(i, ...)
        if type(value) == "number" or type(value) == "boolean" then args[i] = value end
    end
    local events = self.session.events
    events[#events + 1] = { at = Now(), event = name, args = args }
    while #events > self.MAX_EVENTS do table.remove(events, 1) end
end

function Probe:Context()
    local context = { frameShown = false, source = "unknown" }
    local frame = _G.TradeSkillFrame
    if frame and type(frame.IsShown) == "function" then
        local ok, shown = pcall(frame.IsShown, frame)
        context.frameShown = ok and shown == true
    end
    local linkedLegacy = Call(_G, "IsTradeSkillLinked")
    local guildLegacy = Call(_G, "IsTradeSkillGuild")
    local linkedModern = Call(C_TradeSkillUI, "IsTradeSkillLinked")
    local guildModern = Call(C_TradeSkillUI, "IsTradeSkillGuild")
    context.linked = linkedLegacy == true or linkedModern == true
    context.guild = guildLegacy == true or guildModern == true
    if context.linked then context.source = "linked"
    elseif context.guild then context.source = "guild"
    elseif context.frameShown then context.source = "own-window-candidate" end
    local name, nameError, rank, maxRank = Call(_G, "GetTradeSkillLine")
    context.legacyLine = name
    context.legacyLineError = nameError
    context.legacyRank = rank
    context.legacyMaxRank = maxRank
    local base, baseError = Call(C_TradeSkillUI, "GetBaseProfessionInfo")
    context.baseProfession = type(base) == "table" and {
        professionID = base.professionID, professionName = base.professionName,
        skillLineID = base.skillLineID, skillLevel = base.skillLevel,
    } or nil
    context.baseProfessionError = baseError
    return context
end

local function SafeRecipeInfo(recipeID)
    local info, err = Call(C_TradeSkillUI, "GetRecipeInfo", recipeID)
    if type(info) ~= "table" then return { id = recipeID, error = err or "no-info" } end
    return {
        id = recipeID, name = info.name, icon = info.icon, learned = info.learned,
        sourceType = info.sourceType, categoryID = info.categoryID,
        skillLineAbilityID = info.skillLineAbilityID, isRecraft = info.isRecraft,
    }
end

function Probe:ModernSnapshot()
    local result = { api = "C_TradeSkillUI", errors = {}, recipes = {} }
    local ids, err = Call(C_TradeSkillUI, "GetAllRecipeIDs")
    result.allRecipeIDsError = err
    if type(ids) == "table" then
        result.allRecipeIDsReturned = true
        local seen = {}
        for _, id in pairs(ids) do
            if type(id) == "number" and not seen[id] then
                seen[id] = true
                result.recipes[#result.recipes + 1] = SafeRecipeInfo(id)
            end
        end
        table.sort(result.recipes, function(a, b) return a.id < b.id end)
        result.allCount = #result.recipes
    else
        result.allRecipeIDsReturned = false
    end
    local filtered, filteredError = Call(C_TradeSkillUI, "GetFilteredRecipeIDs")
    result.filteredRecipeIDsError = filteredError
    result.filteredCount = type(filtered) == "table" and #filtered or nil
    result.showLearned = Call(C_TradeSkillUI, "GetShowLearned")
    result.showUnlearned = Call(C_TradeSkillUI, "GetShowUnlearned")
    return result
end

function Probe:LegacySnapshot()
    local result = { api = "legacy", rows = {}, recipeIDs = {}, duplicateIDs = {}, headerCount = 0, headerGroupsWithoutRecipes = 0 }
    local count, err = Call(_G, "GetNumTradeSkills")
    result.rowCount = tonumber(count)
    result.error = err
    result.subClassFilter = Call(_G, "GetTradeSkillSubClassFilter")
    result.inventoryFilter = Call(_G, "GetTradeSkillInvSlotFilter")
    result.filters = {
        subClasses = LegacyFilterOptions("GetTradeSkillSubClasses", "GetTradeSkillSubClassFilter"),
        inventorySlots = LegacyFilterOptions("GetTradeSkillInvSlots", "GetTradeSkillInvSlotFilter"),
        onlyMakeable = Call(_G, "GetOnlyShowMakeable"),
        onlySkillUps = Call(_G, "GetOnlyShowSkillUps"),
    }
    result.filters.itemName, result.filters.itemNameError = Call(_G, "GetTradeSkillItemNameFilter")
    result.filters.minItemLevel, result.filters.itemLevelError, result.filters.maxItemLevel = Call(_G, "GetTradeSkillItemLevelFilter")
    local search = _G.TradeSkillFrameSearchBox
    if search and type(search.GetText) == "function" then
        local ok, value = pcall(search.GetText, search)
        result.filters.searchText = ok and value or nil
    end
    if not result.rowCount then return result end
    local seen = {}
    local activeHeader, hasVisibleRecipe = false, false
    for index = 1, math.min(result.rowCount, 10000) do
        local name, infoError, difficulty, numAvailable, isExpanded = Call(_G, "GetTradeSkillInfo", index)
        local link, linkError = Call(_G, "GetTradeSkillRecipeLink", index)
        local recipeID, linkFamily = RecipeID(link)
        local outputLink = Call(_G, "GetTradeSkillItemLink", index)
        local row = {
            index = index, name = name, difficulty = difficulty, numAvailable = numAvailable,
            isExpanded = isExpanded, recipeID = recipeID, linkFamily = linkFamily,
            outputItemID = ItemID(outputLink), infoError = infoError, linkError = linkError,
        }
        result.rows[#result.rows + 1] = row
        if difficulty == "header" or difficulty == "subheader" then
            if activeHeader and not hasVisibleRecipe then
                result.headerGroupsWithoutRecipes = result.headerGroupsWithoutRecipes + 1
            end
            result.headerCount = result.headerCount + 1
            if isExpanded == true then result.expandedHeaderCount = (result.expandedHeaderCount or 0) + 1
            elseif isExpanded == false then result.collapsedHeaderCount = (result.collapsedHeaderCount or 0) + 1
            else result.unknownExpansionHeaderCount = (result.unknownExpansionHeaderCount or 0) + 1 end
            activeHeader, hasVisibleRecipe = true, false
        else hasVisibleRecipe = true end
        if recipeID then
            if seen[recipeID] then result.duplicateIDs[#result.duplicateIDs + 1] = recipeID
            else seen[recipeID] = true; result.recipeIDs[#result.recipeIDs + 1] = recipeID end
        end
    end
    if activeHeader and not hasVisibleRecipe then
        result.headerGroupsWithoutRecipes = result.headerGroupsWithoutRecipes + 1
    end
    table.sort(result.recipeIDs)
    result.uniqueRecipeCount = Count(seen)
    result.truncated = result.rowCount > 10000
    return result
end

local function AssessVisibleList(context, legacy, earlierSnapshots)
    local assessment = { scope = "unverified", restrictions = {}, uncertainties = {} }
    local function Restrict(reason)
        assessment.restrictions[#assessment.restrictions + 1] = reason
    end
    local function Uncertain(reason)
        assessment.uncertainties[#assessment.uncertainties + 1] = reason
    end
    if context.source ~= "own-window-candidate" then Uncertain("own-window-not-confirmed") end
    if legacy.error or not legacy.rowCount then Uncertain("legacy-list-unavailable") end
    if legacy.truncated then Restrict("row-limit") end
    local filters = legacy.filters or {}
    for _, key in ipairs({ "subClasses", "inventorySlots" }) do
        local option = filters[key]
        if option and option.all == 0 then Restrict(key .. "-filter")
        elseif not option or option.all == nil then Uncertain(key .. "-filter-unknown") end
    end
    if filters.onlyMakeable == true then Restrict("only-makeable")
    elseif filters.onlyMakeable == nil then Uncertain("only-makeable-unknown") end
    if filters.onlySkillUps == true then Restrict("only-skill-ups")
    elseif filters.onlySkillUps == nil then Uncertain("only-skill-ups-unknown") end
    if type(filters.searchText) == "string" and filters.searchText:match("%S") then Restrict("blizzard-search")
    elseif filters.searchText == nil then Uncertain("blizzard-search-unknown") end
    if type(filters.itemName) == "string" and filters.itemName:match("%S") then Restrict("native-item-name-filter")
    elseif filters.itemNameError then Uncertain("native-item-name-filter-unknown") end
    if type(filters.minItemLevel) == "number" and type(filters.maxItemLevel) == "number" then
        if filters.minItemLevel ~= 0 or filters.maxItemLevel ~= 0 then Restrict("native-item-level-filter") end
    else Uncertain("native-item-level-filter-unknown") end
    if (legacy.collapsedHeaderCount or 0) > 0 then Restrict("collapsed-header") end
    if (legacy.unknownExpansionHeaderCount or 0) > 0 then Uncertain("header-expansion-unknown") end
    if (legacy.headerGroupsWithoutRecipes or 0) > 0 then Uncertain("header-without-visible-recipe") end
    if context.source == "own-window-candidate" and context.legacyLine and legacy.uniqueRecipeCount then
        local currentIDs = {}
        for _, id in ipairs(legacy.recipeIDs or {}) do currentIDs[id] = true end
        for _, prior in ipairs(earlierSnapshots or {}) do
            local earlierContext, earlierLegacy = prior.context or {}, prior.legacy or {}
            if earlierContext.source == "own-window-candidate" and
                earlierContext.legacyLine == context.legacyLine and
                earlierContext.legacyRank == context.legacyRank and
                earlierLegacy.uniqueRecipeCount and earlierLegacy.uniqueRecipeCount > legacy.uniqueRecipeCount then
                local earlierIDs, subset = {}, true
                for _, id in ipairs(earlierLegacy.recipeIDs or {}) do earlierIDs[id] = true end
                for id in pairs(currentIDs) do if not earlierIDs[id] then subset = false; break end end
                if subset then Restrict("subset-of-earlier-own-list"); break end
            end
        end
    end
    if #assessment.restrictions > 0 then assessment.scope = "restricted" end
    return assessment
end

function Probe:Snapshot(reason)
    if not self.session then self:Initialize() end
    local list = self.session.snapshots
    local snapshot = {
        at = Now(), reason = reason or "manual", context = self:Context(), professions = self:Professions(),
        modern = self:ModernSnapshot(), legacy = self:LegacySnapshot(),
        completeness = "unverified",
    }
    snapshot.visibleList = AssessVisibleList(snapshot.context, snapshot.legacy, list)
    list[#list + 1] = snapshot
    while #list > self.MAX_SNAPSHOTS do table.remove(list, 1) end
    self:Print(string.format("%s [%s]：现代列表 %s 条，旧版 %s 行 / %s 个配方 ID，无可见配方分类 %s；完整性未验证。",
        snapshot.reason, tostring(snapshot.context.legacyLine or "未知专业"),
        tostring(snapshot.modern.allCount or "不可用"), tostring(snapshot.legacy.rowCount or "不可用"),
        tostring(snapshot.legacy.uniqueRecipeCount or "不可用"), tostring(snapshot.legacy.headerGroupsWithoutRecipes or "不可用")))
    if snapshot.context.source ~= "own-window-candidate" and (snapshot.legacy.uniqueRecipeCount or 0) > 0 then
        self:Print("窗口来源未确认为本人专业；这次列表仅作诊断证据。")
    end
    if snapshot.visibleList.scope == "restricted" then
        self:Print("旧版列表有明确的可见范围限制：" .. table.concat(snapshot.visibleList.restrictions, "、") .. "；缺失配方仍为未知。")
    end
    return snapshot
end

function Probe:Recipe(recipeID)
    recipeID = tonumber(recipeID)
    if not recipeID or recipeID < 1 then self:Print("用法：/yct recipe <配方 ID>"); return nil end
    if not self.session then self:Initialize() end
    local result = { at = Now(), id = recipeID, context = self:Context(), modern = SafeRecipeInfo(recipeID) }
    local link, linkError = Call(C_TradeSkillUI, "GetRecipeItemLink", recipeID)
    result.outputItemID = ItemID(link)
    result.outputLinkError = linkError
    local output, outputError = Call(C_TradeSkillUI, "GetRecipeOutputItemData", recipeID)
    result.outputData = type(output) == "table" and { itemID = output.itemID, itemIDs = output.itemIDs, quantity = output.quantity } or nil
    result.outputDataError = outputError
    local schematic, schematicError = Call(C_TradeSkillUI, "GetRecipeSchematic", recipeID, false)
    result.schematicError = schematicError
    if type(schematic) == "table" then
        result.schematic = { recipeID = schematic.recipeID, outputItemID = schematic.outputItemID, reagentSlotSchematics = {} }
        for index, slot in ipairs(schematic.reagentSlotSchematics or {}) do
            local reagent = { index = index, quantityRequired = slot.quantityRequired, reagentType = slot.reagentType, reagents = {} }
            for _, candidate in ipairs(slot.reagents or {}) do
                reagent.reagents[#reagent.reagents + 1] = { itemID = candidate.itemID, currencyID = candidate.currencyID }
            end
            result.schematic.reagentSlotSchematics[#result.schematic.reagentSlotSchematics + 1] = reagent
        end
    end
    local latest = self.session.snapshots[#self.session.snapshots]
    if latest and latest.context.legacyLine == result.context.legacyLine then
        for _, row in ipairs(latest.legacy.rows) do
            if row.recipeID == recipeID then
                result.legacy = { index = row.index, outputItemID = row.outputItemID, reagents = {} }
                local count = Call(_G, "GetTradeSkillNumReagents", row.index)
                for reagentIndex = 1, math.min(tonumber(count) or 0, 100) do
                    local name, _, _, needed = Call(_G, "GetTradeSkillReagentInfo", row.index, reagentIndex)
                    local reagentLink = Call(_G, "GetTradeSkillReagentItemLink", row.index, reagentIndex)
                    result.legacy.reagents[#result.legacy.reagents + 1] = { name = name, itemID = ItemID(reagentLink), quantity = needed }
                end
                break
            end
        end
    end
    self.session.recipeSamples = self.session.recipeSamples or {}
    self.session.recipeSamples[#self.session.recipeSamples + 1] = result
    while #self.session.recipeSamples > 40 do table.remove(self.session.recipeSamples, 1) end
    self:Print("已记录配方 " .. recipeID .. " 的产物与材料样本；未推断取得状态。")
    return result
end

function Probe:Archaeology()
    if not self.session then self:Initialize() end
    local frame = _G.ArchaeologyFrame
    local frameShown = false
    if frame and type(frame.IsShown) == "function" then
        local ok, shown = pcall(frame.IsShown, frame)
        frameShown = ok and shown == true
    end
    local result = { at = Now(), frameShown = frameShown, races = {}, projectCount = 0, spellIDCount = 0, completedCount = 0, completeness = "unverified" }
    local count, err = Call(_G, "GetNumArchaeologyRaces")
    result.raceCount, result.error = tonumber(count), err
    if result.raceCount then
        for raceIndex = 1, math.min(result.raceCount, 50) do
            local projectCount, projectError = Call(_G, "GetNumArtifactsByRace", raceIndex)
            local race = { index = raceIndex, projectCount = tonumber(projectCount), error = projectError, projects = {} }
            result.races[#result.races + 1] = race
            for projectIndex = 1, math.min(race.projectCount or 0, 500) do
                local fn = _G.GetArtifactInfoByRace
                if type(fn) ~= "function" then race.error = "missing-GetArtifactInfoByRace"; break end
                local ok, name, _, rarity, _, _, _, _, spellID, _, completionCount = pcall(fn, raceIndex, projectIndex)
                if not ok then race.error = "GetArtifactInfoByRace-error"; break end
                race.projects[#race.projects + 1] = {
                    index = projectIndex, spellID = tonumber(spellID),
                    rarity = rarity, completionCount = tonumber(completionCount),
                    hasName = type(name) == "string" and name ~= "",
                }
                result.projectCount = result.projectCount + 1
                if tonumber(spellID) then result.spellIDCount = result.spellIDCount + 1 end
                if tonumber(completionCount) and tonumber(completionCount) > 0 then result.completedCount = result.completedCount + 1 end
            end
        end
    end
    self.session.archaeologySamples = self.session.archaeologySamples or {}
    self.session.archaeologySamples[#self.session.archaeologySamples + 1] = result
    while #self.session.archaeologySamples > 4 do table.remove(self.session.archaeologySamples, 1) end
    self:Print(string.format("考古界面 %s；%s 个种族、%d 个项目、%d 个法术 ID、%d 个完成记录；完整性未验证。",
        frameShown and "已打开" or "未打开", tostring(result.raceCount or "不可用"),
        result.projectCount, result.spellIDCount, result.completedCount))
    return result
end
