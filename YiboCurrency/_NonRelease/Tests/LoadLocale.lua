-- Load actual owner resources for fixtures that construct an addon namespace.
dofile("YiboCore/_NonRelease/Tests/LoadLocale.lua")
dofile("YiboCurrency/Locales/zhCN.lua")
dofile("YiboCurrency/Locales/enUS.lua")
function YiboCurrency:T(key, ...) return YiboCore.Locale:Get("YiboCurrency", key, ...) end
function YiboCurrency:UpgradeMessage() return self:T("UI.CORE_UPGRADE") end
