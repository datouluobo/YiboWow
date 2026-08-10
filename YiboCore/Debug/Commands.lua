local Core = _G.YiboCore

local function PrintStatus()
    Core:Print("版本 " .. Core:GetVersion() .. "，API " .. Core.API_VERSION)
    Core:Print("已初始化: " .. tostring(Core:IsInitialized()))

    local capabilities = { "runtime", "events", "migrations", "database", "characters", "character-profile", "account-view", "account-entry", "level-filter" }
    Core:Print("能力: " .. table.concat(capabilities, ", "))
    if Core.AccountView then
        local pages = Core.AccountView:GetRegisteredPages()
        local visibleCharacters = Core.AccountView:GetVisibleCharacters()
        Core:Print("账号视图: 页面 " .. #pages .. "，视图角色 " .. #visibleCharacters .. "，当前页 " .. tostring(Core.AccountView.activePageID or "无"))
    end
    if Core.Entry then
        Core:Print("入口: 小地图 " .. tostring(Core.Entry.button and Core.Entry.button:IsShown() or false) .. "，Broker " .. tostring(Core.Entry.broker ~= nil))
    end
end

local function PrintCharacters()
    local characters = Core.Characters:GetAll()
    Core:Print("已记录角色: " .. #characters)
    for _, character in ipairs(characters) do
        Core:Print(string.format("%s-%s（%s，等级 %s）", character.name, character.realm, character.class, character.level))
    end
end

local function PrintAddons()
    local addons = Core:GetRegisteredAddons()
    Core:Print("已注册插件: " .. #addons)
    for _, addon in ipairs(addons) do
        Core:Print(addon.name .. " " .. addon.version .. "（API " .. addon.requiredAPI .. "）")
    end
end

SLASH_YIBOCORE1 = "/yco"
SlashCmdList.YIBOCORE = function(message)
    message = string.lower(strtrim(message or ""))
    if message == "" and Core.AccountView then
        Core.AccountView:Toggle()
    elseif message == "status" then
        PrintStatus()
    elseif message == "characters" or message == "chars" then
        PrintCharacters()
    elseif message == "addons" then
        PrintAddons()
    elseif message == "settings" and Core.AccountView then
        Core.AccountView:ShowSettings()
    else
        Core:Print("命令: /yco [status | characters | addons | settings]")
    end
end
