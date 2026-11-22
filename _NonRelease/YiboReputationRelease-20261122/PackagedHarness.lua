-- Boot the real published Core package and then a business addon package root,
-- in client order: Core files, ADDON_LOADED(YiboCore), addon files from the
-- package's default TOC, ADDON_LOADED(addon), PLAYER_LOGIN.  Synthetic client
-- (FrameFixture); the Core and addon Lua files are the extracted ZIP contents.
local CoreBoot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
return function(o)
    local env, core, fire, flush = CoreBoot(o.client, o.coreSaved, o.projectID, o.configure, nil,
        o.coreRoot .. '/YiboCore', 'YiboCore.toc')
    fire('ADDON_LOADED')
    local registrations = {}
    if core and type(core.RegisterAddon) == 'function' then
        local original = core.RegisterAddon
        core.RegisterAddon = function(self, name, metadata)
            registrations[name] = (registrations[name] or 0) + 1
            registrations.last = metadata
            return original(self, name, metadata)
        end
    end
    for key, value in pairs(o.saved or {}) do env[key] = value end
    if o.beforeAddon then o.beforeAddon(env, core) end
    local ns = {}
    local root = o.addonRoot .. '/' .. o.addonName
    local loaded = {}
    for line in io.lines(root .. '/' .. o.addonName .. '.toc') do
        line = line:gsub('\r', ''):match('^%s*(.-)%s*$')
        if line:match('%.lua$') and not line:match('^#') then
            local chunk = assert(loadfile(root .. '/' .. line:gsub('\\', '/')))
            setfenv(chunk, env); chunk(o.addonName, ns)
            loaded[#loaded + 1] = line
        end
    end
    fire('ADDON_LOADED', o.addonName)
    fire('PLAYER_LOGIN')
    local function Flush()
        for _ = 1, 30 do
            if #env.TEST_TIMERS == 0 then return end
            flush()
        end
        error('timer loop')
    end
    return { env = env, core = core, fire = fire, flush = Flush, ns = ns, registrations = registrations, loaded = loaded }
end
