local addonName, ns = ...
local YBP = _G.YiboBeastPaths

local overlayFrames = {}
local routeNodeFrames = {}
local hoveredRoutePetID = nil
local defaultMapBounds = {
    left = 0.0,
    top = 0.0,
    right = 1.0,
    bottom = 1.0,
}
local defaultTransform = {
    offsetX = 0.0,
    offsetY = 0.0,
    scale = 1.0,
    scaleX = 1.0,
    scaleY = 1.0,
    thickness = 1.0,
    opacity = 1.0,
}
local thicknessOffsets = {
    { 0, 0 },
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
}
local zoneNameToMapID = {
    ["翡翠林"] = 371,
    ["Jade Forest"] = 371,
    ["The Jade Forest"] = 371,
    ["昆莱山"] = 379,
    ["Kun-Lai Summit"] = 379,
    ["四风谷"] = 376,
    ["Valley of the Four Winds"] = 376,
    ["卡桑琅丛林"] = 418,
    ["Krasarang Wilds"] = 418,
    ["恐惧废土"] = 422,
    ["Dread Wastes"] = 422,
    ["锦绣谷"] = 390,
    ["Vale of Eternal Blossoms"] = 390,
    ["螳螂高原"] = 388,
    ["Townlong Steppes"] = 388,
}

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi * 0.5
    elseif y < 0 then
        return -math.pi * 0.5
    end

    return 0
end
local blockedParentMapNames = {
    ["Pandaria"] = true,
    ["潘达利亚"] = true,
}

for _, pet in pairs(ns.pets or {}) do
    if pet.zone and pet.mapID and not zoneNameToMapID[pet.zone] then
        zoneNameToMapID[pet.zone] = pet.mapID
    end
end

local function TrimText(text)
    if type(text) ~= "string" then
        return nil
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end

    return text
end

local function GetMapDropdownText()
    local candidates = {
        "WorldMapFrameAreaDropDownText",
        "WorldMapFrameZoneDropDownText",
        "WorldMapZoneDropDownText",
        "WorldMapAreaDropDownText",
    }

    for _, name in ipairs(candidates) do
        local widget = _G[name]
        if widget and widget.GetText then
            local text = TrimText(widget:GetText())
            if text then
                return text
            end
        end
    end
end

function YBP:GetCurrentWorldMapID()
    local text = GetMapDropdownText()
    if text then
        if blockedParentMapNames[text] then
            return nil
        end

        if zoneNameToMapID[text] then
            return zoneNameToMapID[text]
        end
    end

    if WorldMapFrame and WorldMapFrame.GetMapID then
        local mapID = WorldMapFrame:GetMapID()
        if mapID and mapID > 0 then
            return mapID
        end
    end

    if WorldMapFrame and WorldMapFrame.mapID and WorldMapFrame.mapID > 0 then
        return WorldMapFrame.mapID
    end
end

local function GetOverlayParent()
    if _G.WorldMapDetailFrame then
        return _G.WorldMapDetailFrame
    end

    if _G.WorldMapButton then
        return _G.WorldMapButton
    end

    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end

    return WorldMapFrame
end

local function EnsureOverlayFrame(petID, parent)
    local frame = overlayFrames[petID]
    if frame and frame:GetParent() ~= parent then
        frame:Hide()
        overlayFrames[petID] = nil
        frame = nil
    end

    if frame then
        return frame, frame.legacyHost and frame.legacyHost.texture or nil
    end

    frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
    frame:SetAllPoints(parent)
    frame:Hide()

    frame.legacyHost = CreateFrame("Frame", nil, frame)
    frame.legacyHost:SetFrameStrata("HIGH")
    frame.legacyHost:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.legacyHost:SetAllPoints(frame)
    frame.legacyHost:Hide()
    frame.legacyHost.isLegacyHost = true
    frame.legacyHost.ownerOverlayFrame = frame

    frame.legacyHost.texture = frame.legacyHost:CreateTexture(nil, "OVERLAY")
    frame.legacyHost.texture:SetAllPoints(frame.legacyHost)
    frame.legacyHost.texture:SetBlendMode("BLEND")

    frame.legacyHost.emphasis = frame.legacyHost:CreateTexture(nil, "OVERLAY")
    frame.legacyHost.emphasis:SetAllPoints(frame.legacyHost)
    frame.legacyHost.emphasis:SetBlendMode("ADD")
    frame.legacyHost.emphasis:Hide()

    frame.legacyHost.echoes = {}
    for i = 2, #thicknessOffsets do
        local echo = frame.legacyHost:CreateTexture(nil, "OVERLAY")
        echo:SetBlendMode("BLEND")
        echo:Hide()
        frame.legacyHost.echoes[#frame.legacyHost.echoes + 1] = echo
    end

    overlayFrames[petID] = frame
    return frame, frame.legacyHost.texture
end

local function HideAllRouteNodes()
    for _, nodeMap in pairs(routeNodeFrames) do
        for _, button in pairs(nodeMap) do
            button:Hide()
        end
    end
end

local function GetNodeRoleLabel(role)
    if role == "start" then
        return "路线起点"
    elseif role == "end" then
        return "路线终点"
    elseif role == "mid" then
        return "路线节点"
    end

    return "路线交互点"
end

local function BuildTooltipData(petID, node)
    local tooltipData = ns.routeNodeTooltips and ns.routeNodeTooltips[petID] or nil
    local pet = ns.pets and ns.pets[petID] or nil
    local title = (tooltipData and tooltipData.title) or (pet and pet.name) or ("宠物 " .. tostring(petID))
    local subtitle = (tooltipData and tooltipData.subtitle) or (pet and pet.nameEN) or nil
    local titleSuffix = tooltipData and tooltipData.titleSuffix or nil
    local colorName = tooltipData and tooltipData.colorName or nil
    local displayLabel = tooltipData and tooltipData.displayLabel or colorName or nil
    local iconTexture = tooltipData and tooltipData.iconTexture or "Interface\\Icons\\Ability_Hunter_BeastCall"
    local imageTexture = tooltipData and tooltipData.imageTexture or iconTexture
    local tooltipTexture = tooltipData and tooltipData.tooltipTexture or imageTexture
    local trackName = tooltipData and tooltipData.trackName or nil
    local trackNameEN = tooltipData and tooltipData.trackNameEN or nil
    local footTexture = "Interface\\Icons\\Ability_Tracking"
    local zoneName = pet and (pet.zone or pet.zoneEN) or nil

    return {
        title = title,
        subtitle = subtitle,
        titleSuffix = titleSuffix,
        trackName = trackName,
        trackNameEN = trackNameEN,
        colorName = colorName,
        displayLabel = displayLabel,
        iconTexture = iconTexture,
        imageTexture = imageTexture,
        tooltipTexture = tooltipTexture,
        footTexture = footTexture,
        zoneName = zoneName,
        roleLabel = GetNodeRoleLabel(node and node.role),
        isPlaceholder = node and node.isPlaceholder or false,
        npcID = tooltipData and tooltipData.npcID or nil,
        routeID = petID,
    }
end

local routeNodeTooltip

local function GetOrCreateRouteNodeTooltip()
    if routeNodeTooltip then
        return routeNodeTooltip
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(200)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.07, 0.04, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.45, 0.10, 0.22, 0.90)
    frame:Hide()

    frame.portraitBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.portraitBg:SetSize(56, 56)
    frame.portraitBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.portraitBg:SetBackdropColor(0.10, 0.10, 0.14, 0.98)
    frame.portraitBg:SetBackdropBorderColor(0.85, 0.66, 0.20, 0.90)

    frame.portrait = frame.portraitBg:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetPoint("TOPLEFT", frame.portraitBg, "TOPLEFT", 3, -3)
    frame.portrait:SetPoint("BOTTOMRIGHT", frame.portraitBg, "BOTTOMRIGHT", -3, 3)
    frame.portrait:SetTexCoord(0.02, 0.98, 0.02, 0.98)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(0.25, 0.85, 1.00)

    frame.meta = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.meta:SetJustifyH("LEFT")
    frame.meta:SetTextColor(1.00, 0.82, 0.00)

    frame.trackName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.trackName:SetJustifyH("LEFT")
    frame.trackName:SetTextColor(0.90, 0.90, 0.96)

    frame.route = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.route:SetJustifyH("LEFT")
    frame.route:SetTextColor(0.72, 0.72, 0.78)

    routeNodeTooltip = frame
    return routeNodeTooltip
end

local function ShowRouteNodeTooltip(button)
    if not button or not button.petID or not button.nodeData then
        return
    end

    local data = BuildTooltipData(button.petID, button.nodeData)
    local tooltip = GetOrCreateRouteNodeTooltip()
    tooltip:ClearAllPoints()
    tooltip:SetPoint(button:GetCenter() > UIParent:GetCenter() and "RIGHT" or "LEFT", button,
        button:GetCenter() > UIParent:GetCenter() and "LEFT" or "RIGHT",
        button:GetCenter() > UIParent:GetCenter() and -12 or 12, 0)

    tooltip.portraitBg:ClearAllPoints()
    tooltip.portraitBg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 10, -10)
    tooltip.portrait:SetTexture(data.tooltipTexture)

    local combinedTitle = data.title or ""
    if data.subtitle and data.subtitle ~= "" then
        combinedTitle = string.format("%s  |cffd9d9d9%s|r", combinedTitle, data.subtitle)
    end
    if data.titleSuffix and data.titleSuffix ~= "" then
        combinedTitle = string.format("%s  |cffffd24a%s|r", combinedTitle, data.titleSuffix)
    end
    local combinedTrackName = data.trackName or ""
    if data.trackNameEN and data.trackNameEN ~= "" then
        combinedTrackName = string.format("%s  |cffd9d9d9%s|r", combinedTrackName, data.trackNameEN)
    end
    tooltip.title:SetText(combinedTitle)
    tooltip.meta:SetText(data.displayLabel or data.colorName or "")
    tooltip.trackName:SetText(combinedTrackName)
    tooltip.route:SetText(string.format("Route ID: %d", data.routeID))

    local textWidth = math.max(
        tooltip.title:GetStringWidth() or 0,
        tooltip.meta:GetStringWidth() or 0,
        tooltip.trackName:GetStringWidth() or 0,
        tooltip.route:GetStringWidth() or 0
    )
    textWidth = math.max(120, math.min(340, textWidth + 8))

    tooltip.title:SetWidth(textWidth)
    tooltip.meta:SetWidth(textWidth)
    tooltip.trackName:SetWidth(textWidth)
    tooltip.route:SetWidth(textWidth)

    tooltip.title:ClearAllPoints()
    tooltip.title:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 74, -12)
    tooltip.meta:ClearAllPoints()
    tooltip.meta:SetPoint("TOPLEFT", tooltip.title, "BOTTOMLEFT", 0, -6)
    tooltip.trackName:ClearAllPoints()
    tooltip.trackName:SetPoint("TOPLEFT", tooltip.meta, "BOTTOMLEFT", 0, -6)
    tooltip.route:ClearAllPoints()
    tooltip.route:SetPoint("TOPLEFT", tooltip.trackName, "BOTTOMLEFT", 0, -6)

    local frameWidth = 74 + textWidth + 12
    local frameHeight = math.max(78, 12
        + (tooltip.title:GetStringHeight() or 0)
        + 6
        + (tooltip.meta:GetStringHeight() or 0)
        + 6
        + (tooltip.trackName:GetStringHeight() or 0)
        + 6
        + (tooltip.route:GetStringHeight() or 0)
        + 12)
    tooltip:SetSize(frameWidth, frameHeight)
    tooltip:Show()
end

function YBP:SetHoveredRoutePetID(petID)
    if hoveredRoutePetID == petID then
        return
    end

    hoveredRoutePetID = petID
    if self.UpdateOverlayHoverState then
        self:UpdateOverlayHoverState()
    end
end

local function EnsureRouteNodeButton(petID, nodeID, parent)
    local petNodes = routeNodeFrames[petID]
    if not petNodes then
        petNodes = {}
        routeNodeFrames[petID] = petNodes
    end

    local button = petNodes[nodeID]
    if button and button:GetParent() ~= parent then
        button:Hide()
        petNodes[nodeID] = nil
        button = nil
    end

    if button then
        return button
    end

    button = CreateFrame("Button", nil, parent)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 30)
    button:RegisterForClicks("LeftButtonUp")
    button:Hide()

    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints(button)

    button.emphasis = button:CreateTexture(nil, "BACKGROUND")
    button.emphasis:SetAtlas("worldquest-questmarker-abilityhighlight")
    button.emphasis:SetBlendMode("ADD")
    button.emphasis:SetSize(26, 26)
    button.emphasis:SetPoint("CENTER", button, "CENTER")
    button.emphasis:SetVertexColor(1.0, 1.0, 1.0, 0.40)
    button.emphasis:Hide()

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAtlas("worldquest-questmarker-abilityhighlight")
    button.highlight:SetAllPoints(button.emphasis)
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetVertexColor(1.00, 1.00, 1.00, 0.20)
    button.highlight:Hide()

    button:SetScript("OnEnter", ShowRouteNodeTooltip)
    button:SetScript("OnLeave", function()
        YBP:SetHoveredRoutePetID(nil)
        if routeNodeTooltip then
            routeNodeTooltip:Hide()
        end
    end)
    button:HookScript("OnEnter", function(self)
        YBP:SetHoveredRoutePetID(self.petID)
    end)

    petNodes[nodeID] = button
    return button
end

local function RefreshOverlayFrameLevel(frame, orderIndex, isHovered)
    if not frame then
        return
    end

    local parent = frame:GetParent()
    local parentLevel = parent and parent:GetFrameLevel() or 1
    local baseLevel = parentLevel + 10 + ((orderIndex or 1) * 2)
    frame.baseFrameLevel = baseLevel

    if isHovered then
        frame:SetFrameLevel(baseLevel + 100)
    else
        frame:SetFrameLevel(baseLevel)
    end

    if frame.legacyHost then
        frame.legacyHost:SetFrameLevel(frame:GetFrameLevel() + 1)
    end
end

local function RefreshRouteNodeButtonsForPet(petID, overlayFrame)
    local nodes = YBP.GetResolvedRouteNodes and YBP:GetResolvedRouteNodes(petID) or (ns.routeNodes and ns.routeNodes[petID])
    local petNodes = routeNodeFrames[petID]
    if petNodes then
        for _, button in pairs(petNodes) do
            button:Hide()
        end
    end

    if not nodes or not overlayFrame or not overlayFrame:IsShown() then
        return
    end

    local showDebugNodes = YBP.ShouldShowRouteNodesOnMap and YBP:ShouldShowRouteNodesOnMap(petID)

    local width = overlayFrame:GetWidth() or 0
    local height = overlayFrame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        return
    end

    for index, node in ipairs(nodes) do
        local isPublicStartNode = node.role == "start" and node.isPlaceholder ~= true
        if showDebugNodes or isPublicStartNode then
            local nodeID = node.id or tostring(index)
            local button = EnsureRouteNodeButton(petID, nodeID, overlayFrame:GetParent())
            local style = ns.routeNodeStyles and ns.routeNodeStyles.default or nil
            local size = (node.size or (style and style.size) or 18) * (node.nodeScale or 1.0)
            local color = node.color or (style and style.color) or { 0.31, 0.85, 1.00 }
            local normalizedX
            local normalizedY
            if overlayFrame.isLegacyHost then
                normalizedX = node.normalizedX or 0.5
                normalizedY = node.normalizedY or 0.5
            else
                local transform = YBP.GetResolvedTransform and YBP:GetResolvedTransform(petID) or defaultTransform
                normalizedX = 0.5 + (transform.offsetX or 0) + (((node.normalizedX or 0.5) - 0.5) * (transform.scale or 1) * (transform.scaleX or 1))
                normalizedY = 0.5 + (transform.offsetY or 0) + (((node.normalizedY or 0.5) - 0.5) * (transform.scale or 1) * (transform.scaleY or 1))
            end
            local x = width * normalizedX
            local y = height * normalizedY

            button.petID = petID
            button.nodeData = node
            button:SetSize(size + 2, size + 2)
            button:ClearAllPoints()
            button:SetPoint("CENTER", overlayFrame, "TOPLEFT", x, -y)
            button.texture:SetAtlas(ns.IS_CLASSIC and "VignetteKillElite" or "VignetteKill")
            button.texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, 0.95)
            button:Show()
        end
    end
end

local function ApplyRouteNodeHoverState(petID, isHovered, hasHoveredTarget)
    local petNodes = routeNodeFrames[petID]
    if not petNodes then
        return
    end

    for _, button in pairs(petNodes) do
        if button and button:IsShown() then
            if hasHoveredTarget then
                if isHovered then
                    button.emphasis:Show()
                    button.highlight:Show()
                    button.texture:SetAlpha(1.0)
                else
                    button.emphasis:Hide()
                    button.highlight:Hide()
                    button.texture:SetAlpha(0.95)
                end
            else
                button.emphasis:Hide()
                button.highlight:Hide()
                button.texture:SetAlpha(0.95)
            end
        end
    end
end

local function ApplyTextureThickness(frame, texturePath, alpha, thickness)
    if not frame or not frame.texture then
        return
    end

    local strength = thickness or 1.0
    if strength < 0.4 then
        strength = 0.4
    end

    local inset = 0
    local finalAlpha = alpha
    if strength < 1.0 then
        -- 位图本身不能真正无损“变细”，这里用轻微收缩 + 降低 alpha 做视觉减细。
        inset = (1.0 - strength) * 6
        finalAlpha = alpha * (0.65 + 0.35 * strength)
    end

    frame.texture:SetTexture(texturePath)
    frame.texture:ClearAllPoints()
    frame.texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    frame.texture:SetAlpha(finalAlpha)

    local layers = math.floor((strength - 1.0) * 8 + 0.5)
    if layers < 0 then
        layers = 0
    elseif layers > #frame.echoes then
        layers = #frame.echoes
    end

    for index, echo in ipairs(frame.echoes) do
        if index <= layers then
            local offset = thicknessOffsets[index + 1]
            echo:SetTexture(texturePath)
            echo:ClearAllPoints()
            echo:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + offset[1], -(inset + offset[2]))
            echo:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset - offset[1]), inset - offset[2])
            echo:SetAlpha(alpha * 0.75)
            echo:Show()
        else
            echo:Hide()
        end
    end
end

local function ApplyOverlayEmphasis(frame, texturePath, active, thickness)
    if not frame or not frame.emphasis then
        return
    end
    if not active then
        frame.emphasis:Hide()
        return
    end

    frame.emphasis:SetTexture(texturePath)
    frame.emphasis:ClearAllPoints()
    frame.emphasis:SetAllPoints(frame)
    frame.emphasis:SetVertexColor(1.0, 1.0, 1.0, 0.40)
    frame.emphasis:SetAlpha(0.40)
    frame.emphasis:Show()
end

local function AcquireVectorSlot(frame, layerKey, slotIndex)
    frame.vectorLayers = frame.vectorLayers or {}
    frame.vectorLayers[layerKey] = frame.vectorLayers[layerKey] or {}

    local slot = frame.vectorLayers[layerKey][slotIndex]
    if slot then
        return slot
    end

    slot = CreateFrame("Frame", nil, frame)
    slot:SetFrameStrata("HIGH")
    slot:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
    slot:EnableMouse(false)
    slot:SetClipsChildren(false)

    slot.texture = slot:CreateTexture(nil, "OVERLAY")
    slot.texture:SetTexture("Interface\\Buttons\\WHITE8X8")

    frame.vectorLayers[layerKey][slotIndex] = slot
    return slot
end

local function HideVectorLayer(frame, layerKey)
    if not frame or not frame.vectorLayers or not frame.vectorLayers[layerKey] then
        return
    end

    for _, slot in ipairs(frame.vectorLayers[layerKey]) do
        slot:Hide()
    end
end

local function HideUnusedVectorSlots(frame, layerKey, lastIndex)
    if not frame or not frame.vectorLayers or not frame.vectorLayers[layerKey] then
        return
    end

    for index = (lastIndex or 0) + 1, #frame.vectorLayers[layerKey] do
        frame.vectorLayers[layerKey][index]:Hide()
    end
end

local function GetAdjustedAlpha(baseAlpha, petID)
    local selectedDebugPetID
    if YBP.IsDebugEnabled and YBP:IsDebugEnabled() and YBP.GetSelectedDebugPetID then
        selectedDebugPetID = YBP:GetSelectedDebugPetID()
    end

    local alpha = baseAlpha or 1.0
    if not hoveredRoutePetID and selectedDebugPetID then
        if petID == selectedDebugPetID then
            alpha = baseAlpha or 1.0
        else
            alpha = (baseAlpha or 1.0) * 0.35
        end
    end

    if hoveredRoutePetID and petID ~= hoveredRoutePetID then
        alpha = alpha * 0.45
    end

    if hoveredRoutePetID and petID == hoveredRoutePetID then
        alpha = math.max(alpha, 0.98)
    end

    return alpha
end

local function TransformRoutePointForMap(petID, point)
    if not point then
        return nil, nil
    end

    local transform = YBP.GetResolvedTransform and YBP:GetResolvedTransform(petID) or defaultTransform
    local x = 0.5 + (transform.offsetX or 0) + (((point.x or 0.5) - 0.5) * (transform.scale or 1) * (transform.scaleX or 1))
    local y = 0.5 + (transform.offsetY or 0) + (((point.y or 0.5) - 0.5) * (transform.scale or 1) * (transform.scaleY or 1))
    return x, y
end

local referenceDisplayTransformCache = {}

local function AccumulateBounds(bounds, x, y)
    if not x or not y then
        return bounds
    end

    if not bounds then
        return {
            minX = x,
            maxX = x,
            minY = y,
            maxY = y,
        }
    end

    if x < bounds.minX then
        bounds.minX = x
    elseif x > bounds.maxX then
        bounds.maxX = x
    end

    if y < bounds.minY then
        bounds.minY = y
    elseif y > bounds.maxY then
        bounds.maxY = y
    end

    return bounds
end

local function BuildReferenceDisplayTransformFromSegments(petID, route)
    if not route or not route.segments or not route.displaySegments then
        return nil
    end

    local sourceBounds
    for _, segment in ipairs(route.segments) do
        for _, point in ipairs(segment.points or {}) do
            local x, y = TransformRoutePointForMap(petID, point)
            sourceBounds = AccumulateBounds(sourceBounds, x, y)
        end
    end

    local targetBounds
    for _, segment in ipairs(route.displaySegments) do
        for _, point in ipairs(segment.points or {}) do
            targetBounds = AccumulateBounds(targetBounds, point.x, point.y)
        end
    end

    if not sourceBounds or not targetBounds then
        return nil
    end

    local sourceWidth = math.max(0.0001, sourceBounds.maxX - sourceBounds.minX)
    local sourceHeight = math.max(0.0001, sourceBounds.maxY - sourceBounds.minY)
    local targetWidth = math.max(0.0001, targetBounds.maxX - targetBounds.minX)
    local targetHeight = math.max(0.0001, targetBounds.maxY - targetBounds.minY)

    local sourceCenterX = (sourceBounds.minX + sourceBounds.maxX) * 0.5
    local sourceCenterY = (sourceBounds.minY + sourceBounds.maxY) * 0.5
    local targetCenterX = (targetBounds.minX + targetBounds.maxX) * 0.5
    local targetCenterY = (targetBounds.minY + targetBounds.maxY) * 0.5

    return {
        scaleX = targetWidth / sourceWidth,
        scaleY = targetHeight / sourceHeight,
        offsetX = targetCenterX - sourceCenterX,
        offsetY = targetCenterY - sourceCenterY,
    }
end

local function GetReferenceDisplayTransform(petID, route)
    if not route then
        return nil
    end

    if route.referenceDisplayTransform then
        return route.referenceDisplayTransform
    end

    local cached = referenceDisplayTransformCache[petID]
    if cached then
        return cached
    end

    local inferred = BuildReferenceDisplayTransformFromSegments(petID, route)
    referenceDisplayTransformCache[petID] = inferred or false
    if inferred then
        return inferred
    end

    return nil
end

local function ResolveDisplayPointForLayer(petID, point, route, layerKey)
    if not point then
        return nil, nil
    end

    local x, y = TransformRoutePointForMap(petID, point)
    if not x or not y then
        return nil, nil
    end

    local shouldUseReferenceDisplayTransform = false
    if layerKey == "reference" and route then
        shouldUseReferenceDisplayTransform = true
    elseif layerKey == "resolved" and route and route.derivedFrom and (route.derivedFrom.footprints or 0) == 0 then
        shouldUseReferenceDisplayTransform = true
    end

    if shouldUseReferenceDisplayTransform and route then
        local transform = GetReferenceDisplayTransform(petID, route)
        if not transform then
            return x, y
        end

        local scaleX = transform.scaleX or 1.0
        local scaleY = transform.scaleY or 1.0
        local offsetX = transform.offsetX or 0.0
        local offsetY = transform.offsetY or 0.0

        x = 0.5 + ((x - 0.5) * scaleX) + offsetX
        y = 0.5 + ((y - 0.5) * scaleY) + offsetY
    end

    return x, y
end

local function DrawLineSlot(frame, layerKey, slotIndex, startX, startY, endX, endY, color, thickness)
    local slot = AcquireVectorSlot(frame, layerKey, slotIndex)
    local dx = endX - startX
    local dy = endY - startY
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= 0.5 then
        slot:Hide()
        return false
    end

    local centerX = (startX + endX) * 0.5
    local centerY = (startY + endY) * 0.5
    -- Route points are measured in a top-left origin with Y growing downward,
    -- while texture rotation math assumes the conventional upward-positive Y.
    local angle = Atan2(-dy, dx)
    local padding = math.max(6, (thickness or 1) * 3)
    local squareSize = length + (padding * 2)

    slot:ClearAllPoints()
    slot:SetPoint("CENTER", frame, "TOPLEFT", centerX, -centerY)
    slot:SetSize(squareSize, squareSize)
    slot.texture:ClearAllPoints()
    slot.texture:SetPoint("CENTER", slot, "CENTER")
    slot.texture:SetSize(length + 1, thickness)
    slot.texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    slot.texture:SetRotation(angle)
    slot:Show()
    return true
end

local function EvaluateCatmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t

    return {
        x = 0.5 * (
            (2 * p1.x)
            + (-p0.x + p2.x) * t
            + ((2 * p0.x) - (5 * p1.x) + (4 * p2.x) - p3.x) * t2
            + (-p0.x + (3 * p1.x) - (3 * p2.x) + p3.x) * t3
        ),
        y = 0.5 * (
            (2 * p1.y)
            + (-p0.y + p2.y) * t
            + ((2 * p0.y) - (5 * p1.y) + (4 * p2.y) - p3.y) * t2
            + (-p0.y + (3 * p1.y) - (3 * p2.y) + p3.y) * t3
        ),
    }
end

local function GetControlPoint(points, index, isLoop)
    if isLoop and #points > 0 then
        local wrappedIndex = ((index - 1) % #points) + 1
        return points[wrappedIndex]
    end

    if index < 1 then
        return points[1]
    elseif index > #points then
        return points[#points]
    end

    return points[index]
end

local function BuildDirectionSmoothedPoints(points, isLoop)
    local count = #points
    if count <= 2 then
        return points
    end

    local smoothed = {}
    for index = 1, count do
        local current = points[index]
        if not isLoop and (index == 1 or index == count) then
            smoothed[index] = { x = current.x, y = current.y }
        else
            local prev = GetControlPoint(points, index - 1, isLoop)
            local next = GetControlPoint(points, index + 1, isLoop)
            smoothed[index] = {
                x = (prev.x * 0.25) + (current.x * 0.50) + (next.x * 0.25),
                y = (prev.y * 0.25) + (current.y * 0.50) + (next.y * 0.25),
            }
        end
    end

    return smoothed
end

local function BuildSmoothedPointSequence(points, isLoop, density)
    local smoothed = {}
    local count = #points
    if count == 0 then
        return smoothed
    end

    if count == 1 then
        smoothed[1] = { x = points[1].x, y = points[1].y }
        return smoothed
    end

    local controlPoints = BuildDirectionSmoothedPoints(points, isLoop)
    local segmentCount = isLoop and count or (count - 1)
    local maxStep = 28 / math.max(1, density or 1)

    smoothed[1] = { x = controlPoints[1].x, y = controlPoints[1].y }

    for segmentIndex = 1, segmentCount do
        local p0 = GetControlPoint(controlPoints, segmentIndex - 1, isLoop)
        local p1 = GetControlPoint(controlPoints, segmentIndex, isLoop)
        local p2 = GetControlPoint(controlPoints, segmentIndex + 1, isLoop)
        local p3 = GetControlPoint(controlPoints, segmentIndex + 2, isLoop)
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local distance = math.sqrt((dx * dx) + (dy * dy))
        local steps = math.max(1, math.ceil(distance / maxStep))

        for step = 1, steps do
            local t = step / steps
            smoothed[#smoothed + 1] = EvaluateCatmullRom(p0, p1, p2, p3, t)
        end
    end

    return smoothed
end

local function RenderRouteLayer(frame, petID, route, layerKey, color, thickness)
    local jointLayerKey = layerKey .. "Joints"
    local segments = route and route.segments or nil

    if not segments then
        HideVectorLayer(frame, layerKey)
        HideVectorLayer(frame, jointLayerKey)
        return
    end

    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        HideVectorLayer(frame, layerKey)
        HideVectorLayer(frame, jointLayerKey)
        return
    end

    local density = YBP.GetRouteDisplayDensity and YBP:GetRouteDisplayDensity() or 2
    local slotIndex = 0
    for _, segment in ipairs(segments) do
        local points = segment.points or {}
        local pixelPoints = {}
        for _, point in ipairs(points) do
            local x, y = ResolveDisplayPointForLayer(petID, point, route, layerKey)
            if x and y then
                pixelPoints[#pixelPoints + 1] = {
                    x = width * x,
                    y = height * y,
                }
            end
        end

        local densePoints = BuildSmoothedPointSequence(pixelPoints, segment.loop and #pixelPoints >= 3, density)

        for pointIndex = 1, (#densePoints - 1) do
            local startPoint = densePoints[pointIndex]
            local endPoint = densePoints[pointIndex + 1]
            if startPoint and endPoint then
                slotIndex = slotIndex + 1
                DrawLineSlot(frame, layerKey, slotIndex, startPoint.x, startPoint.y, endPoint.x, endPoint.y, color, thickness)
            end
        end
    end

    HideUnusedVectorSlots(frame, layerKey, slotIndex)
    HideVectorLayer(frame, jointLayerKey)
end

local function RenderFootprintLayer(frame, petID, points, color, size)
    if not frame then
        return
    end

    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        HideVectorLayer(frame, "footprints")
        return
    end

    local slotIndex = 0
    for _, point in ipairs(points or {}) do
        local x = point and point.x or nil
        local y = point and point.y or nil
        if x and y then
            slotIndex = slotIndex + 1
            local slot = AcquireVectorSlot(frame, "footprints", slotIndex)
            slot:ClearAllPoints()
            slot:SetPoint("CENTER", frame, "TOPLEFT", width * x, -(height * y))
            slot:SetSize(size, size)
            slot.texture:SetRotation(0)
            slot.texture:SetTexture("Interface\\MINIMAP\\POIIcons")
            slot.texture:SetTexCoord(0, 0.125, 0.625, 0.75)
            slot.texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            slot:Show()
        end
    end

    HideUnusedVectorSlots(frame, "footprints", slotIndex)
end

function YBP:UpdateOverlayHoverState()
    for petID, frame in pairs(overlayFrames) do
        ApplyRouteNodeHoverState(petID, petID == hoveredRoutePetID, hoveredRoutePetID ~= nil)
        if frame and frame:IsShown() then
            RefreshOverlayFrameLevel(frame, frame.orderIndex, petID == hoveredRoutePetID)
        end
    end
end

local function HideAllOverlays()
    for _, frame in pairs(overlayFrames) do
        frame:Hide()
    end
    HideAllRouteNodes()
end

function YBP:GetVisiblePetIDsForMap(mapID)
    local petIDs = {}
    local seen = {}
    if not mapID then
        return petIDs
    end

    for petID, route in pairs(ns.referenceRoutes or {}) do
        if route.mapID == mapID and not seen[petID] then
            seen[petID] = true
            petIDs[#petIDs + 1] = petID
        end
    end

    for petID, route in pairs(ns.resolvedRoutes or {}) do
        if route.mapID == mapID and not seen[petID] then
            seen[petID] = true
            petIDs[#petIDs + 1] = petID
        end
    end

    for petID, overlay in pairs(ns.routeOverlays or {}) do
        if overlay.mapID == mapID and not seen[petID] then
            seen[petID] = true
            petIDs[#petIDs + 1] = petID
        end
    end

    table.sort(petIDs)
    return petIDs
end

function YBP:GetResolvedTransform(petID)
    -- 调试模式：优先返回调试临时参数
    if self.IsDebugEnabled and self:IsDebugEnabled() then
        local debugDB = _G.YiboBeastPathsDebugDB
        if debugDB and debugDB.transforms and debugDB.transforms[petID] then
            local dt = debugDB.transforms[petID]
            return {
                offsetX = dt.offsetX ~= nil and dt.offsetX or defaultTransform.offsetX,
                offsetY = dt.offsetY ~= nil and dt.offsetY or defaultTransform.offsetY,
                scale = dt.scale ~= nil and dt.scale or defaultTransform.scale,
                scaleX = dt.scaleX ~= nil and dt.scaleX or defaultTransform.scaleX,
                scaleY = dt.scaleY ~= nil and dt.scaleY or defaultTransform.scaleY,
                thickness = dt.thickness ~= nil and dt.thickness or defaultTransform.thickness,
                opacity = dt.opacity ~= nil and dt.opacity or defaultTransform.opacity,
            }
        end
    end

    local stored = ns.routeTransforms and ns.routeTransforms[petID] or nil

    return {
        offsetX = stored and stored.offsetX or defaultTransform.offsetX,
        offsetY = stored and stored.offsetY or defaultTransform.offsetY,
        scale = stored and stored.scale or defaultTransform.scale,
        scaleX = stored and stored.scaleX or defaultTransform.scaleX,
        scaleY = stored and stored.scaleY or defaultTransform.scaleY,
        thickness = stored and stored.thickness or defaultTransform.thickness,
        opacity = stored and stored.opacity or defaultTransform.opacity,
    }
end

function YBP:GetFormalRouteTransform(petID)
    local stored = ns.routeTransforms and ns.routeTransforms[petID] or nil

    return {
        offsetX = stored and stored.offsetX or defaultTransform.offsetX,
        offsetY = stored and stored.offsetY or defaultTransform.offsetY,
        scale = stored and stored.scale or defaultTransform.scale,
        scaleX = stored and stored.scaleX or defaultTransform.scaleX,
        scaleY = stored and stored.scaleY or defaultTransform.scaleY,
        thickness = stored and stored.thickness or defaultTransform.thickness,
        opacity = stored and stored.opacity or defaultTransform.opacity,
    }
end

function YBP:GetResolvedRouteNodes(petID)
    local formalNodes = ns.routeNodes and ns.routeNodes[petID] or nil
    if not formalNodes then
        return nil
    end

    local debugDB = _G.YiboBeastPathsDebugDB
    local debugNodes = debugDB and debugDB.nodeTransforms and debugDB.nodeTransforms[petID] or nil
    local resolved = {}

    for index, node in ipairs(formalNodes) do
        local debugNode = debugNodes and node.id and debugNodes[node.id] or nil
        resolved[index] = {
            id = node.id,
            role = node.role,
            normalizedX = debugNode and debugNode.normalizedX or node.normalizedX,
            normalizedY = debugNode and debugNode.normalizedY or node.normalizedY,
            nodeScale = debugNode and debugNode.nodeScale or node.nodeScale or 1.0,
            size = debugNode and debugNode.size or node.size,
            color = debugNode and debugNode.color or node.color,
            isPlaceholder = node.isPlaceholder,
        }
        if debugNode and debugNode.isPlaceholder ~= nil then
            resolved[index].isPlaceholder = debugNode.isPlaceholder
        end
    end

    return resolved
end

function YBP:ApplyOverlayTransform(frame, mapBounds, transform)
    local parent = frame and frame:GetParent()
    if not parent then
        return
    end

    local parentWidth = parent:GetWidth() or 0
    local parentHeight = parent:GetHeight() or 0
    if parentWidth <= 0 or parentHeight <= 0 then
        frame:SetAllPoints(parent)
        return
    end

    local bounds = mapBounds or defaultMapBounds
    local finalTransform = transform or defaultTransform
    local baseWidth = parentWidth * (bounds.right - bounds.left)
    local baseHeight = parentHeight * (bounds.bottom - bounds.top)
    local finalScaleX = finalTransform.scale * finalTransform.scaleX
    local finalScaleY = finalTransform.scale * finalTransform.scaleY
    local finalWidth = baseWidth * finalScaleX
    local finalHeight = baseHeight * finalScaleY
    local centerX = parentWidth * bounds.left + (baseWidth * 0.5) + (parentWidth * finalTransform.offsetX)
    local centerY = parentHeight * bounds.top + (baseHeight * 0.5) + (parentHeight * finalTransform.offsetY)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "TOPLEFT", centerX, -centerY)
    frame:SetWidth(finalWidth)
    frame:SetHeight(finalHeight)
end

function YBP:RefreshMapLayer()
    HideAllOverlays()

    if not self.db or not self.db.visible then
        return
    end

    local currentMapID = self:GetCurrentWorldMapID()
    if not currentMapID then
        return
    end

    local petIDs = self:GetVisiblePetIDsForMap(currentMapID)
    if #petIDs == 0 then
        return
    end

    local parent = GetOverlayParent()
    if not parent then
        return
    end

    local mapBounds = ns.mapCanvasBounds and ns.mapCanvasBounds[currentMapID] or defaultMapBounds

    -- 调试模式：确定选中宠物 ID
    local selectedDebugPetID
    if self.IsDebugEnabled and self:IsDebugEnabled() and self.GetSelectedDebugPetID then
        selectedDebugPetID = self:GetSelectedDebugPetID()
    end

    for index, petID in ipairs(petIDs) do
        local overlay = ns.routeOverlays[petID]
        local frame = EnsureOverlayFrame(petID, parent)
        local legacyHost = frame.legacyHost
        local display = self.GetRouteDisplaySettings and self:GetRouteDisplaySettings() or {
            showResolved = true,
            showReference = false,
            showFootprints = true,
            showLegacyOverlay = false,
        }
        local resolvedRoute = self.GetResolvedRoute and self:GetResolvedRoute(petID) or nil
        local referenceRoute = self.GetReferenceRoute and self:GetReferenceRoute(petID) or nil
        local footprintPoints = self.GetFootprintsForPet and self:GetFootprintsForPet(petID, false) or {}

        local resolvedTransform = self:GetResolvedTransform(petID)
        local legacyOverlayTransform = self.GetFormalRouteTransform and self:GetFormalRouteTransform(petID) or resolvedTransform
        local thickness = resolvedTransform.thickness or 1.0
        local resolvedColor = self.GetRouteLayerColor and self:GetRouteLayerColor(petID, "resolved") or { 0.15, 0.95, 0.85, 0.95 }
        local referenceColor = self.GetRouteLayerColor and self:GetRouteLayerColor(petID, "reference") or { 0.65, 0.75, 1.00, 0.35 }
        local footprintColor = self.GetRouteLayerColor and self:GetRouteLayerColor(petID, "footprint") or { 1.00, 0.84, 0.10, 0.95 }
        resolvedColor = { resolvedColor[1], resolvedColor[2], resolvedColor[3], GetAdjustedAlpha((resolvedColor[4] or 0.95) * (resolvedTransform.opacity or 1.0), petID) }
        referenceColor = { referenceColor[1], referenceColor[2], referenceColor[3], GetAdjustedAlpha(referenceColor[4] or 0.35, petID) }
        footprintColor = { footprintColor[1], footprintColor[2], footprintColor[3], GetAdjustedAlpha(footprintColor[4] or 0.95, petID) }

        frame.currentThickness = thickness
        frame.orderIndex = index

        self:ApplyOverlayTransform(frame, mapBounds, defaultTransform)
        if legacyHost then
            self:ApplyOverlayTransform(legacyHost, defaultMapBounds, legacyOverlayTransform)
        end
        RefreshOverlayFrameLevel(frame, index, petID == hoveredRoutePetID)

        if display.showLegacyOverlay and overlay and overlay.texture and legacyHost then
            ApplyTextureThickness(legacyHost, overlay.texture, GetAdjustedAlpha((resolvedTransform.opacity or 1.0) * 0.32, petID), thickness)
            legacyHost.texturePath = overlay.texture
            legacyHost.texture:Show()
            legacyHost:Show()
        else
            if legacyHost then
                legacyHost.texturePath = nil
                legacyHost.texture:Hide()
                legacyHost.emphasis:Hide()
                for _, echo in ipairs(legacyHost.echoes) do
                    echo:Hide()
                end
                legacyHost:Hide()
            end
        end

        if display.showResolved then
            RenderRouteLayer(frame, petID, resolvedRoute, "resolved", resolvedColor, (self.GetRouteLayerThickness and self:GetRouteLayerThickness(petID, "resolved") or 3) * thickness)
        else
            HideVectorLayer(frame, "resolved")
            HideVectorLayer(frame, "resolvedJoints")
        end

        if display.showReference and self.IsDebugEnabled and self:IsDebugEnabled() then
            RenderRouteLayer(frame, petID, referenceRoute, "reference", referenceColor, self.GetRouteLayerThickness and self:GetRouteLayerThickness(petID, "reference") or 2)
        else
            HideVectorLayer(frame, "reference")
            HideVectorLayer(frame, "referenceJoints")
        end

        if display.showFootprints then
            RenderFootprintLayer(frame, petID, footprintPoints, footprintColor, self.GetFootprintDisplaySize and self:GetFootprintDisplaySize() or 12)
        else
            HideVectorLayer(frame, "footprints")
        end

        frame:Show()
        RefreshRouteNodeButtonsForPet(petID, frame)
    end

    self:UpdateOverlayHoverState()
end
