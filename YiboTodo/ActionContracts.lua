local Addon = _G.YiboTodo
local Contracts = {}
Addon.ActionContracts = Contracts

local function Source(adapter)
    return { adapter = adapter, definition = { name = "action.todo", kind = "provider", providerID = adapter.PROVIDER,
        version = { major = 1, minor = 0 }, methods = { Query = function(request) return adapter:Query(request) end } } }
end
local sources = { Source(Addon.ActionTodo), Source(Addon.ActionNomi) }
if Addon.ActionActivities then sources[#sources + 1] = Source(Addon.ActionActivities) end

local function HasRegistration()
    for _, source in ipairs(sources) do if source.ref then return true end end
    return false
end

function Contracts:Initialize()
    local core = Addon.Core
    if not (core and core:CheckAPIVersion(11) and core:HasCapability("business-providers", 1)
        and core.Contracts and type(core.Contracts.List) == "function") then
        return nil, "行动中心集成需要升级 YiboCore 至 API v11；账号待办基础功能仍可使用。"
    end
    if Addon.GoalTargets then Addon.GoalTargets:Initialize() end
    for _, source in ipairs(sources) do
        if not source.ref then
            local _, meta = source.adapter:Commit()
            source.notifiedRevision = meta.revision
            local ref, err = core.Contracts:Register(Addon.NAME, source.definition)
            if not ref then return nil, err end
            source.ref = ref
        end
    end
    return true
end

function Contracts:Changed()
    if not HasRegistration() then return end
    if self.queued then return end
    self.queued = true
    local generation = self.generation
    local function Flush()
        if generation ~= Contracts.generation then return end
        Contracts.queued = nil
        if Addon.GoalTargets then Addon.GoalTargets:Changed() end
        for _, source in ipairs(sources) do
            if source.ref then
                local _, meta = source.adapter:Commit()
                if meta.revision ~= source.notifiedRevision then
                    source.notifiedRevision = meta.revision
                    Addon.Core.Contracts:NotifyChanged(Addon.NAME, source.ref,
                        { sourceEpoch = meta.sourceEpoch, revision = meta.revision, reason = "source-projection-changed" })
                end
            end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end

function Contracts:Shutdown()
    if Addon.GoalTargets and Addon.GoalTargets.ref then Addon.Core.Contracts:Unregister(Addon.NAME, Addon.GoalTargets.ref); Addon.GoalTargets.ref = nil end
    self.generation, self.queued = (self.generation or 0) + 1, nil
    for _, source in ipairs(sources) do
        if source.ref then
            local ref = source.ref
            source.ref = nil
            Addon.Core.Contracts:Unregister(Addon.NAME, ref)
        end
    end
end
