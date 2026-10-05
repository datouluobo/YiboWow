local Addon = {}
_G.YiboMail = Addon
Addon.NAME, Addon.VERSION, Addon.API_VERSION = "YiboMail", "0.7-api1", 1
Addon.FEATURES = { send = true, sendAssist = false, account = true, settings = false }
Addon.CAPABILITIES = { ["mail-items.query"] = 1, ["mail-items.state"] = 1, ["mail-items.events"] = 1 }
Addon.Frame = CreateFrame("Frame")
function Addon.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, entry in pairs(value) do result[key] = Addon.Copy(entry) end; return result
end
function Addon:Now()
    if GetServerTime then return GetServerTime(), "server" end
    return time(), "client"
end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r 邮件：" .. tostring(message)) end
end
-- Length prefixes prevent subjects containing delimiters from colliding.
function Addon.Encode(values)
    local result = {}; for _, value in ipairs(values) do value = tostring(value); result[#result + 1] = #value .. ":" .. value end
    return table.concat(result)
end
