-- Transaction boundary for native discovery. The target owns durable storage,
-- client validation and events; this object stages before a guarded commit.
local Addon = _G.YiboCurrency
local Session = {}; Session.__index = Session
Addon.NativeSession = Session

function Session:New(hooks)
    assert(type(hooks) == "table" and type(hooks.Identity) == "function"
        and type(hooks.IsReady) == "function" and type(hooks.Load) == "function"
        and type(hooks.Commit) == "function" and type(hooks.Now) == "function"
        and type(hooks.Adapter) == "table")
    return setmetatable({ hooks = hooks, current = nil }, self)
end

function Session:Invalidate()
    self.current = nil
end

function Session:Scan(expected)
    local hooks = self.hooks
    if not hooks:IsReady() then self:Invalidate(); return false, "not-ready" end
    local identity = hooks:Identity()
    if type(identity) ~= "string" or identity == "" or (expected and expected ~= identity) then
        self:Invalidate(); return false, "identity"
    end
    local state = hooks:Load(identity)
    if type(state) ~= "table" or type(state.directory) ~= "table" or type(state.snapshot) ~= "table" then
        self:Invalidate(); return false, "invalid-state"
    end
    local stamp = hooks:Now()
    local ok, directory, observations, complete = pcall(Addon.NativeDiscovery.Collect,
        Addon.NativeDiscovery, hooks.Adapter, state.directory, stamp)
    if not ok then self:Invalidate(); return false, "scan-error" end
    local snapshot = Addon.NativeDiscovery:MergeSnapshot(state.snapshot, observations)
    if not hooks:IsReady() or hooks:Identity() ~= identity then
        self:Invalidate(); return false, "identity-changed"
    end
    -- Commit itself must reject stale identities and write both values atomically.
    local committed = hooks:Commit(identity, directory, snapshot)
    if not committed then self:Invalidate(); return false, "commit-failed" end
    self.current = { identity = identity, observations = observations }
    return complete, complete and nil or "partial"
end

function Session:Value(identity, snapshot, id)
    local current = self.current
    local observations = current and current.identity == identity and current.observations or nil
    return Addon.NativeDiscovery:GetValue(snapshot, observations, id)
end
