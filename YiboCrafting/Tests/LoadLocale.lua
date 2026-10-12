-- Test-only dependency fixture for isolated Crafting modules.
local Core = assert(YiboCore)
Core.Capabilities = Core.Capabilities or { Register = function() end }
GetLocale = GetLocale or function() return "zhCN" end
if not Core.Locale then dofile("YiboCore/Runtime/Locale.lua") end
dofile("YiboCrafting/Locales/Interface.lua")
dofile("YiboCrafting/Locales/Targets.lua")
dofile("YiboCrafting/Locales/Categories.lua")
Core.IsInitialized = Core.IsInitialized or function() return true end
Core.Contracts = Core.Contracts or {}
Core.Events = Core.Events or { Register = function() end }
Core.Entry = Core.Entry or {}
Core.BusinessItemActions = Core.BusinessItemActions or {}
Core.BusinessItemActions.Unbind = Core.BusinessItemActions.Unbind or function() end
Core.CharacterCleanup = Core.CharacterCleanup or { RegisterOwner = function() return true end }
Core.Characters = Core.Characters or {}
Core.Characters.GetCurrentID = Core.Characters.GetCurrentID or function() return "Player-1" end
Core.Defaults = Core.Defaults or { Copy = function(_, value)
    local function Copy(v)
        if type(v) ~= "table" then return v end
        local result = {}; for key, item in pairs(v) do result[key] = Copy(item) end; return result
    end
    return Copy(value)
end }
if Core.UITheme then
    local Theme = Core.UITheme
    Theme.CreateInput = Theme.CreateInput or function() return CreateFrame("EditBox") end
    Theme.GetDataRowColor = Theme.GetDataRowColor or function() return Theme.Colors.row or {0,0,0,1} end
    Theme.CreateCurrentCharacterOutline = Theme.CreateCurrentCharacterOutline or function() return CreateFrame("Frame") end
    Theme.UpdateCurrentCharacterColumnOutline = Theme.UpdateCurrentCharacterColumnOutline or function() end
    Theme.ApplyDataColumnTints = Theme.ApplyDataColumnTints or function() end
end
