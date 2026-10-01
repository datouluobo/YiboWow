local Addon = _G.YiboVault or {}
_G.YiboVault = Addon

Addon.NAME = "YiboVault"
Addon.RELEASE_VERSION = "1.1.0"
Addon.REQUIRED_CORE_API = 6
Addon.SCHEMA_VERSION = 1
Addon.API_VERSION = 1
Addon.VERSION = Addon.RELEASE_VERSION .. "-api" .. Addon.API_VERSION
Addon.CAPABILITIES = {
    ["items.query"] = 1,
    ["items.personal-counts"] = 1,
    ["items.state"] = 1,
    ["items.events"] = 1,
    ["storage.summary"] = 1,
    ["source.bags"] = 1,
    ["source.equipment"] = 1,
    ["source.bank"] = 1,
    ["source.guild-bank"] = 1,
    ["source.auction"] = 1,
    ["source.mail"] = 1,
}
Addon.SourceClasses = { bags = "physical", equipment = "physical", bank = "physical", ["guild-bank"] = "physical", auction = "listed", mail = "external" }
Addon.Frame = CreateFrame("Frame")

function Addon:Now()
    if type(GetServerTime) == "function" then
        local value = GetServerTime()
        if type(value) == "number" and value > 0 then return value, "server" end
    end
    return (type(time) == "function" and time() or 0), "client"
end

function Addon:Print(message)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r 物品总览：" .. tostring(message))
    end
end

local function Hex(value)
    return (tostring(value):gsub(".", function(character)
        return string.format("%02x", string.byte(character))
    end))
end

function Addon:GetGuildIdentity(character)
    if type(character) ~= "table" then return nil end
    local realm = tostring(character.realm or "")
    local guild = type(character.profile) == "table" and tostring(character.profile.guild or "") or ""
    if realm == "" or guild == "" then return nil end
    return "guild:" .. Hex(realm) .. ":" .. Hex(guild), guild, realm
end
