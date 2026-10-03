local addonName = ...
local PREFIX = "[YiboVaultIconProbe] "
local ICON_BASE = "Interface\\AddOns\\YiboVaultIconBrokerProbe\\Media\\YiboVaultIcon-pixel-rework-"
local sizes = { 24, 32 }
local registered = false
local hidingBarSnapshot

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
    end
end

local function CopySettings(source)
    local copy = {}
    for name, settings in pairs(source or {}) do
        if type(settings) == "table" then
            local item = {}
            for key, value in pairs(settings) do item[key] = value end
            copy[name] = item
        end
    end
    return copy
end

local function PrepareHidingBar(testNames)
    local bar = _G.HidingBarAddon
    if type(bar) ~= "table" and type(bar) ~= "userdata" then return false end
    if type(bar.pConfig) ~= "table" or type(bar.addFromDataBroker) ~= "function" then return false end
    if hidingBarSnapshot then return true end

    local config = bar.pConfig
    hidingBarSnapshot = {
        addFromDataBroker = config.addFromDataBroker,
        addAnyTypeFromDataBroker = config.addAnyTypeFromDataBroker,
        btnSettings = CopySettings(config.btnSettings),
    }
    config.addFromDataBroker = true
    bar:addFromDataBroker()

    -- Keep the test isolated to the two requested launchers. The previous
    -- HidingBar preferences are restored before WoW saves settings on logout.
    for name, button in pairs(bar.createdButtons or {}) do
        local buttonName = button.name
        if button.data and button.data.type == "launcher" and not testNames[buttonName] then
            config.btnSettings[buttonName][1] = true
            bar:setBtnSettings(button)
            if button.Hide then button:Hide() end
        end
    end
    return true
end

local function RestoreHidingBar()
    local snapshot = hidingBarSnapshot
    local bar = _G.HidingBarAddon
    if not snapshot or not bar or not bar.pConfig then return end

    local config = bar.pConfig
    config.addFromDataBroker = snapshot.addFromDataBroker
    config.addAnyTypeFromDataBroker = snapshot.addAnyTypeFromDataBroker
    local settings = config.btnSettings
    for name in pairs(settings) do settings[name] = nil end
    for name, saved in pairs(snapshot.btnSettings) do
        local item = {}
        for key, value in pairs(saved) do item[key] = value end
        settings[name] = item
    end
    hidingBarSnapshot = nil
end

local function RegisterProbes()
    if registered then return true end
    local stub = _G.LibStub
    local broker = type(stub) == "table" and stub.GetLibrary and stub:GetLibrary("LibDataBroker-1.1", true)
    if not broker then return false end

    local testNames = { YiboVaultIconTest24 = true, YiboVaultIconTest32 = true }
    if not PrepareHidingBar(testNames) then return false end
    for _, size in ipairs(sizes) do
        local label = "YiboVault Test " .. size .. "px"
        broker:NewDataObject("YiboVaultIconTest" .. size, {
            type = "launcher",
            text = label,
            icon = ICON_BASE .. size,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("YiboVault 图标实测")
                tooltip:AddLine(size .. " × " .. size .. " 原生尺寸", 0.8, 0.9, 0.85)
            end,
        })
    end
    registered = true
    Print("已注册 24px 和 32px 两个临时 Broker 图标项。")
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        RestoreHidingBar()
        return
    end
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            if not RegisterProbes() then
                Print("未找到已初始化的 HidingBar/LibDataBroker，24px/32px 探针未接入。")
            end
        end)
    end
end)
