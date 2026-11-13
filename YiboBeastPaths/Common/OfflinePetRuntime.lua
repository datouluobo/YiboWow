local addonName, ns = ...
if not ns.YBP_TARGET_OK then return end

local owner = "YiboBeastPaths"
local frame = CreateFrame("Frame")
local integration, integrationCore, waitingCore, lastReason, capture
local stableOpen, updatePending, stableGeneration = false, false, 0
local function Ready() end

local function CorrectTarget()
    return (ns.YBP_TARGET == "Retail" and type(_G.WOW_PROJECT_MAINLINE) == "number"
            and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
        or (ns.YBP_TARGET == "Mists" and type(_G.WOW_PROJECT_MISTS_CLASSIC) == "number"
            and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MISTS_CLASSIC)
end

local function Start()
    if not ns.YBP_TARGET_OK or not CorrectTarget() then return false end
    local core = _G.YiboCore
    local ready, reason = ns.CheckOfflinePetCore(core)
    if not ready then lastReason = reason; return false end
    if not (ns.RegisterLocale(core) and _G.YiboBeastPaths and _G.YiboBeastPaths.db) then
        lastReason = "not-ready"; return false
    end
    local root = _G.YiboBeastPaths.db
    local valid, err = ns.OfflinePetSnapshot.CheckStore(root, ns.YBP_TARGET)
    if not valid and err ~= "invalid-store" then lastReason = err; return false end
    if not core:RegisterAddon(owner, { requiredAPI = 13, version = "1.9.0" }) then
        lastReason = "upgrade"; return false
    end
    if not integration or integrationCore ~= core then
        local function text(key, ...) return core.Locale:Get(owner, key, ...) end
        integrationCore = core
        integration = ns.OfflinePetPage.New(core, root, ns.YBP_TARGET,
            ns.CreateOfflinePetRenderer(core, text), text,
            function() if capture then capture:Invalidate() end end)
        ns.IsUnifiedPageReady = function()
            return CorrectTarget() and _G.YiboCore == core and integration.active
                and ns.CheckOfflinePetCore(core) == true
        end
        capture = ns.OfflinePetCapture.New({
            target = ns.YBP_TARGET,
            Root = function() return _G.YiboBeastPaths and _G.YiboBeastPaths.db end,
            Now = function() return type(_G.time) == "function" and _G.time() or nil end,
            Read = function() return ns.ReadOfflinePets() end,
            SaveObservations = true,
            Schedule = function(callback)
                if not (_G.C_Timer and type(_G.C_Timer.After) == "function") then error("timer unavailable") end
                _G.C_Timer.After(1.25, callback)
            end,
            Notify = function() core.AccountView:NotifyPageChanged("yibo-beastpaths-offline-pets") end,
            Valid = function(id)
                if not stableOpen or not CorrectTarget() or _G.YiboCore ~= core or not integration.active
                    or not _G.YiboBeastPaths or _G.YiboBeastPaths.db ~= root
                    or not ns.CheckOfflinePetCore(core) then return false end
                local _, class = UnitClass("player")
                return class == "HUNTER" and core.Characters:GetCurrentID() == id
            end,
            -- No VerifiedPolicy is registered: real completeness is not yet proven.
        })
    end
    local ok, failure = integration:Start()
    if not ok then lastReason = failure; return false end
    if waitingCore then waitingCore.Events:Unregister("CORE_READY", owner .. ":offline", Ready); waitingCore = nil end
    lastReason = nil
    return true
end

local function AttemptStableRead()
    if not stableOpen or not CorrectTarget() or not Start() then return end
    local _, class = UnitClass("player")
    local characterID = integrationCore.Characters:GetCurrentID()
    if class == "HUNTER" and type(characterID) == "string" and characterID ~= "" then
        capture:Attempt(characterID)
    end
end

Ready = function()
    if Start() and stableOpen then AttemptStableRead() end
end

local function QueueStableUpdate()
    if not stableOpen then return end
    if capture then capture:Invalidate() end
    if updatePending or not (_G.C_Timer and type(_G.C_Timer.After) == "function") then return end
    updatePending = true
    local generation = stableGeneration
    local ok = pcall(_G.C_Timer.After, 0.25, function()
        if generation ~= stableGeneration then return end
        updatePending = false
        AttemptStableRead()
    end)
    if not ok then updatePending = false end
end

function _G.YiboBeastPaths:OpenOfflinePets(tab)
    if Start() then
        integration:SelectTab(tab == "maintenance" and "maintenance" or "stable")
        if integrationCore.AccountView:Toggle("yibo-beastpaths-offline-pets") == false then return false end
        return true
    end
    local key = (lastReason == "invalid-root" or lastReason == "invalid-store") and "OFFLINE_STORE_INVALID"
        or lastReason == "missing" and "OFFLINE_CORE_MISSING"
        or lastReason == "not-ready" and "OFFLINE_CORE_NOT_READY" or "OFFLINE_CORE_UPGRADE"
    print(ns.Text(key))
    return false
end
local function Watch()
    local core = _G.YiboCore
    if core and core.Events and core.Events.Register and core.Events.Unregister and waitingCore ~= core then
        if waitingCore then waitingCore.Events:Unregister("CORE_READY", owner .. ":offline", Ready) end
        waitingCore = core
        core.Events:Register("CORE_READY", owner .. ":offline", Ready)
    end
end

frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and (name == addonName or name == "YiboCore")) then
        local wasActive = integration and integration.active
        if not Start() then Watch()
        elseif stableOpen and not wasActive then AttemptStableRead() end
    elseif event == "PET_STABLE_SHOW" then
        stableGeneration = stableGeneration + 1
        stableOpen, updatePending = true, false
        if capture then capture:Invalidate() end
        AttemptStableRead()
    elseif event == "PET_STABLE_UPDATE" then
        QueueStableUpdate()
    elseif event == "PET_STABLE_CLOSED" or event == "PLAYER_ENTERING_WORLD" then
        stableGeneration = stableGeneration + 1
        stableOpen, updatePending = false, false
        if capture then capture:Invalidate() end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PET_STABLE_SHOW")
frame:RegisterEvent("PET_STABLE_UPDATE")
frame:RegisterEvent("PET_STABLE_CLOSED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
