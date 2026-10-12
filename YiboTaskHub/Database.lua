local Addon = _G.YiboTaskHub
local Database = {}
Addon.Database = Database

function Database:Initialize()
    Addon.db = nil
    if type(_G.YiboTaskHubDB) ~= "table" then _G.YiboTaskHubDB = {} end
    local db = _G.YiboTaskHubDB
    if tonumber(db.schemaVersion) and tonumber(db.schemaVersion) > 4 then return nil, Addon:T("TEXT.THE_ACTION_HUB_DATABASE_IS_NEWER_UPD.F19A82") end
    -- Commit the schema version only after the goal migration succeeds.
    if type(db.settings) ~= "table" then db.settings = {} end
    if type(db.settings.sourceFilter) ~= "string" then db.settings.sourceFilter = "all" end
    local s = db.settings
    if type(s.hiddenWork) ~= "table" then s.hiddenWork = {} end
    if not ({ all = true, ready = true, unknown = true, waiting = true })[s.workFilter] then s.workFilter = "all" end
    if type(s.previewColumns) ~= "table" then s.previewColumns = {} end
    for _, id in ipairs({ "work", "beneficiary", "source", "status" }) do
        if type(s.previewColumns[id]) ~= "boolean" then s.previewColumns[id] = true end
    end
    if type(s.hudEnabled) ~= "boolean" then s.hudEnabled = true end
    if type(s.showOtherCharacters) ~= "boolean" then s.showOtherCharacters = true end
    if type(s.bossTargetsAutoDisplay) ~= "boolean" then s.bossTargetsAutoDisplay = true end
    if type(db.bossTargets) ~= "table" then db.bossTargets = {} end
    local targets = db.bossTargets
    targets.byCharacter = type(targets.byCharacter) == "table" and targets.byCharacter or {}
    targets.sourceEpoch = targets.sourceEpoch or ("targets:" .. tostring(Addon:Now()) .. ":" .. tostring(math.random(100000, 999999)))
    targets.revision = tonumber(targets.revision) or 0
    targets.nextID = tonumber(targets.nextID) or 0
    if type(s.hudLocked) ~= "boolean" then s.hudLocked = false end
    if not ({ summary = true, hud = true, list = true })[s.reminderMode] then s.reminderMode = "summary" end
    if not ({ [3] = true, [5] = true, [8] = true, [12] = true })[s.hudRows] then s.hudRows = 5 end
    if type(db.goals) ~= "table" then
        local function Clone(v)
            if type(v) ~= "table" then return v end
            local out = {}; for k, x in pairs(v) do out[k] = Clone(x) end; return out
        end
        local goals = { byID = {}, revision = 0, nextID = 0 }
        for characterID, list in pairs(targets.byCharacter) do
            if type(characterID) ~= "string" or type(list) ~= "table" then return nil, Addon:T("TEXT.THE_LEGACY_BOSS_GOAL_FORMAT_IS_INVAL.E34AEC") end
            for _, target in ipairs(list) do
                if type(target) ~= "table" or type(target.id) ~= "string" or type(target.catalogID) ~= "string" then
                    return nil, Addon:T("TEXT.THE_LEGACY_BOSS_GOAL_FORMAT_IS_INVAL.E34AEC")
                end
                goals.nextID = goals.nextID + 1
                local id = "goal:" .. goals.nextID
                goals.byID[id] = { id = id, title = target.title or target.catalogID, state = target.active == false and "paused" or "active",
                    priority = 0, revision = 1, createdAt = Addon:Now(), updatedAt = Addon:Now(), history = {}, legacyBossID = target.id,
                    intent = { providerID = "YiboAltoBoss:targets", objectID = target.catalogID, targetType = "boss", scope = { mode = "character", characterID = characterID },
                        conditions = Clone(target), repeatPolicy = "recurring" } }
            end
        end
        db.goalMigration = { version = 1, at = Addon:Now(), legacyBossTargets = Clone(targets.byCharacter) }
        db.goals = goals
    end
    db.schemaVersion = 4
    Addon.db = db
    -- Explicit goals/history persist; source snapshots and projections stay in memory.
    return db
end
