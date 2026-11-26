local YQB = _G.YQB
local Core = _G.YiboCore
local db, currentID

local function ApplyLegacyMode(runtime, mode)
    runtime.paused = mode == "paused"
    if runtime.paused then mode = YQB.Target.defaultMode end
    runtime.autoReject = mode == "direct"
    runtime.autoAbandon = mode == "abandon" or (mode == "direct" and YQB.Target.legacyDirectAbandons == true)
end

function YQB.MergeTables(target, source)
    target = type(target) == "table" and target or {}
    if type(source) ~= "table" then return target end
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = YQB.MergeTables(type(target[key]) == "table" and target[key] or nil, value)
        elseif target[key] == nil then
            target[key] = value
        elseif type(value) == "boolean" then
            target[key] = target[key] or value
        end
    end
    return target
end

function YQB.BindCurrentCharacter()
    local id = Core.Characters:GetCurrentID()
    if not id then return end
    if currentID and currentID ~= id and db.characterData[currentID] then
        db.characterData[id] = YQB.MergeTables(db.characterData[id], db.characterData[currentID])
        db.characterData[currentID] = nil
    end
    currentID, YQB.curCharacterID = id, id
    db.characterData[id] = db.characterData[id] or { blocked = {}, cache = {} }
end

function YQB.InitializeStore()
    db = _G[YQB.Target.savedVariable] or {}
    if YQB.MigrateDatabase then YQB.MigrateDatabase(db) end
    db.globalBlocked = db.globalBlocked or {}
    db.globalCache = db.globalCache or {}
    db.characterData = db.characterData or {}
    db.settings = db.settings or {}
    db.settings.previewColumns = db.settings.previewColumns or { global = true, characters = true }
    db.settings.groupExpanded = db.settings.groupExpanded or { blocked = true, current = true }
    db.settings.runtime = db.settings.runtime or {}
    local runtime = db.settings.runtime
    if runtime.autoReject == nil and runtime.autoAbandon == nil and runtime.paused == nil then
        local mode = runtime.processMode
        if mode ~= "direct" and mode ~= "abandon" and mode ~= "paused" and mode ~= "notify" then
            mode = YQB.Target.defaultMode
        end
        ApplyLegacyMode(runtime, mode)
    end
    db.filters = db.filters or { showDaily = true, showNormal = true, hideComplete = true }
    if db.filters.reportChat == nil then db.filters.reportChat = true end
    if db.filters.levelExpr == nil then db.filters.levelExpr = YQB.Target.defaultLevel end
    db.diagnostics = type(db.diagnostics) == "table" and db.diagnostics or {}
    db.schemaVersion = YQB.Target.schemaVersion or 3
    _G[YQB.Target.savedVariable] = db
    YQB.BindCurrentCharacter()
    Core.Events:Register("CHARACTER_ID_CHANGED", "YiboQuestBlocker", function(_, oldID, newID)
        local oldData = db.characterData[oldID]
        if oldData then
            db.characterData[newID] = YQB.MergeTables(db.characterData[newID], oldData)
            db.characterData[oldID] = nil
        end
        if currentID == oldID then YQB.BindCurrentCharacter() end
        YQB.NotifyCorePageChanged()
    end)
    YQB.PREFIX = YQB.T("CHAT.PREFIX")
    YQB.PREFIX_ERR, YQB.PREFIX_INFO = YQB.PREFIX, YQB.PREFIX
end

function YQB.GetDatabase() return db end
function YQB.GetCurrentCharacterID() return currentID end

function YQB.PersistDB()
    _G[YQB.Target.savedVariable] = db
end

function YQB.IsChatReportingEnabled() return not not db.filters.reportChat end

function YQB.ReportMessage(message)
    if message and YQB.IsChatReportingEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage(YQB.PREFIX .. " " .. message)
    end
end

function YQB.AddDiagnostic(result, questID, detail)
    local entries = db.diagnostics
    entries[#entries + 1] = { at = time and time() or 0, result = result, questID = questID, detail = detail }
    while #entries > 30 do table.remove(entries, 1) end
end

function YQB.GetDiagnostics() return db.diagnostics end
function YQB.ClearDiagnostics()
    wipe(db.diagnostics)
    YQB.NotifyCorePageChanged()
end

function YQB.GetRuntimeSettings() return db.settings.runtime end

function YQB.IsProcessingPaused() return db.settings.runtime.paused == true end
function YQB.IsAutoRejectEnabled() return not YQB.IsProcessingPaused() and db.settings.runtime.autoReject == true end
function YQB.IsAutoAbandonEnabled() return not YQB.IsProcessingPaused() and db.settings.runtime.autoAbandon == true end

function YQB.GetProcessMode()
    if YQB.IsProcessingPaused() then return "paused" end
    if YQB.IsAutoRejectEnabled() then return "direct" end
    if YQB.IsAutoAbandonEnabled() then return "abandon" end
    return "notify"
end

local function NotifyProcessingChanged()
    db.settings.runtime.processMode = YQB.GetProcessMode()
    if YQB.OnModeChanged then YQB.OnModeChanged() end
    YQB.NotifyCorePageChanged()
end

function YQB.SetProcessingOption(key, enabled)
    if key ~= "autoReject" and key ~= "autoAbandon" and key ~= "paused" then return false end
    db.settings.runtime[key] = enabled == true
    NotifyProcessingChanged()
    return true
end

function YQB.SetProcessMode(mode)
    if mode == "paused" then return YQB.SetProcessingOption("paused", true) end
    if mode ~= "direct" and mode ~= "abandon" and mode ~= "notify" then return false end
    ApplyLegacyMode(db.settings.runtime, mode)
    NotifyProcessingChanged()
    return true
end
