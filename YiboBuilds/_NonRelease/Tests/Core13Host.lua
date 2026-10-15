-- Minimal host for actual Builds modules and the real Core language service.
local function Setup(language)
    local state = { api = 13, ready = true, missing = nil, addonRegistrations = 0, ownerRegistrations = 0, pages = 0, entries = 0 }
    CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(self, _, fn) state.onEvent = fn end } end
    GetServerTime = function() return 1000 end
    YiboBuilds, YiboBuildsDB = nil, nil
    YiboCore = {
        UITheme = { Colors = {}, Font = {} }, Capabilities = { Register = function() end },
        CheckAPIVersion = function(_, required) return state.api >= required end,
        HasCapability = function(_, name) return state.missing ~= name end,
        IsInitialized = function() return state.ready end,
        Characters = { FormatName = function(_, character, options)
            state.nameOptions = options
            return options.realmMode == "full" and character.name .. "-" .. character.realm or character.name
        end },
        RegisterAddon = function() state.addonRegistrations = state.addonRegistrations + 1; return true end,
        AccountView = {
            RegisterPage = function(_, _, value) state.pages = state.pages + 1; state.page = value; return value end,
            NotifyPageChanged = function() end,
        },
        Entry = { RegisterBusinessEntry = function(_, _, value) state.entries = state.entries + 1; state.entry = value; return value end },
        CharacterCleanup = { RegisterOwner = function(_, _, value) state.ownerRegistrations = state.ownerRegistrations + 1; state.owner = value; return true end },
        Contracts = { Register = function() return {} end, NotifyChanged = function() end }, BusinessItemActions = {},
    }
    dofile("YiboCore/Util/Defaults.lua")
    dofile("YiboCore/Runtime/Locale.lua")
    YiboCore.Locale.language = language or "zh"
    dofile("YiboBuilds/Bootstrap.lua")
    dofile("YiboBuilds/Locales/zhCN.lua")
    dofile("YiboBuilds/Locales/enUS.lua")
    return state
end
return Setup
