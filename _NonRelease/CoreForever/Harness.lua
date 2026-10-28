-- Shared test boot: load actual client manifests into isolated Lua environments.
local function Boot(forever, saved, projectID, configure)
    local env = setmetatable({ TEST_FOREVER = forever, TEST_MESSAGES = {}, TEST_TIMERS = {},
        WOW_PROJECT_ID = projectID or (forever and 18 or 19), WOW_PROJECT_CAMELOT = forever and 18 or nil,
        YiboCoreForeverDB = forever and saved or nil, YiboCoreDB = not forever and saved or { sentinel = "mists" },
    }, { __index = _G })
    env._G = env
    local function Load(path, addonName)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk(addonName or "YiboCore", {})
    end
    Load("_NonRelease/CoreForever/FrameFixture.lua")
    if configure then configure(env) end
    local toc = forever and "YiboCore_Forever.toc" or "YiboCore_Mists.toc"
    for line in io.lines("YiboCore/" .. toc) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then Load("YiboCore/" .. line:gsub("\\", "/")) end
    end
    local function Event(event, ...)
        local args = { ... }; if event == "ADDON_LOADED" and #args == 0 then args = { "YiboCore" } end
        for _, f in ipairs(env.TEST_FRAMES) do
            if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, unpack(args)) end
        end
    end
    local function Flush()
        local pending = env.TEST_TIMERS; env.TEST_TIMERS = {}
        for _, timer in ipairs(pending) do timer[2]() end
    end
    return env, env.YiboCore, Event, Flush, Load
end

return Boot
