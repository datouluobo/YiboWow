local addonName, P = ...
-- 0.1.0 (2026-11-21): first Forever transmog evidence probe, API list from the 1.60.1.70959 export.
-- 0.1.1 (2026-11-21): quest reward API presence and turn-in verification of unchosen reward unlocks.
-- 0.1.2 (2026-11-22): skip quest-complete samples without item rewards; keep up to 24 samples.
local VERSION, MAX_SAMPLES, MAX_LIST, MAX_SOURCES, MAX_BAG_ITEMS, MAX_SETS = "0.1.2", 24, 4096, 24, 48, 40
local MAX_CAT_SCAN, MAX_CAT_ROWS, MAX_ADDED, MAX_EVENTS = 800, 12, 200, 64
local db, session, inWorld, reportWindow
local function pack(...) return { n = select("#", ...), ... } end
local function restricted(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end
local function clean(value, depth, seen)
    if restricted(value) then return "<restricted>" end
    local kind = type(value)
    if kind == "nil" then return "<nil>" end
    if kind == "boolean" then return value end
    if kind == "string" then return string.sub(value, 1, 2048) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "<non-finite>" end
        return value
    end
    if kind ~= "table" then return "<" .. kind .. ">" end
    if depth >= 6 then return "<depth-limit>" end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local result, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > MAX_LIST then result.__truncated = true; break end
        if not restricted(key) and (type(key) == "string" or type(key) == "number") then
            result[key] = clean(item, depth + 1, seen)
        end
    end
    seen[value] = nil
    return result
end
local function safe(value)
    local ok, result = pcall(clean, value, 0, {})
    if ok then return result end
    return "<unreadable>"
end
local function resolve(path)
    local value = _G
    for segment in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[segment]
    end
    return value
end
-- Call sites below are a fixed read-only whitelist. Slash input is only an item ID/link or category number.
-- No filter, outfit, favorite, situation, CVar or transmogrify setters are called.
local function read(path, ...)
    local fn = resolve(path)
    if type(fn) ~= "function" then return { status = "missing" } end
    local raw = pack(pcall(fn, ...))
    if not raw[1] then return { status = "error", error = safe(raw[2]) } end
    local result = { status = "returned_unverified", n = raw.n - 1, values = {}, types = {} }
    for i = 2, raw.n do
        result.values[i - 1] = safe(raw[i])
        result.types[i - 1] = restricted(raw[i]) and "restricted" or type(raw[i])
    end
    return result
end
local function first(result) return result and result.values and result.values[1] end
local function value(result, index) return result and result.values and result.values[index] end
local function positive(v)
    return type(v) == "number" and v > 0 and v < 2147483648 and v == math.floor(v)
end
local function counter(v)
    return type(v) == "number" and v >= 0 and v <= 9007199254740990 and v == math.floor(v)
end
local function validStore(store)
    if store == nil then return true end
    if type(store) ~= "table" or store.schema ~= 1 or type(store.samples) ~= "table"
        or not counter(store.nextSample) or not counter(store.sessions) or #store.samples > MAX_SAMPLES then return false end
    local count = 0
    for index, sample in pairs(store.samples) do
        count = count + 1
        if not positive(index) or index > #store.samples or type(sample) ~= "table"
            or not positive(sample.id) or sample.id > store.nextSample then return false end
    end
    return count == #store.samples
end
local function say(key, ...)
    print("|cff20e070[YiboTransmogForeverProbe]|r " .. string.format(P.text[key], ...))
end
local function isForever()
    local build = read("GetBuildInfo")
    return value(build, 4) == 16001 and type(WOW_PROJECT_CAMELOT) == "number"
        and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local function sourceRow(sourceID)
    return { sourceID = sourceID, info = read("C_TransmogCollection.GetSourceInfo", sourceID),
        bySource = read("C_TransmogCollection.GetAppearanceInfoBySource", sourceID),
        sourceInfo = read("C_TransmogCollection.GetAppearanceSourceInfo", sourceID),
        playerCan = read("C_TransmogCollection.PlayerCanCollectSource", sourceID),
        accountCan = read("C_TransmogCollection.AccountCanCollectSource", sourceID),
        known = read("C_TransmogCollection.PlayerKnowsSource", sourceID),
        has = read("C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance", sourceID),
        drops = read("C_TransmogCollection.GetAppearanceSourceDrops", sourceID),
        holiday = read("C_TransmogCollection.GetSourceRequiredHoliday", sourceID),
        sets = read("C_TransmogSets.GetSetsContainingSourceID", sourceID) }
end
local function itemRow(ref)
    local row = { ref = safe(ref), info = read("C_Item.GetItemInfo", ref), instant = read("C_Item.GetItemInfoInstant", ref),
        tmog = read("C_TransmogCollection.GetItemInfo", ref),
        hasByInfo = read("C_TransmogCollection.PlayerHasTransmogByItemInfo", ref),
        learnSet = read("C_Item.GetItemLearnTransmogSet", ref) }
    local itemID = first(row.instant)
    if positive(itemID) then
        row.has = read("C_TransmogCollection.PlayerHasTransmog", itemID)
        if first(row.info) == nil then row.requestedLoad = read("C_Item.RequestLoadItemDataByID", itemID).status end
    end
    local appearanceID, sourceID = value(row.tmog, 1), value(row.tmog, 2)
    if positive(sourceID) then row.source = sourceRow(sourceID) end
    if positive(appearanceID) then
        row.allSources, row.others = read("C_TransmogCollection.GetAllAppearanceSources", appearanceID), {}
        local list = first(row.allSources)
        if type(list) == "table" then
            for i = 1, math.min(#list, MAX_SOURCES) do
                local id = list[i]
                if positive(id) and id ~= sourceID then
                    row.others[#row.others + 1] = { sourceID = id, info = read("C_TransmogCollection.GetSourceInfo", id),
                        has = read("C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance", id) }
                end
            end
            row.othersTruncated = #list > MAX_SOURCES or nil
        end
    end
    return row
end

local function categoryIDs()
    local ids, enum = {}, type(Enum) == "table" and Enum.TransmogCollectionType
    if type(enum) == "table" then
        for _, id in pairs(enum) do if positive(id) then ids[#ids + 1] = id end end
    end
    if #ids == 0 then for id = 1, 29 do ids[id] = id end end
    table.sort(ids)
    return ids
end
local function collectCategories()
    local rows = {}
    for _, id in ipairs(categoryIDs()) do
        rows[#rows + 1] = { id = id, info = read("C_TransmogCollection.GetCategoryInfo", id),
            collected = read("C_TransmogCollection.GetCategoryCollectedCount", id),
            total = read("C_TransmogCollection.GetCategoryTotal", id),
            filteredCollected = read("C_TransmogCollection.GetFilteredCategoryCollectedCount", id),
            filteredTotal = read("C_TransmogCollection.GetFilteredCategoryTotal", id) }
    end
    return rows
end
local function collectSets()
    local all = read("C_TransmogSets.GetAllSets")
    local s = { all = { status = all.status, n = all.n }, fullBase = read("C_TransmogSets.GetFullBaseSetsCounts"),
        validBase = read("C_TransmogSets.GetValidBaseSetsCountsForCharacter"), hasAnyValid = read("C_TransmogSets.HasAnyValidSets"),
        usable = read("C_TransmogSets.HasUsableSets"), classFilter = read("C_TransmogSets.GetTransmogSetsClassFilter"),
        count = 0, collected = 0, hidden = 0, valid = 0, limited = 0, byExpansion = {}, rows = {} }
    local list = first(all)
    if type(list) ~= "table" then return s end
    for _, set in ipairs(list) do
        if type(set) == "table" then
            s.count = s.count + 1
            if set.collected == true then s.collected = s.collected + 1 end
            if set.hiddenUntilCollected == true then s.hidden = s.hidden + 1 end
            if set.validForCharacter == true then s.valid = s.valid + 1 end
            if set.limitedTimeSet == true then s.limited = s.limited + 1 end
            local key = tostring(set.expansionID)
            s.byExpansion[key] = (s.byExpansion[key] or 0) + 1
            if #s.rows < MAX_SETS then
                s.rows[#s.rows + 1] = { setID = set.setID, name = set.name, label = set.label, baseSetID = set.baseSetID,
                    expansionID = set.expansionID, patchID = set.patchID, classMask = set.classMask, collected = set.collected,
                    validForCharacter = set.validForCharacter, hiddenUntilCollected = set.hiddenUntilCollected,
                    requiredFaction = set.requiredFaction }
            end
        end
    end
    local firstSet = s.rows[1] and s.rows[1].setID
    if positive(firstSet) then
        s.firstPrimary = read("C_TransmogSets.GetSetPrimaryAppearances", firstSet)
        s.firstSources = read("C_TransmogSets.GetAllSourceIDs", firstSet)
    end
    return s
end
-- Display state is observed only. CVar names are unknown, so console commands are filtered by name when listable.
local function collectDisplay()
    local d = { transmogEnabled = read("C_TransmogOutfitInfo.IsTransmogEnabled"),
        situationsEnabled = read("C_TransmogOutfitInfo.GetOutfitSituationsEnabled"),
        activeOutfit = read("C_TransmogOutfitInfo.GetActiveOutfitID"),
        equippedGearDisplayed = read("C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed"),
        equippedGearLocked = read("C_TransmogOutfitInfo.IsEquippedGearOutfitLocked"),
        maxUsableOutfits = read("C_TransmogOutfitInfo.GetMaxNumberOfUsableOutfits"),
        outfits = read("C_TransmogOutfitInfo.GetOutfitsInfo"),
        situations = read("C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions"),
        eventActive = read("C_TransmogOutfitInfo.TransmogEventActive"), inEvent = read("C_TransmogOutfitInfo.InTransmogEvent"),
        atNPC = read("C_Transmog.IsAtTransmogNPC"), preset = read("C_GameRules.GetForeverExperiencePreset"),
        collectedShown = read("C_TransmogCollection.GetCollectedShown"),
        uncollectedShown = read("C_TransmogCollection.GetUncollectedShown"),
        defaultFilters = read("C_TransmogCollection.IsUsingDefaultFilters"),
        classFilter = read("C_TransmogCollection.GetClassFilter"), cvars = {} }
    local commands = first(read("C_Console.GetAllCommands"))
    if type(commands) ~= "table" then commands = first(read("ConsoleGetAllCommands")) end
    d.cvarListStatus = type(commands) == "table" and "listed" or "unlisted"
    if type(commands) == "table" then
        for _, c in ipairs(commands) do
            local name = type(c) == "table" and c.command
            if type(name) == "string" then
                local lower = string.lower(name)
                if string.find(lower, "transmog", 1, true) or string.find(lower, "wardrobe", 1, true)
                    or string.find(lower, "appearance", 1, true) or string.find(lower, "outfit", 1, true) then
                    d.cvars[#d.cvars + 1] = { name = name, value = read("C_CVar.GetCVar", name), info = read("C_CVar.GetCVarInfo", name) }
                end
            end
        end
    end
    return d
end

local function collectCategory(id)
    local list = read("C_TransmogCollection.GetCategoryAppearances", id)
    local c = { id = id, info = read("C_TransmogCollection.GetCategoryInfo", id), status = list.status, total = 0, collected = 0,
        usable = 0, hidden = 0, scanned = 0, sourceTypes = {}, sourceCollected = 0, sourceTotal = 0, collectedRows = {}, missingRows = {} }
    local appearances = first(list)
    if type(appearances) ~= "table" then return c end
    c.total = #appearances
    for i, a in ipairs(appearances) do
        if type(a) == "table" then
            if a.isCollected == true then c.collected = c.collected + 1 end
            if a.isUsable == true then c.usable = c.usable + 1 end
            if a.isHideVisual == true then c.hidden = c.hidden + 1 end
            if i <= MAX_CAT_SCAN and positive(a.visualID) then
                c.scanned = c.scanned + 1
                local sources = first(read("C_TransmogCollection.GetAppearanceSources", a.visualID, id))
                local brief = {}
                if type(sources) == "table" then
                    for _, src in ipairs(sources) do
                        if type(src) == "table" then
                            local key = tostring(src.sourceType)
                            c.sourceTypes[key] = (c.sourceTypes[key] or 0) + 1
                            c.sourceTotal = c.sourceTotal + 1
                            if src.isCollected == true then c.sourceCollected = c.sourceCollected + 1 end
                            if #brief < 4 then
                                brief[#brief + 1] = { sourceID = src.sourceID, itemID = src.itemID, name = src.name, quality = src.quality,
                                    sourceType = src.sourceType, isCollected = src.isCollected, playerCanCollect = src.playerCanCollect,
                                    isValidSourceForPlayer = src.isValidSourceForPlayer, useError = src.useError }
                            end
                        end
                    end
                end
                local rows = a.isCollected == true and c.collectedRows or c.missingRows
                if #rows < MAX_CAT_ROWS then
                    rows[#rows + 1] = { visualID = a.visualID, isCollected = a.isCollected, isUsable = a.isUsable,
                        canDisplayOnPlayer = a.canDisplayOnPlayer, minIlvl = a.minIlvl, hasRequiredHoliday = a.hasRequiredHoliday,
                        sourceCount = type(sources) == "table" and #sources or nil, sources = brief }
                end
            end
        end
    end
    c.scanTruncated = c.total > MAX_CAT_SCAN or nil
    return c
end

local function collectBags()
    local rows, scanned = {}, 0
    for bag = 0, 4 do
        local slots = first(read("C_Container.GetContainerNumSlots", bag))
        if counter(slots) then
            for slot = 1, slots do
                local info = first(read("C_Container.GetContainerItemInfo", bag, slot))
                local link = type(info) == "table" and info.hyperlink
                if type(link) == "string" and #rows < MAX_BAG_ITEMS then
                    scanned = scanned + 1
                    local classID = value(read("C_Item.GetItemInfoInstant", link), 6)
                    if classID == 2 or classID == 4 then
                        local r = itemRow(link)
                        r.bag, r.slot, r.quality, r.isBound = bag, slot, info.quality, info.isBound
                        rows[#rows + 1] = r
                    end
                end
            end
        end
    end
    return rows, scanned
end

local QUEST_API = { "GetQuestID", "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemInfo", "GetQuestItemLink",
    "GetQuestReward", "hooksecurefunc", "C_Timer.After" }
local function collectQuest()
    local q = { questID = read("GetQuestID"), title = read("GetTitleText"), choices = read("GetNumQuestChoices"),
        rewards = read("GetNumQuestRewards"), money = read("GetRewardMoney"), choiceRows = {}, rewardRows = {}, api = {} }
    for _, name in ipairs(QUEST_API) do q.api[name] = type(resolve(name)) end
    for _, kind in ipairs({ "choice", "reward" }) do
        local n = first(kind == "choice" and q.choices or q.rewards)
        local target = kind == "choice" and q.choiceRows or q.rewardRows
        if counter(n) then
            for i = 1, math.min(n, 10) do
                local link = first(read("GetQuestItemLink", kind, i))
                local r = type(link) == "string" and itemRow(link) or { ref = "<no-link>" }
                r.index, r.questItemInfo = i, read("GetQuestItemInfo", kind, i)
                target[#target + 1] = r
            end
        end
    end
    return q
end

-- Before-state of every reward is kept so a later verify sample can compare it with the live state and
-- with SOURCE_ADDED events after QUEST_TURNED_IN. The chosen index comes from a post-hook on GetQuestReward.
local function field(t, key) if type(t) == "table" then return t[key] end end
local function pendingFrom(sampleID, q)
    local p = { sampleID = sampleID, questID = first(q.questID), title = first(q.title), clock = first(read("GetTime")), rows = {} }
    for _, group in ipairs({ { "choice", q.choiceRows }, { "reward", q.rewardRows } }) do
        for _, r in ipairs(group[2]) do
            local src = r.source
            local b = src and first(src.bySource)
            local pc = src and src.playerCan
            p.rows[#p.rows + 1] = { kind = group[1], index = r.index, itemID = first(r.instant), name = value(r.info, 1),
                appearanceID = value(r.tmog, 1), sourceID = value(r.tmog, 2), usable = value(r.questItemInfo, 5),
                hadSource = src and first(src.has), hadAppearance = field(b, "appearanceIsCollected"),
                playerCan = pc and value(pc, 2) }
        end
    end
    return p
end
local function addedSince(sourceID, clock)
    for _, a in ipairs(session.added) do
        if a.sourceID == sourceID and type(a.clock) == "number" and (type(clock) ~= "number" or a.clock >= clock - 0.5) then
            return a.event
        end
    end
end
local function collectVerify()
    local p = session.pendingQuest
    if not p or not p.turnedIn then return nil end
    local t = p.turnedIn
    local v = { questID = p.questID, title = p.title, sampleID = p.sampleID, turnedInQuestID = t.questID,
        chosen = t.chosen, fallbackChoice = t.fallbackChoice, turnInClock = t.clock, rows = {},
        unchosenEligible = 0, unchosenUnlocked = 0, chosenUnlocked = 0 }
    local chosen = positive(t.chosen) and t.chosen or (positive(t.fallbackChoice) and t.fallbackChoice) or nil
    v.chosenUsed = chosen
    for _, row in ipairs(p.rows) do
        local r = { kind = row.kind, index = row.index, itemID = row.itemID, name = row.name, sourceID = row.sourceID,
            appearanceID = row.appearanceID, usable = row.usable, playerCan = row.playerCan,
            hadSource = row.hadSource, hadAppearance = row.hadAppearance,
            isChosen = row.kind == "choice" and chosen ~= nil and row.index == chosen or nil }
        if positive(row.sourceID) then
            r.hasNow = first(read("C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance", row.sourceID))
            local b = first(read("C_TransmogCollection.GetAppearanceInfoBySource", row.sourceID))
            r.appearanceNow = field(b, "appearanceIsCollected")
            -- Events may precede QUEST_TURNED_IN, so the window is measured from the reward sample.
            r.addedEvent = addedSince(row.sourceID, p.clock)
            if row.hadSource == true then r.verdict = "already-had"
            elseif r.hasNow == true or r.addedEvent then r.verdict = "unlocked"
            elseif r.hasNow == false then r.verdict = "not-unlocked"
            else r.verdict = "unknown" end
            if row.kind == "choice" and row.hadSource ~= true then
                if r.isChosen then
                    if r.verdict == "unlocked" then v.chosenUnlocked = v.chosenUnlocked + 1 end
                else
                    v.unchosenEligible = v.unchosenEligible + 1
                    if r.verdict == "unlocked" then v.unchosenUnlocked = v.unchosenUnlocked + 1 end
                end
            end
        else
            r.verdict = "no-appearance"
        end
        v.rows[#v.rows + 1] = r
    end
    return v
end

local function base(kind)
    return { probeVersion = VERSION, kind = kind, capturedAt = read("GetServerTime"), monotonicTime = read("GetTime"),
        build = read("GetBuildInfo"), locale = read("GetLocale"), projectID = safe(WOW_PROJECT_ID),
        camelotID = safe(WOW_PROJECT_CAMELOT), guid = read("UnitGUID", "player"), name = read("UnitFullName", "player"),
        level = read("UnitLevel", "player"), class = read("UnitClass", "player"), sessionID = session.id,
        gameMode = read("C_GameRules.GetActiveGameMode"), observationsOnly = true,
        location = { map = read("C_Map.GetBestMapForUnit", "player"), instance = read("GetInstanceInfo"),
            zone = read("GetRealZoneText") },
        numSources = read("C_TransmogCollection.GetNumTransmogSources"), hasAny = read("C_TransmogCollection.HasAnyAppearance"),
        latest = read("C_TransmogCollection.GetLatestAppearance"),
        added = safe(session.added), addedTotal = session.addedTotal, eventCounts = safe(session.counts),
        events = safe(session.events), registration = safe(P.registration) }
end
local function capture(kind, arg)
    if not db then say("unavailable"); return end
    if not inWorld then say("not_ready"); return end
    local s, rows = base(kind), 0
    if kind == "scan" then
        s.display, s.categories, s.sets = collectDisplay(), collectCategories(), collectSets()
        rows = #s.categories
    elseif kind == "item" then
        s.items = { itemRow(arg) }; rows = 1
    elseif kind == "cat" then
        s.category = collectCategory(arg); rows = s.category.total
    elseif kind == "bags" then
        s.items, s.bagItemsSeen = collectBags(); rows = #s.items
    elseif kind == "quest" or kind == "quest-auto" then
        s.quest = collectQuest(); rows = #s.quest.choiceRows + #s.quest.rewardRows
    elseif kind == "verify" then
        s.verify = collectVerify()
        if not s.verify then say("no_pending"); return end
        rows = #s.verify.rows
    end
    db.nextSample = db.nextSample + 1; s.id = db.nextSample
    if s.quest then session.pendingQuest, session.chosen = pendingFrom(s.id, s.quest), nil end
    db.samples[#db.samples + 1] = s
    while #db.samples > MAX_SAMPLES do table.remove(db.samples, 1) end
    say("sampled", s.id, kind, rows)
    return s
end

local function str(v) if type(v) == "table" then return "<table>" end return tostring(v) end
local function line(out, ...) local p = {} for i = 1, select("#", ...) do p[i] = str((select(i, ...))) end out[#out + 1] = table.concat(p, " ") end
local function sorted(map)
    local parts = {}
    for k, v in pairs(map or {}) do parts[#parts + 1] = tostring(k) .. "=" .. str(v) end
    table.sort(parts)
    return table.concat(parts, " ")
end
local function sourceLine(out, prefix, src)
    local i = first(src.info)
    local b = first(src.bySource)
    line(out, prefix, "source", src.sourceID, "item", type(i) == "table" and i.itemID, type(i) == "table" and i.name,
        "q", type(i) == "table" and i.quality, "type", type(i) == "table" and i.sourceType, "cat", type(i) == "table" and i.categoryID,
        "srcCollected", type(i) == "table" and i.isCollected, "has", first(src.has), "known", first(src.known),
        "playerCan", value(src.playerCan, 1), value(src.playerCan, 2), "accountCan", value(src.accountCan, 1), value(src.accountCan, 2))
    if type(b) == "table" then
        line(out, prefix, "  appearance", b.appearanceID, "appCollected", b.appearanceIsCollected, "srcCollected", b.sourceIsCollected,
            "permanent", b.sourceIsCollectedPermanent, "conditional", b.sourceIsCollectedConditional, "usable", b.appearanceIsUsable,
            "nonLevelReq", b.appearanceHasAnyNonLevelRequirements, b.appearanceMeetsNonLevelRequirements,
            "playerCond", b.meetsTransmogPlayerCondition, "numSources", b.appearanceNumSources, "anyValid", b.isAnySourceValidForPlayer)
    end
    local drops, sets = first(src.drops), first(src.sets)
    line(out, prefix, "  drops", type(drops) == "table" and #drops or src.drops and src.drops.status,
        "holiday", first(src.holiday), "sets", type(sets) == "table" and table.concat(sets, ",") or src.sets and src.sets.status,
        "useError", type(i) == "table" and i.useError, type(i) == "table" and i.useErrorType)
    if type(drops) == "table" then
        for _, d in ipairs(drops) do
            if type(d) == "table" then line(out, prefix, "    drop", d.instance, d.instanceType, d.encounter) end
        end
    end
end
local function itemLines(out, r)
    line(out, "item", r.ref, "name", value(r.info, 1), "q", value(r.info, 3), "ilvl", value(r.info, 4), "req", value(r.info, 5),
        "equip", value(r.instant, 4), "class", value(r.instant, 6), value(r.instant, 7), "bind", value(r.info, 14),
        "sell", value(r.info, 11), "load", r.requestedLoad)
    line(out, "  tmog", "appearance", value(r.tmog, 1), "source", value(r.tmog, 2), r.tmog and r.tmog.status,
        "has", first(r.has), "hasByInfo", first(r.hasByInfo), "learnSet", first(r.learnSet))
    if r.source then sourceLine(out, " ", r.source) end
    for _, o in ipairs(r.others or {}) do
        local i = first(o.info)
        line(out, "  other", o.sourceID, "item", type(i) == "table" and i.itemID, type(i) == "table" and i.name,
            "type", type(i) == "table" and i.sourceType, "collected", type(i) == "table" and i.isCollected, "has", first(o.has))
    end
    if r.othersTruncated then line(out, "  others truncated") end
end
-- Compact copyable summary; the full raw sample is in SavedVariables after reload/logout.
local function reportText()
    if not db or #db.samples == 0 then return nil end
    local s, out = db.samples[#db.samples], {}
    line(out, "YiboTransmogForeverProbe", VERSION, "sample", s.id, s.kind, "session", s.sessionID)
    line(out, "build", value(s.build, 1), value(s.build, 2), value(s.build, 4), "project", s.projectID, s.camelotID, "locale", first(s.locale))
    line(out, "player", value(s.name, 1), "level", first(s.level), "class", value(s.class, 2), "gameMode", first(s.gameMode))
    line(out, "map", first(s.location.map), "zone", first(s.location.zone), "instance", value(s.location.instance, 1),
        value(s.location.instance, 2), value(s.location.instance, 8))
    line(out, "collection", "numSources", first(s.numSources), "hasAny", first(s.hasAny), "latest", value(s.latest, 1), value(s.latest, 2))
    if s.display then
        local d = s.display
        local outfits, situations = first(d.outfits), first(d.situations)
        line(out, "display", "transmogEnabled", first(d.transmogEnabled), d.transmogEnabled.status, "preset", first(d.preset),
            "situations", first(d.situationsEnabled), "situationCats", type(situations) == "table" and #situations,
            "activeOutfit", first(d.activeOutfit), "gearDisplayed", first(d.equippedGearDisplayed), "gearLocked", first(d.equippedGearLocked))
        line(out, "  outfits", type(outfits) == "table" and #outfits, "maxUsable", first(d.maxUsableOutfits), "event", first(d.eventActive),
            first(d.inEvent), "atNPC", first(d.atNPC))
        line(out, "  filters", "collected", first(d.collectedShown), "uncollected", first(d.uncollectedShown),
            "default", first(d.defaultFilters), "class", first(d.classFilter), "cvarList", d.cvarListStatus)
        for _, c in ipairs(d.cvars) do line(out, "  cvar", c.name, first(c.value)) end
        if type(situations) == "table" then
            for _, cat in ipairs(situations) do
                if type(cat) == "table" then line(out, "  situationCat", cat.name, cat.triggerID, cat.isRadioButton) end
            end
        end
    end
    for _, c in ipairs(s.categories or {}) do
        line(out, "cat", c.id, value(c.info, 1), "weapon", value(c.info, 2), "collected", first(c.collected), "total", first(c.total),
            "filtered", first(c.filteredCollected), "/", first(c.filteredTotal))
    end
    if s.sets then
        local t = s.sets
        line(out, "sets", "status", t.all.status, "count", t.count, "collected", t.collected, "hiddenUntilCollected", t.hidden,
            "validForChar", t.valid, "limited", t.limited, "fullBase", value(t.fullBase, 1), value(t.fullBase, 2),
            "validBase", value(t.validBase, 1), value(t.validBase, 2), "hasAnyValid", first(t.hasAnyValid))
        line(out, "  byExpansion", sorted(t.byExpansion))
        for _, r in ipairs(t.rows) do
            line(out, "  set", r.setID, r.name, "label", r.label, "base", r.baseSetID, "exp", r.expansionID, "patch", r.patchID,
                "class", r.classMask, "collected", r.collected, "valid", r.validForCharacter, "hidden", r.hiddenUntilCollected)
        end
    end
    if s.category then
        local c = s.category
        line(out, "category", c.id, value(c.info, 1), c.status, "appearances", c.total, "collected", c.collected, "usable", c.usable,
            "hiddenVisual", c.hidden, "scanned", c.scanned, "truncated", c.scanTruncated)
        line(out, "  sources", c.sourceCollected, "/", c.sourceTotal, "byType", sorted(c.sourceTypes))
        for _, group in ipairs({ { "have", c.collectedRows }, { "miss", c.missingRows } }) do
            for _, r in ipairs(group[2]) do
                line(out, "  " .. group[1], r.visualID, "usable", r.isUsable, "display", r.canDisplayOnPlayer, "minIlvl", r.minIlvl,
                    "holiday", r.hasRequiredHoliday, "sources", r.sourceCount)
                for _, src in ipairs(r.sources) do
                    line(out, "    src", src.sourceID, "item", src.itemID, src.name, "q", src.quality, "type", src.sourceType,
                        "collected", src.isCollected, "playerCan", src.playerCanCollect, "valid", src.isValidSourceForPlayer, "err", src.useError)
                end
            end
        end
    end
    if s.quest then
        local q = s.quest
        line(out, "quest", first(q.questID), first(q.title), "choices", first(q.choices), "rewards", first(q.rewards), "money", first(q.money))
        line(out, "questApi", sorted(q.api))
        for _, group in ipairs({ { "choice", q.choiceRows }, { "reward", q.rewardRows } }) do
            for _, r in ipairs(group[2]) do
                line(out, group[1], r.index, "usable", value(r.questItemInfo, 5))
                if r.info then itemLines(out, r) end
            end
        end
    end
    if s.verify then
        local v = s.verify
        line(out, "verify", "quest", v.questID, v.title, "turnedIn", v.turnedInQuestID, "fromSample", v.sampleID,
            "chosen", v.chosen, "fallback", v.fallbackChoice, "used", v.chosenUsed)
        line(out, "verify", "unchosenUnlocked", v.unchosenUnlocked, "/", v.unchosenEligible, "chosenUnlocked", v.chosenUnlocked)
        for _, r in ipairs(v.rows) do
            line(out, "  " .. r.kind, r.index, r.name, "item", r.itemID, "source", r.sourceID, "chosen", r.isChosen,
                "usable", r.usable, "playerCan", r.playerCan, "before", r.hadSource, r.hadAppearance,
                "now", r.hasNow, r.appearanceNow, "event", r.addedEvent, "=>", r.verdict)
        end
    end
    if s.items and not s.quest then
        if s.bagItemsSeen then line(out, "bags", "itemsSeen", s.bagItemsSeen, "equippable", #s.items) end
        for _, r in ipairs(s.items) do
            if r.bag then line(out, "bagSlot", r.bag, r.slot, "quality", r.quality, "bound", r.isBound) end
            itemLines(out, r)
        end
    end
    line(out, "added", "sessionTotal", s.addedTotal)
    for _, a in ipairs(type(s.added) == "table" and s.added or {}) do
        line(out, "  added", a.event, a.sourceID, "item", a.itemID, a.name, "type", a.sourceType, "clock", a.clock)
    end
    line(out, "events", sorted(s.eventCounts))
    line(out, "hook", "GetQuestReward", type(s.registration) == "table" and s.registration.GetQuestRewardHook)
    return table.concat(out, "\n")
end
local function report()
    local content = reportText()
    if not content then say("no_sample"); return end
    if not reportWindow then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(760, 520); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.04, 0.98)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -14); title:SetText(P.text.title)
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(90, 24); close:SetPoint("BOTTOM", 0, 10); close:SetText(P.text.close)
        close:SetScript("OnClick", function() f:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40); scroll:SetPoint("BOTTOMRIGHT", -34, 44)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(690); edit:SetMaxLetters(0); edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit); f.edit = edit; reportWindow = f
    end
    reportWindow:Show(); reportWindow.edit:SetText(content); reportWindow.edit:SetFocus(); reportWindow.edit:HighlightText()
end

local ADDED_EVENTS = { TRANSMOG_COLLECTION_SOURCE_ADDED = true, TRANSMOG_COLLECTION_SOURCE_REMOVED = true,
    TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED = true }
local frame = CreateFrame("Frame")
P.registration = {}
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
    "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED", "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_ITEM_UPDATE", "TRANSMOG_SOURCE_COLLECTABILITY_UPDATE",
    "TRANSMOG_DISPLAYED_OUTFIT_CHANGED", "TRANSMOG_OUTFITS_CHANGED", "TRANSMOGRIFY_OPEN", "TRANSMOGRIFY_CLOSE",
    "CVAR_UPDATE", "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_TURNED_IN",
    "LOOT_OPENED", "CHAT_MSG_LOOT", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_BATTLEGROUND", "PLAYER_LEVEL_UP" }) do
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    P.registration[event] = ok and "registered" or safe(err)
end
frame:SetScript("OnEvent", function(_, event, ...)
    local arg = ...
    if event == "ADDON_LOADED" and arg == addonName then
        if session then return end
        if not isForever() then say("unavailable"); return end
        local existing = YiboTransmogForeverProbeDB
        if not validStore(existing) then say("unavailable"); return end
        YiboTransmogForeverProbeDB = existing or { schema = 1, nextSample = 0, sessions = 0, samples = {} }
        db = YiboTransmogForeverProbeDB; db.sessions = db.sessions + 1
        session = { id = db.sessions, events = {}, counts = {}, added = {}, addedTotal = 0 }
        say("ready")
    end
    if not session or (event == "ADDON_LOADED" and arg ~= addonName) then return end
    if event == "PLAYER_ENTERING_WORLD" then inWorld = true end
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then inWorld = false end
    session.counts[event] = (session.counts[event] or 0) + 1
    if ADDED_EVENTS[event] then
        session.addedTotal = session.addedTotal + 1
        if #session.added < MAX_ADDED then
            local info = positive(arg) and first(read("C_TransmogCollection.GetSourceInfo", arg))
            session.added[#session.added + 1] = { event = event, sourceID = safe(arg), clock = first(read("GetTime")),
                itemID = type(info) == "table" and info.itemID or nil, name = type(info) == "table" and info.name or nil,
                sourceType = type(info) == "table" and info.sourceType or nil }
        end
        return
    end
    if event == "CHAT_MSG_LOOT" and session.counts[event] > 16 then return end
    if event == "TRANSMOG_COLLECTION_UPDATED" and session.counts[event] > 16 then return end
    session.events[#session.events + 1] = { event = event, clock = first(read("GetTime")), args = safe(pack(...)) }
    while #session.events > MAX_EVENTS do table.remove(session.events, 1) end
    -- Reward rows are read when the quest-complete window opens; nothing is selected or turned in.
    -- 0.1.2: quests without item rewards are skipped so they no longer push useful samples out of the cap.
    if event == "QUEST_COMPLETE" and inWorld and db then
        local items = (tonumber(first(read("GetNumQuestChoices"))) or 0) + (tonumber(first(read("GetNumQuestRewards"))) or 0)
        if items > 0 then capture("quest-auto") end
    end
    local p = session.pendingQuest
    if event == "QUEST_TURNED_IN" and p and not p.turnedIn and (not positive(p.questID) or p.questID == arg) then
        p.turnedIn = { questID = safe(arg), clock = first(read("GetTime")), chosen = session.chosen and session.chosen.choice,
            fallbackChoice = QuestInfoFrame and safe(QuestInfoFrame.itemChoice) or nil }
        -- Collection events can arrive after the turn-in; sample once after a short delay, /ytf verify repeats it.
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(3, function() if inWorld then capture("verify") end end)
        end
    end
end)
-- Post-hook only records the chosen index; the original GetQuestReward runs unchanged.
if type(hooksecurefunc) == "function" and type(GetQuestReward) == "function" then
    P.registration.GetQuestRewardHook = select(1, pcall(hooksecurefunc, "GetQuestReward", function(choice)
        if session then session.chosen = { choice = safe(choice), clock = first(read("GetTime")) } end
    end)) and "hooked" or "failed"
else
    P.registration.GetQuestRewardHook = "unavailable"
end
SLASH_YIBOTRANSMOGFOREVERPROBE1 = "/ytf"
SlashCmdList.YIBOTRANSMOGFOREVERPROBE = function(message)
    local command, argument = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "report" then
        local ok, err = pcall(report); if not ok then say("report_error", tostring(err)) end
    elseif command == "scan" or command == "bags" or command == "verify" then
        capture(command)
    elseif command == "quest" then
        if not (QuestFrame and QuestFrame:IsShown()) then say("no_quest"); return end
        capture("quest")
    elseif command == "item" then
        local id = tonumber(argument)
        local link = string.match(argument or "", "|H(item:[^|]+)|h")
        if positive(id) then capture("item", id)
        elseif link then capture("item", argument)
        else say("invalid") end
    elseif command == "cat" then
        local id = tonumber(argument)
        if not positive(id) then say("invalid"); return end
        capture("cat", id)
    else say("help") end
end
P.capture, P.reportText = capture, reportText
