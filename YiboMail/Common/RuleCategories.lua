local Addon = _G.YiboMail
local Rules = Addon.SendRules
local classLabels = {
    [0] = Addon:T("UI.TEXT_0439"), [1] = Addon:T("UI.TEXT_0230"), [2] = Addon:T("UI.TEXT_0432"), [3] = Addon:T("UI.TEXT_0219"), [4] = Addon:T("UI.TEXT_0317"),
    [5] = Addon:T("UI.TEXT_0362"), [6] = Addon:T("UI.TEXT_0261"), [7] = Addon:T("UI.TEXT_0105"), [8] = Addon:T("UI.TEXT_0459"),
    [9] = Addon:T("UI.TEXT_0611"), [10] = Addon:T("UI.TEXT_0569"), [11] = Addon:T("UI.TEXT_0481"), [12] = Addon:T("UI.TEXT_0116"),
    [13] = Addon:T("UI.TEXT_0622"), [14] = Addon:T("UI.TEXT_0433"), [15] = Addon:T("UI.TEXT_0143"), [16] = Addon:T("UI.TEXT_0637"),
    [17] = Addon:T("UI.TEXT_0310"), [18] = Addon:T("UI.TEXT_0643"), [19] = Addon:T("UI.TEXT_0092"), [20] = Addon:T("UI.TEXT_0117"),
}
local function ClassLabel(id, name)
    if id == 5 or id == 7 then return classLabels[id] end
    if name and name:find("[A-Za-z]") then
        local upper = name:upper()
        if id == 8 and upper:find("GENERIC", 1, true) then return Addon:T("UI.TEXT_0584") end
        if id == 10 and upper:find("MONEY", 1, true) then return Addon:T("UI.TEXT_0621") end
        return classLabels[id] or name
    end
    return name or classLabels[id] or (Addon:T("UI.TEXT_0148") .. tostring(id))
end
local hiddenClasses = { [6] = true, [10] = true, [11] = true, [14] = true, [18] = true }
local function IsObsolete(name)
    return name and (name:lower():find("obsolete", 1, true) or name:find("作废", 1, true) or name:find("废弃", 1, true))
end

function Rules:ClassLabel(id, name) return ClassLabel(id, name) end
function Rules:Categories(classID)
    -- Prefer the current API, but retry the legacy entry point when a client
    -- exposes both and one returns no usable name (or throws).
    local function Name(modern, legacy, ...)
        for index = 1, 2 do
            local get
            if index == 1 then get = modern else get = legacy end
            if type(get) == "function" then
                local ok, name = pcall(get, ...)
                if ok and type(name) == "string" and name ~= "" then return name end
            end
        end
    end
    local result = {}
    if classID == nil then
        for id = 0, 20 do
            local name = Name(C_Item and C_Item.GetItemClassInfo, GetItemClassInfo, id)
            if name and not hiddenClasses[id] and not IsObsolete(name) then
                -- The localized Reagent label can read simply “材料”, which
                -- is easily mistaken for Tradegoods. Keep their IDs distinct.
                local label = ClassLabel(id, name)
                result[#result + 1] = { value = id, label = label }
            end
        end
    else
        result[1] = { value = -1, label = Addon:T("UI.TEXT_0134") }
        for id = 0, 30 do
            local name = Name(C_Item and C_Item.GetItemSubClassInfo, GetItemSubClassInfo, classID, id)
            if name and not IsObsolete(name) then result[#result + 1] = { value = id, label = name } end
        end
    end
    return result
end
