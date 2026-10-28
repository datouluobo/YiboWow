-- Actual selected Core manifest in an isolated, synthetic client environment.
return function(target, saved, projectID, configure, nativeAlias, sourceRoot, manifest)
    local projects = { Retail = 1, Mists = 19, Forever = 18 }
    local stores = { Retail = "YiboCoreRetailDB", Mists = "YiboCoreDB", Forever = "YiboCoreForeverDB" }
    local env = setmetatable({ TEST_GUID = "Player-R2-1", TEST_MESSAGES = {}, TEST_TIMERS = {},
        WOW_PROJECT_ID = projectID or projects[target], WOW_PROJECT_MAINLINE = 1, WOW_PROJECT_CAMELOT = 18,
        YiboCoreDB = { sentinel = "mists" }, YiboCoreForeverDB = { sentinel = "forever" },
        YiboCoreRetailDB = { sentinel = "retail" },
    }, { __index = _G })
    env[stores[target]] = saved
    env._G = env
    local function Load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("YiboCore", {})
    end
    Load("_NonRelease/CoreForever/FrameFixture.lua")
    if configure then configure(env) end
    local toc = manifest or ("YiboCore_" .. ((target == "Retail" or nativeAlias) and "Mainline" or target) .. ".toc")
    sourceRoot = sourceRoot or "YiboCore"
    for line in io.lines(sourceRoot .. "/" .. toc) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then Load(sourceRoot .. "/" .. line:gsub("\\", "/")) end
    end
    local function Event(event, ...)
        local args = { ... }; if event == "ADDON_LOADED" and #args == 0 then args = { "YiboCore" } end
        for _, frame in ipairs(env.TEST_FRAMES) do
            if frame.events and frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, unpack(args)) end
        end
    end
    local function Flush()
        local timers = env.TEST_TIMERS; env.TEST_TIMERS = {}
        for _, timer in ipairs(timers) do timer[2]() end
    end
    return env, env.YiboCore, Event, Flush, Load
end
