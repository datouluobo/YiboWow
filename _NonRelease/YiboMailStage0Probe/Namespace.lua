local Addon = _G.YiboMailStage0Probe or {}
_G.YiboMailStage0Probe = Addon

Addon.NAME = "YiboMailStage0Probe"
Addon.VERSION = "0.1.1"
Addon.SCHEMA_VERSION = 1
Addon.MAX_SAMPLES = 400
Addon.MAX_EVENTS = 800
Addon.Runtime = Addon.Runtime or { mailOpen = false }
Addon.EVENT_NAMES = {
    "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE",
    "MAIL_SUCCESS", "MAIL_FAILED", "UI_ERROR_MESSAGE",
}

function Addon:Now()
    if type(GetServerTime) == "function" then
        local value = GetServerTime()
        if type(value) == "number" and value > 0 then return value, "server" end
    end
    if type(time) == "function" then return time(), "client" end
    return os.time(), "client"
end

function Addon:Print(message)
    local output = "|cff20e070[Yibo Mail Probe]|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(output)
    elseif type(print) == "function" then
        print(output)
    end
end

function Addon:IsFrameShown(frameName)
    local frame = _G[frameName]
    return frame and type(frame.IsShown) == "function" and frame:IsShown() == true
end

function Addon:SafeCall(label, callable, ...)
    if type(callable) ~= "function" then return false, { label = label, error = "missing-api" } end
    local function Pack(...) return { n = select("#", ...), ... } end
    local packed = Pack(pcall(callable, ...))
    if not packed[1] then return false, { label = label, error = tostring(packed[2]) } end
    local results = { n = packed.n - 1 }
    for index = 2, packed.n do results[index - 1] = packed[index] end
    return true, results
end
