local ADDON_NAME, NS = ...
local initialized = false

local function Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. NS:T("prefix") .. tostring(text)) end
end

local function IsSupportedClient()
    return (type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)
        or (type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return nil, false end
    local result = { pcall(callback, ...) }
    local ok = table.remove(result, 1)
    if not ok then return tostring(result[1]), false end
    return result, true
end

local function Capture()
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    local version, build, buildDate, interface = GetBuildInfo()
    local money, moneyOK = SafeCall(GetMoney)
    local rows, listOK, failures = {}, false, 0
    local listSizeAPI = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) or GetCurrencyListSize
    local listInfoAPI = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo) or GetCurrencyListInfo
    local listLinkAPI = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink) or GetCurrencyListLink
    local detailAPI = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) or GetCurrencyInfo
    local size, sizeOK = SafeCall(listSizeAPI)
    if sizeOK and type(size[1]) == "number" and type(listInfoAPI) == "function" then
        listOK = size[1] <= 500
        for index = 1, math.min(size[1], 500) do
            local info, ok = SafeCall(listInfoAPI, index)
            if ok then
                local value = info[1]
                local link, linkOK = SafeCall(listLinkAPI, index)
                local hyperlink = linkOK and type(link[1]) == "string" and link[1] or nil
                local currencyID = type(value) == "table" and tonumber(value.currencyID) or nil
                currencyID = currencyID or (hyperlink and tonumber(hyperlink:match("currency:(%d+)")))
                local row
                if type(value) == "table" then
                    row = {
                        name = value.name, quantity = value.quantity, iconFileID = value.iconFileID,
                        isHeader = value.isHeader, isExpanded = value.isHeaderExpanded,
                        isShowInBackpack = value.isShowInBackpack,
                    }
                else
                    row = { name = value, isHeader = info[2], isExpanded = info[3],
                        isShowInBackpack = info[5], quantity = info[6], icon = info[7] }
                end
                row.index, row.currencyID, row.link = index, currencyID, hyperlink
                if currencyID then
                    local detail, detailOK = SafeCall(detailAPI, currencyID)
                    row.detailOK = detailOK
                    if detailOK then row.detail = detail end
                end
                rows[#rows + 1] = row
            else
                failures = failures + 1
                rows[#rows + 1] = { index = index, error = tostring(info) }
            end
        end
        listOK = listOK and failures == 0
    end
    local snapshot = {
        version = version, build = build, buildDate = buildDate, interface = tonumber(interface),
        projectID = WOW_PROJECT_ID, locale = GetLocale and GetLocale() or "unknown", moneyAPI = type(GetMoney) == "function",
        moneyCopper = moneyOK and money[1] or nil,
        currencyInfoAPI = type(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) == "function",
        currencyListAPI = type(listSizeAPI) == "function" and type(listInfoAPI) == "function",
        currencyListSize = sizeOK and size[1] or nil, currencyRows = rows, rowsComplete = listOK,
        currencyListFailures = failures, currencyLinkAPI = type(listLinkAPI) == "function",
        itemCountAPI = type(C_Item and C_Item.GetItemCount) == "function" or type(GetItemCount) == "function",
    }
    YiboCurrencyProbeDB = YiboCurrencyProbeDB or {}
    YiboCurrencyProbeDB.lastCapture = snapshot
    Print(NS:T("saved"))
    return snapshot
end

local function ReportStatus()
    local snapshot = YiboCurrencyProbeDB and YiboCurrencyProbeDB.lastCapture
    if not snapshot then Print(NS:T("empty")); return end
    Print(string.format(NS:T("report"), tostring(snapshot.interface), tostring(snapshot.moneyAPI),
        tostring(snapshot.moneyCopper), tostring(snapshot.currencyInfoAPI), tostring(snapshot.currencyListAPI),
        #(snapshot.currencyRows or {})))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    if initialized then return end
    initialized = true
    SLASH_YIBOCURRENCYPROBE1 = "/ycp"
    SlashCmdList.YIBOCURRENCYPROBE = function(message)
        local command = tostring(message or ""):match("^%s*(%S+)") or ""
        if command == "capture" then Capture()
        elseif command == "status" then ReportStatus()
        else Print(NS:T("help")) end
    end
end)
