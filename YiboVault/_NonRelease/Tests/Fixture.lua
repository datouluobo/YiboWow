-- Unit specs keep their business doubles but use the current public utilities.
local Fixture = {}

function Fixture.Install(language)
    local addon = assert(_G.YiboVault)
    local core = addon.Core or _G.YiboCore or {}
    _G.YiboCore, addon.Core = core, core
    core.Capabilities = core.Capabilities or { Register = function() end }
    core.Database = core.Database or { GetDB = function() return {} end }
    if not core.Locale then dofile("YiboCore/Runtime/Locale.lua") end
    core.Locale.previewLanguage = language or "zh"
    dofile("YiboVault/Locales/zh.lua")
    dofile("YiboVault/Locales/en.lua")
    if not addon.T then
        local create = _G.CreateFrame
        local provided = {}
        for key, value in pairs(addon) do provided[key] = value end
        _G.CreateFrame = create or function() return {} end
        dofile("YiboVault/Namespace.lua")
        for key, value in pairs(provided) do addon[key] = value end
        _G.CreateFrame = create
    end
    if core.Characters and not core.Characters.FormatName then
        local characters = core.Characters
        dofile("YiboCore/Data/Characters.lua")
        characters.FormatName = core.Characters.FormatName
        core.Characters = characters
    end
    return addon, core
end

return Fixture
