dofile("_NonRelease/CurrencyMigration/Spec.lua")
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Read(path) local f = assert(io.open(path, "r")); local text = f:read("*a"); f:close(); return text end
local coreTOC = Read("YiboCore/YiboCore.toc")
for _, path in ipairs({ "Runtime\\CurrencyCatalog.lua", "Data\\Domains\\Economy.lua", "Data\\Domains\\EconomyItems.lua", "Data\\Resources\\Economy.lua" }) do
    Check(not coreTOC:find(path, 1, true), "retired business module is not in Core TOC: " .. path)
    dofile("YiboCore/" .. path:gsub("\\", "/"))
end
Check(YiboCore.CurrencyCatalog == nil, "retired source files cannot recreate a Core currency registry")
for _, definition in ipairs(YiboCore.DataDomains:GetDefinitions()) do Check(definition.id ~= "economy" and definition.id ~= "economy-items", "Core cannot collect currency domains") end
Check(YiboCore.Fields._definitions["character.money"] == nil, "Core has no static money business field")
local coreVersion = coreTOC:match("## Version:%s*([^\r\n]+)")
Check(coreVersion and Read("YiboCore/Bootstrap.lua"):match('Core.VERSION = "([^"]+)"') == coreVersion, "Core versions match")
local currencyTOC = Read("YiboCurrency/YiboCurrency.toc")
for _, name in ipairs({ "Store.lua", "Migration.lua", "Scanner.lua", "ArchiveProvider.lua" }) do Check(currencyTOC:find(name, 1, true), "Currency loads new owned module: " .. name) end
local currencyVersion = currencyTOC:match("## Version:%s*([^\r\n]+)")
Check(currencyVersion and Read("YiboCurrency/Bootstrap.lua"):match('Addon.NAME, Addon.VERSION = "YiboCurrency", "([^"]+)"') == currencyVersion, "Currency versions match")
Check(not Read("YiboCore/Bootstrap.lua"):find('RegisterEvent("PLAYER_MONEY")', 1, true), "Core has no dedicated money collector listener")
local native = YiboCore.Defaults:Copy(YiboCore.Database:GetDB().characters.byID.Bad.domains)
dofile("YiboCore/Data/Profile.lua")
YiboCore.Profile:RefreshCurrent("PLAYER_MONEY")
Check(YiboCurrency.Store.Equal(native, YiboCore.Database:GetDB().characters.byID.Bad.domains), "Core profile dispatch leaves frozen legacy economy untouched")
print("Currency TocSpec: " .. checks .. " additional checks passed")
