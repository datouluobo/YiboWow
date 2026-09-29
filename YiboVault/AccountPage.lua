local Addon = _G.YiboVault
local Core = _G.YiboCore
local Page = {}
Addon.AccountPage = Page
local PAGE_ID = "vault-items"
Page.ID = PAGE_ID

local function BuildScope(context)
    local ids = {}
    local characters = {}
    local realm = context and context.scope and context.scope:match("^realm:(.+)$")
    for _, character in ipairs(context and context.characters or {}) do
        if not realm or character.realm == realm then
            ids[#ids + 1] = character.id
            characters[#characters + 1] = character
        end
    end
    return { mode = "characters", characterIDs = ids }, characters
end

function Page:IsStaleForCurrentView(record, currentCharacterID)
    if record.state ~= "stale" then return false end
    if record.source == "guild-bank" then return true end
    return record.characterID ~= nil and record.characterID == currentCharacterID
end

function Page:GetScope()
    for _, definition in ipairs(Core.AccountView:GetRegisteredPages()) do
        if definition.id == PAGE_ID then
            local context = Core.AccountView:BuildContext(definition)
            return BuildScope(context)
        end
    end
    local current = Core.Characters:GetCurrent()
    if current then return { mode = "characters", characterIDs = { current.id } }, { current } end
    return { mode = "characters", characterIDs = {} }, {}
end

function Page:Create(parent)
    local ok, err = pcall(Addon.StoragePage.Create, Addon.StoragePage, parent)
    if not ok then
        local page = parent.yiboVaultStoragePage
        if page then page.createError = tostring(err) end
        error(err)
    end
end

function Page:Refresh(parent, context)
    Addon.StoragePage:Refresh(parent, context)
end

function Page:Register()
    local registered, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = PAGE_ID,
        title = "物品仓库",
        order = 50,
        defaultEnabled = true,
        previewEnabled = false,
        GetSurfaceMetrics = function()
            return { minContentWidth = 650, naturalContentWidth = 1000,
                minContentHeight = 490, naturalContentHeight = 630 }
        end,
        scope = { mode = "realms", allTitle = "所有服务器" },
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not registered then return nil, err end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "yva", brokerName = "YiboVault", pageID = PAGE_ID,
        text = "[Yibo] 物品仓库", icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon-v2",
    })
    if not entry then return nil, entryError end
    Addon.Items.Events:Register(Page, function()
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end)
    return true
end

function Page:Open()
    Core.AccountView:Toggle(PAGE_ID)
end
