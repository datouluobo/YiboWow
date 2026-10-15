-- Run from the repository root with Lua 5.1.
local function Frame()
    return setmetatable({}, { __index = function(_, key)
        if key == "GetHeight" then return function() return 300 end end
        if key == "GetVerticalScroll" then return function() return 0 end end
        if key == "SetText" then return function(self, value) self.text = value end end
        if key == "Hide" then return function(self) self.hidden = true end end
        if key:match("^[A-Z]") then return function() end end
    end })
end

local login, printed, writes, registrations, requestedAPI
local api, capability = 13, true
local formatted = {}
local function FormatName(_, identity, options)
    formatted[#formatted + 1] = { identity = identity, options = options }
    return identity.name
end
local headerCalls = {}
function CreateFrame()
    local frame = Frame()
    frame.SetScript = function(_, event, callback) if event == "OnEvent" then login = callback end end
    return frame
end
GameTooltip = Frame()
local theme = {
    Colors = { text = {1,1,1}, muted = {1,1,1}, warning = {1,1,1}, panel = {0,0,0,1}, row = {0,0,0,1}, alternate = {0,0,0,1} },
    Space = { xs = 4, sm = 8, md = 16 },
    GetMatrixInsets = function() return { top = 8, bottom = 8, left = 8, right = 8 } end,
    Font = { body = 16, assist = 14 }, Table = { rowHeight = 28, cellInset = 4, iconTextRasterTolerance = 1 },
    GetIconTextColumnWidth = function() return 225 end,
    MeasureText = function() return 60 end,
    CreateText = function() return Frame() end,
    CreateMatrixHeader = function() return Frame() end,
    SetCharacterHeader = function(_, header, character, context, options)
        headerCalls[#headerCalls + 1] = { header = header, character = character, context = context, options = options }
    end,
}
YiboCore = {
    UITheme = theme,
    CheckAPIVersion = function(_, required) requestedAPI = required; return api >= required end,
    HasCapability = function(_, name) return name ~= "character-name-format" or capability end,
    Characters = { FormatName = FormatName },
    DataDomains = { Get = function() return { state = "known", data = { professions = { { id = 202 } } } } end },
    ItemResolver = {},
    RegisterAddon = function(_, _, info) registrations = registrations + 1; assert(info.requiredAPI == 13); return true end,
    Print = function(_, message) printed = message end,
    AccountView = {
        GetScrollSurfaceWidth = function(_, context, parent) return context.surfaceAvailableWidth or 600 end,
        FitRepeatedColumnWidth = function() return 80 end,
        GetColumnPage = function(_, _, _, characters) return characters, {} end,
        UpdateColumnPager = function() end,
    },
}
dofile("YiboCrafting/Namespace.lua")
dofile("YiboCrafting/Tests/LoadLocale.lua")
local readyCallbacks = {}
YiboCore.Events.Register = function(_, event, owner, callback) readyCallbacks[event] = function() return callback(owner) end end
YiboCrafting.Store = { Initialize = function() writes = writes + 1; return {} end,
    GetRecipeState = function() return "unknown" end }
YiboCrafting.AccountPage = { Register = function() return true end }
YiboCrafting.Collector = { Scan = function() end }
dofile("YiboCrafting/Bootstrap.lua")
local function Reject()
    writes, registrations, printed = 0, 0, nil
    YiboCrafting.initialized = nil
    login(nil, "PLAYER_LOGIN")
    assert(not YiboCrafting.initialized and writes == 0 and registrations == 0)
    assert(printed and printed:find("API13", 1, true))
    assert(requestedAPI == 13)
end
api = 12; Reject()
api = 13; capability = false; Reject()
capability = true; YiboCore.Characters.FormatName = nil; Reject()
YiboCore.Characters.FormatName = FormatName; theme.SetCharacterHeader = nil; Reject()
local createHeader = theme.CreateMatrixHeader
theme.CreateMatrixHeader = nil; Reject(); theme.CreateMatrixHeader = createHeader
theme.SetCharacterHeader = function(_, header, character, context, options)
    headerCalls[#headerCalls + 1] = { header = header, character = character, context = context, options = options }
end
writes, registrations = 0, 0
local wasReady = YiboCore.IsInitialized
YiboCore.IsInitialized = function() return false end
assert(YiboCrafting:Initialize() == nil and writes == 0, "Core readiness must precede business writes")
YiboCore.IsInitialized = wasReady
local hasCapability = YiboCore.HasCapability
for _, missing in ipairs({"localization","basic-input","item-resolver","character-identity","account-view","characters","data-domains","events","fields",
    "account-entry","account-surface-budget","character-cleanup","business-services","business-providers","business-item-actions"}) do
    YiboCore.HasCapability = function(_, name) return name ~= missing end
    assert(YiboCrafting:Initialize() == nil and writes == 0, "missing capability must stop initialization: " .. missing)
end
YiboCore.HasCapability = hasCapability
readyCallbacks.CORE_READY()
assert(YiboCrafting.initialized and writes == 1 and registrations == 1, "late Core readiness initializes once")
assert(YiboCrafting:Initialize() and writes == 1 and registrations == 1)
assert(YiboCrafting:Initialize() and writes == 1 and registrations == 1)

dofile("YiboCrafting/AccountPage.lua")
local page = YiboCrafting.AccountPage
local row = Frame()
row.icon, row.name, row.meta, row.cells = Frame(), Frame(), Frame(), {}
local panel = Frame()
panel.header = Frame(); panel.header.title = Frame(); panel.header.cells = {}
panel.scroll, panel.body, panel.rows, panel.empty = Frame(), Frame(), {row, row}, Frame()
local parent = { crafting = { matrix = panel, matrixWidth = 600, state = {}, footer = Frame() } }
local character = { id = "Player-1", name = "原名", realm = "服务器", class = "MAGE" }
local context = { scope = "all", characters = { character } }
local entries = { { key = "202:1", id = 1, professionID = 202, name = "配方" } }
page:RenderMatrix(parent, context, entries, {})
assert(#headerCalls == 1 and headerCalls[1].character == character and headerCalls[1].context == context)
assert(headerCalls[1].options.nameMode == "short")
local header = headerCalls[1].header
page:RenderMatrix(parent, { scope = "realm:服务器", characters = { character } }, entries, {})
assert(#headerCalls == 2 and headerCalls[2].header == header)
page:RenderMatrix(parent, { characters = {} }, entries, {})
assert(header.hidden)
local detail = Frame()
for _, key in ipairs({"title", "icon", "iconHit", "name", "meta", "note", "characters", "body", "empty"}) do
    detail[key] = Frame()
end
detail.scroll, detail.rows = detail.characters, {row}
parent.crafting.detail, parent.crafting.detailWidth = detail, 360
page:RenderDetail(parent, context, entries[1], {})
assert(formatted[#formatted].identity.id == character.id)
assert(formatted[#formatted].options.nameMode == "original" and formatted[#formatted].options.realmMode == "full")
page:RenderDetail(parent, { scope = "realm:服务器", characters = { character } }, entries[1], {})
assert(formatted[#formatted].options.realmMode == "omit")
print("CoreNameIntegration OK: API/capability/method rejection and visible upgrade hint, initialization idempotence, shared header reuse and filtering")
