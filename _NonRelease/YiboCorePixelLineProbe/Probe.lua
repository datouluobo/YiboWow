-- Non-release stage-0 probe for YiboCore pixel-line:1.  Standalone: it does
-- not load or depend on YiboCore, so the evidence describes the client only.
local ADDON = ...
local BASE = 768
local WHITE = "Interface\\Buttons\\WHITE8x8"
local probe = { events = { UI_SCALE_CHANGED = 0, DISPLAY_SIZE_CHANGED = 0, UIPARENT_SIZE = 0 }, eventLog = {} }

local function Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[YPX]|r " .. tostring(text)) end
local function Has(value) return value ~= nil and "yes" or "no" end

local function Physical()
    if type(GetPhysicalScreenSize) ~= "function" then return nil, nil end
    local ok, width, height = pcall(GetPhysicalScreenSize)
    if not ok then return nil, nil end
    return width, height
end

local function PixelSize(region, pixels)
    local _, height = Physical()
    local scale = region:GetEffectiveScale()
    if type(height) ~= "number" or height <= 0 or not scale or scale <= 0 then return pixels or 1 end
    return (pixels or 1) * BASE / height / scale
end

local function Report()
    local width, height = Physical()
    local version, build, _, interface = GetBuildInfo()
    local scale = UIParent:GetEffectiveScale()
    local texture = UIParent:CreateTexture()
    local record = {
        at = time(), client = tostring(version) .. " (" .. tostring(build) .. ")", interface = interface,
        projectID = WOW_PROJECT_ID, locale = GetLocale(),
        physicalAPI = type(GetPhysicalScreenSize) == "function", physicalWidth = width, physicalHeight = height,
        screenWidth = GetScreenWidth(), screenHeight = GetScreenHeight(), uiParentScale = scale,
        useUIScale = GetCVar and GetCVar("useUiScale"), uiScaleCVar = GetCVar and GetCVar("uiScale"),
        pixelUtil = PixelUtil ~= nil, pixelUtilGetPixelToUIUnitFactor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or nil,
        snapToPixelGrid = texture.SetSnapToPixelGrid ~= nil, texelSnappingBias = texture.SetTexelSnappingBias ~= nil,
        pixelsPerUnit = height and height / BASE * scale or nil, onePixelUnits = PixelSize(UIParent, 1),
        events = { UI_SCALE_CHANGED = probe.events.UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED = probe.events.DISPLAY_SIZE_CHANGED },
    }
    texture:Hide()
    YiboCorePixelLineProbeDB.reports = YiboCorePixelLineProbeDB.reports or {}
    table.insert(YiboCorePixelLineProbeDB.reports, record)
    Print(("client %s, Interface %s, project %s"):format(record.client, tostring(interface), tostring(WOW_PROJECT_ID)))
    Print(("GetPhysicalScreenSize %s: %s x %s; GetScreen %.1f x %.1f"):format(Has(GetPhysicalScreenSize), tostring(width), tostring(height), record.screenWidth, record.screenHeight))
    Print(("UIParent scale %.4f (useUiScale=%s, uiScale=%s)"):format(scale, tostring(record.useUIScale), tostring(record.uiScaleCVar)))
    Print(("pixels/unit %s, 1px = %.4f UI units"):format(record.pixelsPerUnit and ("%.4f"):format(record.pixelsPerUnit) or "unknown", record.onePixelUnits))
    Print(("PixelUtil %s (factor %s); SetSnapToPixelGrid %s; SetTexelSnappingBias %s"):format(Has(PixelUtil), tostring(record.pixelUtilGetPixelToUIUnitFactor), Has(texture.SetSnapToPixelGrid), Has(texture.SetTexelSnappingBias)))
    Print(("events since load: UI_SCALE_CHANGED=%d DISPLAY_SIZE_CHANGED=%d UIParent:OnSizeChanged=%d SetScale=%d; report #%d saved"):format(record.events.UI_SCALE_CHANGED, record.events.DISPLAY_SIZE_CHANGED, probe.events.UIPARENT_SIZE, probe.events.SETSCALE or 0, #YiboCorePixelLineProbeDB.reports))
end

-- Comparison board: each row shows the former 1-UI-unit line beside a
-- computed 1-physical-pixel line, at whole and fractional offsets.
local board
local function Rule(parent, label, y, thickness, offset, snapOff)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 12, y + 4); text:SetText(label)
    local lines = {}
    for index = 1, 6 do
        local line = parent:CreateTexture(nil, "ARTWORK")
        if snapOff and line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(false) end
        if snapOff and line.SetTexelSnappingBias then line:SetTexelSnappingBias(0) end
        line:SetColorTexture(0.10, 0.36, 0.37, 1)
        lines[index] = line
    end
    return { lines = lines, y = y, thickness = thickness, offset = offset }
end

local function LayoutBoard()
    if not board then return end
    for _, row in ipairs(board.rows) do
        for index, line in ipairs(row.lines) do
            local size = row.thickness == "unit" and 1 or PixelSize(board, 1)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", board, "TOPLEFT", 250, row.y - (index - 1) * 5 - row.offset)
            line:SetSize(220, size)
        end
    end
    -- Adjacent 4-edge backdrops: the shared edge doubles; side borders do not.
    for index, cell in ipairs(board.backdropCells) do
        cell:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = cell.pixel and PixelSize(board, 1) or 1 })
        cell:SetBackdropColor(0.025, 0.09, 0.105, 1); cell:SetBackdropBorderColor(0.10, 0.36, 0.37, 1)
    end
    for _, edge in ipairs(board.sideEdges) do
        if edge.vertical then edge:SetWidth(PixelSize(board, 1)) else edge:SetHeight(PixelSize(board, 1)) end
    end
    board.status:SetText(("1px = %.4f UI units | scale %.4f | events scale=%d display=%d uiparent=%d setscale=%d"):format(PixelSize(board, 1), board:GetEffectiveScale(), probe.events.UI_SCALE_CHANGED, probe.events.DISPLAY_SIZE_CHANGED, probe.events.UIPARENT_SIZE, probe.events.SETSCALE or 0))
end

local function ShowBoard()
    if board then board:SetShown(not board:IsShown()); LayoutBoard(); return end
    board = CreateFrame("Frame", "YiboCorePixelLineProbeBoard", UIParent, "BackdropTemplate")
    board:SetSize(520, 420); board:SetPoint("CENTER"); board:SetFrameStrata("DIALOG")
    board:SetBackdrop({ bgFile = WHITE }); board:SetBackdropColor(0.018, 0.045, 0.060, 1)
    board:EnableMouse(true); board:SetMovable(true); board:RegisterForDrag("LeftButton")
    board:SetScript("OnDragStart", board.StartMoving); board:SetScript("OnDragStop", board.StopMovingOrSizing)
    local title = board:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10); title:SetText("YPX pixel-line board (drag to move, /ypx show to hide)")
    board.status = board:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    board.status:SetPoint("BOTTOMLEFT", 12, 10)
    board.rows = {
        Rule(board, "A  1 UI unit, whole offset", -40, "unit", 0),
        Rule(board, "B  1 UI unit, +0.5 offset", -80, "unit", 0.5),
        Rule(board, "C  1 px, whole offset", -120, "pixel", 0),
        Rule(board, "D  1 px, +0.5 offset", -160, "pixel", 0.5),
        Rule(board, "E  1 px, +0.5, snap off", -200, "pixel", 0.5, true),
    }
    local label = board:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 12, -250); label:SetText("F  stacked 4-edge rows: 1 unit | 1 px        G  side border, 1 px")
    board.backdropCells, board.sideEdges = {}, {}
    for column, pixel in ipairs({ false, true }) do
        for index = 1, 3 do
            local cell = CreateFrame("Frame", nil, board, "BackdropTemplate")
            cell:SetSize(100, 24); cell:SetPoint("TOPLEFT", 12 + (column - 1) * 110, -270 - (index - 1) * 24)
            cell.pixel = pixel
            board.backdropCells[#board.backdropCells + 1] = cell
        end
    end
    for index = 1, 3 do
        local cell = CreateFrame("Frame", nil, board)
        cell:SetSize(100, 24); cell:SetPoint("TOPLEFT", 250, -270 - (index - 1) * 24)
        local fill = cell:CreateTexture(nil, "BACKGROUND"); fill:SetAllPoints(); fill:SetColorTexture(0.025, 0.09, 0.105, 1)
        local sides = { bottom = true, left = true, right = true, top = index == 1 }
        for side in pairs(sides) do
            if sides[side] then
                local edge = cell:CreateTexture(nil, "ARTWORK"); edge:SetColorTexture(0.10, 0.36, 0.37, 1)
                if side == "top" then edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT")
                elseif side == "bottom" then edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT")
                elseif side == "left" then edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge.vertical = true
                else edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge.vertical = true end
                board.sideEdges[#board.sideEdges + 1] = edge
            end
        end
    end
    LayoutBoard()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then YiboCorePixelLineProbeDB = YiboCorePixelLineProbeDB or {} end
        return
    end
    probe.events[event] = probe.events[event] + 1
    local width, height = Physical()
    table.insert(probe.eventLog, { event = event, at = GetTime(), width = width, height = height, scale = UIParent:GetEffectiveScale() })
    if YiboCorePixelLineProbeDB then YiboCorePixelLineProbeDB.lastEvents = probe.eventLog end
    LayoutBoard()
end)

-- UIParent:SetScale (e.g. by NDui) fires no scale event; follow its size.
UIParent:HookScript("OnSizeChanged", function()
    probe.events.UIPARENT_SIZE = probe.events.UIPARENT_SIZE + 1
    table.insert(probe.eventLog, { event = "UIParent:OnSizeChanged", at = GetTime(), scale = UIParent:GetEffectiveScale() })
    LayoutBoard()
end)

probe.events.SETSCALE = 0
hooksecurefunc(UIParent, "SetScale", function(_, value)
    probe.events.SETSCALE = probe.events.SETSCALE + 1
    table.insert(probe.eventLog, { event = "UIParent:SetScale " .. tostring(value), at = GetTime(), scale = UIParent:GetEffectiveScale() })
    LayoutBoard()
end)

SLASH_YIBOCOREPIXELLINEPROBE1 = "/ypx"
SlashCmdList.YIBOCOREPIXELLINEPROBE = function(message)
    message = strlower(strtrim(message or ""))
    if message == "show" then ShowBoard()
    elseif message == "events" then
        for index, entry in ipairs(probe.eventLog) do
            Print(("%d %s t=%.2f %sx%s scale=%.4f"):format(index, entry.event, entry.at, tostring(entry.width or ""), tostring(entry.height or ""), entry.scale))
        end
        if #probe.eventLog == 0 then Print("no scale/display events since load") end
    elseif message == "clear" then
        YiboCorePixelLineProbeDB.reports, probe.eventLog = {}, {}
        probe.events.UI_SCALE_CHANGED, probe.events.DISPLAY_SIZE_CHANGED, probe.events.UIPARENT_SIZE = 0, 0, 0
        Print("reports and event counters cleared")
    else Report() end
end
