local owner = ...
local Core = _G.YiboCore
if not Core or not Core:CheckAPIVersion(13) or not Core:HasCapability("localization", 1) then
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("YiboIconBrokerProbe requires YiboCore API 13 / localization:1. Upgrade YiboCore.") end
    return
end
Core.Locale:Register(owner, "en", {
    TITLE = "Temporary Broker icons", READY = "Temporary Broker icons applied: %d. /yig show | off | on | 32 | 64 | status",
    OFF = "Original Broker icons restored.", STATUS = "Active: %s; texture: %dpx; Brokers: %d.",
})
Core.Locale:Register(owner, "zh", {
    TITLE = "临时 Broker 图标", READY = "已替换 %d 个临时 Broker 图标。/yig show | off | on | 32 | 64 | status",
    OFF = "已恢复原 Broker 图标。", STATUS = "启用：%s；纹理：%dpx；Broker：%d。",
})
local function T(key, ...) return Core.Locale:Get(owner, key, ...) end
local function Print(key, ...) Core:Print(T(key, ...)) end
local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end
local names = {"YiboCore","YiboMail","YiboVault","YiboBuilds","YiboAutoOpen","YiboCurrency","YiboCrafting","YiboTodo","YiboReputation","YiboAltoBoss","YiboLegendary","YiboMounts","YiboBeastPaths","YiboQuestBlocker","YiboTaskHub"}
local allowed, originals, active, size = {}, {}, false, 64
for _, name in ipairs(names) do allowed[name] = true end
local function Texture(id, resolution)
    return "Interface\\AddOns\\" .. id .. "\\Media\\" .. id .. "Icon-" .. (resolution or size)
end
local function Apply(name, object)
    local id = object.yiboCoreEntryID or name
    if not active or not allowed[id] then return end
    if not originals[object] then originals[object] = { icon = object.icon, id = id } end
    object.icon = Texture(id)
end
local function ApplyAll()
    for name, object in ldb:DataObjectIterator() do Apply(name, object) end
end
local function Count()
    local count = 0
    for _ in pairs(originals) do count = count + 1 end
    return count
end
local callbacks = {}
function callbacks:Created(_, name, object) Apply(name, object) end
function callbacks:Changed(_, name, key, value, object)
    if not active then return end
    local old = originals[object]
    if key == "icon" and old and value ~= Texture(old.id) then
        old.icon = value
        C_Timer.After(0, function() Apply(name, object) end)
    elseif key == "yiboCoreEntryID" then
        Apply(name, object)
    end
end
ldb.RegisterCallback(callbacks, "LibDataBroker_DataObjectCreated", "Created")
ldb.RegisterCallback(callbacks, "LibDataBroker_AttributeChanged", "Changed")
local frame
local function Show()
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(710, 250)
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 180, -80)
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0.12, 0.88, 0.65, 1)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10); title:SetText(T("TITLE") .. " · 24 / 32")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        for i, name in ipairs(names) do
            local x, y = 12 + ((i-1)%5)*140, -38 - math.floor((i-1)/5)*68
            for j, resolution in ipairs({24,32}) do
                local texture = frame:CreateTexture(nil, "ARTWORK")
                texture:SetSize(resolution, resolution)
                texture:SetPoint("TOPLEFT", x+(j-1)*38, y)
                texture:SetTexture(Texture(name, resolution == 24 and 64 or 32))
            end
            local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", x, y-36); label:SetText(name)
        end
    end
    frame:Show()
end
SLASH_YIBOICONBROKERPROBE1 = "/yig"
SlashCmdList.YIBOICONBROKERPROBE = function(message)
    local command = tostring(message or ""):match("^%s*(%S+)") or ""
    if command == "off" then
        active = false
        for object, original in pairs(originals) do object.icon = original.icon end
        if frame then frame:Hide() end
        Print("OFF")
    elseif command == "status" then Print("STATUS", tostring(active), size, Count())
    elseif command == "32" or command == "64" then size = tonumber(command); active = true; ApplyAll(); Print("READY", Count())
    elseif command == "on" then active = true; ApplyAll(); Print("READY", Count())
    else Show() end
end
local event = CreateFrame("Frame")
event:RegisterEvent("PLAYER_ENTERING_WORLD")
event:SetScript("OnEvent", function() ApplyAll() end)
ApplyAll()
C_Timer.After(1, function() if active then ApplyAll(); Print("READY", Count()) end end)
