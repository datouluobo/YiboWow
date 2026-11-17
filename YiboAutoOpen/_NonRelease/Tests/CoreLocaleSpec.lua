local count = 0
local base = (arg and arg[1]) or "YiboAutoOpen/"
local target = (arg and arg[2]) or "Forever"
local function check(v, message) count = count + 1; assert(v, message) end
local function frame()
    return setmetatable({ scripts = {}, text = "", shown = true }, { __index = function(t, k)
        local methods = {
            SetScript = function(s, name, fn) s.scripts[name] = fn end,
            HookScript = function() end,
            GetText = function(s) return s.text end,
            SetText = function(s, value) s.text = tostring(value) end,
            GetWidth = function() return 1100 end, GetHeight = function() return 30 end,
            IsShown = function(s) return s.shown end,
            Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
            SetShown = function(s, v) s.shown = v end,
            IsInIMECompositionMode = function(s) return s.composing end,
        }
        return methods[k] or (k:match("^%u") and function() end or nil)
    end })
end
CreateFrame = function() return frame() end
StaticPopupDialogs, SlashCmdList = {}, {}
STANDARD_TEXT_FONT = "font"
GetLocale = function() return "zhCN" end
GetItemInfo = function(id) return "Native" .. tostring(id), "item:" .. tostring(id) end
IsLoggedIn = function() return false end
local caps, catalogs, language, panels = {}, {}, "en", 0
YiboCore = {
    Client = { ReadItemInfo = function(_, id) return {name = id == 42 and "Test" or "Other", link = "item:" .. id} end,
        ReadBagItemIDs = function() return {42,43} end, BindItemEvents = function() end },
    Capabilities = {Register = function(_, name, version) caps[name] = version end},
    HasCapability = function(_, name, version) return (caps[name] or 0) >= version end,
    IsInitialized = function() return true end, CheckAPIVersion = function(_, v) return v <= 13 end,
    Locale = {Register = function(_, _, lang, values) catalogs[lang] = values end,
        Get = function(_, _, key, ...) local v = assert(catalogs[language][key], key); return select('#', ...) > 0 and string.format(v, ...) or v end},
    Text = function(_, key) return key end,
    RegisterAddon = function() return true end,
    RegisterSettingsPanel = function() panels = panels + 1; return true end,
    UITheme = { Font = {meta=12,body=14,assist=12}, Colors = {muted={},text={},bg={},lineSoft={},accent={}},
        Size = {standard=28,compact=26}, Space = {xs=4},
        CreateText = function() return frame() end,
        CreateButton = function() return frame() end,
        CreateDropdown = function() return frame() end },
}
caps.localization = 1
dofile('YiboCore/UI/Input.lua')
dofile('YiboCore/Runtime/ItemResolver.lua')
WOW_PROJECT_CAMELOT, WOW_PROJECT_MISTS_CLASSIC = 99, 98
WOW_PROJECT_ID = target == "Mists" and 98 or 99
YiboAutoOpen, YiboAutoOpenForeverDB = nil, nil
for line in io.lines(base .. (base == "YiboAutoOpen/" and ("YiboAutoOpen_" .. target .. ".toc") or "YiboAutoOpen.toc")) do
    line = line:gsub('\r',''):gsub('\\','/')
    if line:match('%.lua$') then dofile(base .. line) end
end
local a = YiboAutoOpen
check(a:Initialize()); check(a.CoreIntegration:Initialize()); check(a.CoreIntegration:Initialize()); check(panels == 1)
if target == "Mists" then for _, id in ipairs(a.Database:GetOrderedItems()) do a.Database:RemoveItem(id) end end
check(#a.db.catalog.order == 0)
for key, value in pairs(catalogs.zh) do
    check(catalogs.en[key] ~= nil, key)
    local function formats(v) return (v:gsub('%%%%',''):gsub('[^%%]*%%([%d%.%-]*[a-zA-Z])', '%1|')) end
    local zh, en = {}, {}
    for spec in value:gmatch('%%[%d%.%-]*[a-zA-Z]') do zh[#zh+1] = spec end
    for spec in catalogs.en[key]:gmatch('%%[%d%.%-]*[a-zA-Z]') do en[#en+1] = spec end
    check(table.concat(zh) == table.concat(en), key)
end
for _, lang in ipairs({'en','zh'}) do
    language = lang
    check(a:T('ACTION.ADD') == catalogs[lang]['ACTION.ADD'])
    check(a:StatusText('PAUSED','IN_COMBAT'):find(catalogs[lang]['REASON.IN_COMBAT'],1,true))
    local parent = frame()
    local host = {createCheckbox = function() return frame() end, refreshPage = function() end}
    check(a.Settings:CreatePanel(parent, host) > 0)
    check(a.Database:AddItem(42)); check(a.Settings:CreatePanel(parent, host) > 0)
    local panel = parent.autoOpenSettingsPanel
    panel.add:SetText('43'); panel.addButton.scripts.OnClick(); check(a.db.catalog.entries[43])
    local id = a.ItemResolver:Resolve('42'); check(id == 42)
    id = a.ItemResolver:Resolve('Test'); check(id == 42)
    check(not a.ItemResolver:Resolve('2147483648'))
    panel.space:SetText('9'); panel.space.composing = true
    panel.space.scripts.OnEnterPressed(panel.space); check(a.db.minFreeSlots ~= 9)
    panel.space.composing = false; panel.space.scripts.OnEnterPressed(panel.space); check(a.db.minFreeSlots == 9)
    a.db.minFreeSlots = 5
    a.Database:AddConfirmObject(123, 'Player alias')
    check(a.Settings:CreatePanel(parent, host) > 0)
    check(a.Database:GetConfirmSources()[2].label == 'Player alias')
    a.Database:RemoveItem(42); a.Database:RemoveItem(43)
end
for _, cap in ipairs({'localization','basic-input','item-resolver'}) do
    local saved = caps[cap]; caps[cap] = nil; a.runtime.initialized = false
    local savedDB = YiboAutoOpenForeverDB
    if target == "Forever" then check(not a:Initialize()); check(YiboAutoOpenForeverDB == savedDB) end
    caps[cap] = saved
end
check(a:Initialize()); check(#a.db.catalog.order == 0)
print('Core / locale / settings integration passed: ' .. count .. ' assertions')
