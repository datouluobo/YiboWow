-- Scheduling is shared; target code supplies identity, scan, and timer hooks.
-- A generation guard prevents queued work after logout or character changes.
local Addon = _G.YiboCurrency
local Refresh = {}; Refresh.__index = Refresh
Addon.NativeRefresh = Refresh

function Refresh:New(hooks)
    assert(type(hooks) == "table" and type(hooks.Identity) == "function"
        and type(hooks.Scan) == "function" and type(hooks.After) == "function")
    return setmetatable({ hooks = hooks, generation = 0, retries = 0 }, self)
end

function Refresh:Cancel()
    self.generation = self.generation + 1
    self.queued, self.pending, self.retries = false, false, 0
end

function Refresh:Request()
    self.pending = true
    if self.queued then return end
    self.retries = 0
    self:Queue()
end

function Refresh:Queue()
    if self.queued then return end
    self.queued = true
    local generation = self.generation
    self.hooks:After(0.2, function()
        if generation ~= self.generation then return end
        self.queued = false
        if not self.pending then return end
        self.pending = false
        local identity = self.hooks:Identity()
        if not identity then return end
        -- Scan owns commit and must recheck identity immediately before writing.
        local ok, complete = pcall(self.hooks.Scan, self.hooks, identity)
        if generation ~= self.generation then return end
        if (not ok or complete ~= true) and self.hooks:Identity() == identity and self.retries < 3 then
            self.retries = self.retries + 1
            self.pending = true
            self:Queue()
        end
        if self.pending and not self.queued then self:Queue() end
    end)
end
