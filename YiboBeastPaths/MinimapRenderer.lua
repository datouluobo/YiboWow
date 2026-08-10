local addonName, ns = ...
local YBP = _G.YiboBeastPaths

local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
local TWO_PI = math.pi * 2
local sqrt = math.sqrt
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local floor = math.floor

local minimapState = {
    cacheBuilt = false,
    routesByMap = {},
    segmentPool = {},
    activeCount = 0,
    footprintPool = {},
    activeFootprintCount = 0,
    lastSignature = nil,
    debugStats = {},
}

local MINIMAP_ROUTE_CLIP_RADIUS = 0.995
local MINIMAP_ROUTE_LINE_THICKNESS = 3
local MINIMAP_ROUTE_SEGMENT_STEP_PX = 1
local MINIMAP_ROUTE_SEGMENT_OVERLAP_PX = 2
local MINIMAP_ROUTE_EDGE_PADDING_PX = 3
local MINIMAP_ROUTE_SCREEN_SMOOTH_PASSES = 2
local MINIMAP_FOOTPRINT_SIZE = 12

local minimapSizes = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2 / 3,
        [1] = 400,
        [2] = 333 + 1 / 3,
        [3] = 266 + 2 / 6,
        [4] = 200,
        [5] = 133 + 1 / 3,
    },
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

local function NormalizeAngle(angle)
    while angle > math.pi do
        angle = angle - TWO_PI
    end

    while angle < -math.pi do
        angle = angle + TWO_PI
    end

    return angle
end

local function HideAllMinimapSegments()
    minimapState.activeCount = 0
    for _, slot in ipairs(minimapState.segmentPool) do
        slot:Hide()
    end

    minimapState.activeFootprintCount = 0
    for _, slot in ipairs(minimapState.footprintPool) do
        slot:Hide()
    end
end

local function ResetDebugStats()
    minimapState.debugStats = {
        initialized = minimapState.initialized or false,
        visible = YBP and YBP.db and YBP.db.visible or false,
        cacheBuilt = minimapState.cacheBuilt or false,
        hasHBD = HBD ~= nil,
        hasMinimap = Minimap ~= nil,
        refreshes = (minimapState.debugStats and minimapState.debugStats.refreshes or 0) + 1,
        contextOK = false,
        activeRouteMapID = nil,
        routeCount = 0,
        totalSegments = 0,
        drawnSegments = 0,
        footprintCandidates = 0,
        drawnFootprints = 0,
        clippedSegments = 0,
        skippedInstanceMismatch = 0,
        currentMapID = nil,
        instanceID = nil,
        radius = nil,
        overlayWidth = minimapState.overlay and minimapState.overlay:GetWidth() or nil,
        overlayHeight = minimapState.overlay and minimapState.overlay:GetHeight() or nil,
        reason = nil,
    }
    return minimapState.debugStats
end

local function GetMinimapRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        return C_Minimap.GetViewRadius()
    end

    if not Minimap or not Minimap.GetZoom then
        return nil
    end

    local zoom = Minimap:GetZoom()
    local cvarZoom = tonumber(GetCVar("minimapZoom")) or zoom
    local mode = (cvarZoom == zoom) and "outdoor" or "indoor"
    local radius = minimapSizes[mode] and minimapSizes[mode][zoom]
    if radius then
        return radius * 0.5
    end
end

local function BuildSegmentCache(petID, route)
    local segments = route and route.segments
    if type(segments) ~= "table" then
        return nil
    end

    if not HBD or not route.mapID then
        return nil
    end

    local built = {}
    local color = route.color or { 0.15, 0.95, 0.85, 0.90 }
    local transform = YBP and YBP.GetResolvedMinimapTransform and YBP:GetResolvedMinimapTransform(petID)
        or (ns.routeTransforms and ns.routeTransforms[petID])
        or nil
    local scale = transform and transform.scale or 1.0
    local scaleX = transform and transform.scaleX or 1.0
    local scaleY = transform and transform.scaleY or 1.0
    local offsetX = transform and transform.offsetX or 0.0
    local offsetY = transform and transform.offsetY or 0.0
    local minimapOffsetX = transform and transform.minimapOffsetX or 0.0
    local minimapOffsetY = transform and transform.minimapOffsetY or 0.0
    local minimapScale = transform and transform.minimapScale or 1.0
    local minimapScaleX = transform and transform.minimapScaleX or 1.0
    local minimapScaleY = transform and transform.minimapScaleY or 1.0

    local routeMinX, routeMinY, routeMaxX, routeMaxY
    for _, segment in ipairs(segments) do
        local points = segment.points
        if type(points) == "table" then
            for _, point in ipairs(points) do
                local x = point and point.x
                local y = point and point.y
                if type(x) == "number" and type(y) == "number" then
                    routeMinX = routeMinX and min(routeMinX, x) or x
                    routeMinY = routeMinY and min(routeMinY, y) or y
                    routeMaxX = routeMaxX and max(routeMaxX, x) or x
                    routeMaxY = routeMaxY and max(routeMaxY, y) or y
                end
            end
        end
    end

    local routeCenterX = (routeMinX and routeMaxX) and ((routeMinX + routeMaxX) * 0.5) or 0.5
    local routeCenterY = (routeMinY and routeMaxY) and ((routeMinY + routeMaxY) * 0.5) or 0.5

    local function TransformPoint(point)
        local x = point and point.x
        local y = point and point.y
        if type(x) ~= "number" or type(y) ~= "number" then
            return nil
        end

        local baseMapX = 0.5 + offsetX + ((x - 0.5) * scale * scaleX)
        local baseMapY = 0.5 + offsetY + ((y - 0.5) * scale * scaleY)
        local baseCenterX = 0.5 + offsetX + ((routeCenterX - 0.5) * scale * scaleX)
        local baseCenterY = 0.5 + offsetY + ((routeCenterY - 0.5) * scale * scaleY)
        local mapX = baseCenterX + minimapOffsetX + ((baseMapX - baseCenterX) * minimapScale * minimapScaleX)
        local mapY = baseCenterY + minimapOffsetY + ((baseMapY - baseCenterY) * minimapScale * minimapScaleY)
        local worldX, worldY, instanceID = HBD:GetWorldCoordinatesFromZone(mapX, mapY, route.mapID)
        if not worldX or not worldY or not instanceID then
            return nil
        end

        return {
            mapX = mapX,
            mapY = mapY,
            worldX = worldX,
            worldY = worldY,
            instanceID = instanceID,
        }
    end

    for segmentIndex, segment in ipairs(segments) do
        local points = segment.points
        if type(points) == "table" and #points >= 2 then
            for pointIndex = 1, (#points - 1) do
                local startPoint = TransformPoint(points[pointIndex])
                local endPoint = TransformPoint(points[pointIndex + 1])
                if startPoint and endPoint then
                    built[#built + 1] = {
                        petID = petID,
                        mapID = route.mapID,
                        segmentIndex = segmentIndex,
                        pointIndex = pointIndex,
                        color = color,
                        startPoint = startPoint,
                        endPoint = endPoint,
                    }
                end
            end

            if segment.loop and #points >= 3 then
                local startPoint = TransformPoint(points[#points])
                local endPoint = TransformPoint(points[1])
                if startPoint and endPoint then
                    built[#built + 1] = {
                        petID = petID,
                        mapID = route.mapID,
                        segmentIndex = segmentIndex,
                        pointIndex = #points,
                        color = color,
                        startPoint = startPoint,
                        endPoint = endPoint,
                    }
                end
            end
        end
    end

    return built
end

local function IterateResolvedRoutes()
    local routes = {}

    for petID, pet in pairs(ns.pets or {}) do
        local route = YBP and YBP.GetResolvedRoute and YBP:GetResolvedRoute(petID) or nil
        if route and route.mapID == pet.mapID then
            routes[petID] = route
        end
    end

    return routes
end

local function EnsureRouteCache()
    if minimapState.cacheBuilt then
        return
    end

    wipe(minimapState.routesByMap)

    for petID, route in pairs(IterateResolvedRoutes()) do
        if route and route.mapID then
            local builtSegments = BuildSegmentCache(petID, route)
            if builtSegments and #builtSegments > 0 then
                minimapState.routesByMap[route.mapID] = minimapState.routesByMap[route.mapID] or {}
                minimapState.routesByMap[route.mapID][#minimapState.routesByMap[route.mapID] + 1] = {
                    petID = petID,
                    mapID = route.mapID,
                    color = route.color,
                    segments = builtSegments,
                }
            end
        end
    end

    for _, routes in pairs(minimapState.routesByMap) do
        table.sort(routes, function(a, b)
            return a.petID < b.petID
        end)
    end

    minimapState.cacheBuilt = true
end

function YBP:InvalidateMinimapRouteCache()
    minimapState.cacheBuilt = false
    minimapState.lastSignature = nil
    wipe(minimapState.routesByMap)
end

local function AcquireSegmentSlot()
    local index = minimapState.activeCount + 1
    local slot = minimapState.segmentPool[index]
    if not slot then
        slot = CreateFrame("Frame", nil, minimapState.overlay)
        slot:SetSize(16, 16)
        slot:SetFrameStrata("DIALOG")
        slot:SetFrameLevel((minimapState.overlay:GetFrameLevel() or 1) + 20)
        slot:EnableMouse(false)

        slot.line = slot:CreateTexture(nil, "OVERLAY")
        slot.line:SetTexture("Interface\\Buttons\\WHITE8X8")
        slot.line:SetBlendMode("BLEND")

        minimapState.segmentPool[index] = slot
    end

    minimapState.activeCount = index
    return slot
end

local function AcquireFootprintSlot()
    local index = minimapState.activeFootprintCount + 1
    local slot = minimapState.footprintPool[index]
    if not slot then
        slot = CreateFrame("Frame", nil, minimapState.overlay)
        slot:SetSize(MINIMAP_FOOTPRINT_SIZE, MINIMAP_FOOTPRINT_SIZE)
        slot:SetFrameStrata("DIALOG")
        slot:SetFrameLevel((minimapState.overlay:GetFrameLevel() or 1) + 24)
        slot:EnableMouse(false)

        slot.icon = slot:CreateTexture(nil, "OVERLAY")
        slot.icon:SetAllPoints(slot)
        slot.icon:SetTexture("Interface\\MINIMAP\\POIIcons")
        slot.icon:SetTexCoord(0, 0.125, 0.625, 0.75)

        minimapState.footprintPool[index] = slot
    end

    minimapState.activeFootprintCount = index
    return slot
end

local function TrimUnusedSegmentSlots()
    for index = minimapState.activeCount + 1, #minimapState.segmentPool do
        minimapState.segmentPool[index]:Hide()
    end

    for index = minimapState.activeFootprintCount + 1, #minimapState.footprintPool do
        minimapState.footprintPool[index]:Hide()
    end
end

local function ClipLineToCircle(x1, y1, x2, y2, radius)
    local r2 = radius * radius
    local inside1 = (x1 * x1 + y1 * y1) <= r2
    local inside2 = (x2 * x2 + y2 * y2) <= r2
    if inside1 and inside2 then
        return x1, y1, x2, y2
    end

    local dx = x2 - x1
    local dy = y2 - y1
    local a = dx * dx + dy * dy
    if a <= 0 then
        return nil
    end

    local b = 2 * (x1 * dx + y1 * dy)
    local c = x1 * x1 + y1 * y1 - r2
    local disc = b * b - 4 * a * c
    if disc < 0 then
        return nil
    end

    local root = sqrt(disc)
    local t1 = (-b - root) / (2 * a)
    local t2 = (-b + root) / (2 * a)
    if t1 > t2 then
        t1, t2 = t2, t1
    end

    local startT = max(0, t1)
    local endT = min(1, t2)
    if startT > endT then
        return nil
    end

    return x1 + dx * startT, y1 + dy * startT, x1 + dx * endT, y1 + dy * endT
end

local function GetRouteTransformContext()
    if not HBD or not Minimap or not Minimap:IsVisible() then
        return nil
    end

    local playerX, playerY, instanceID = HBD:GetPlayerWorldPosition()
    local currentMapID = HBD:GetPlayerZone()
    local radius = GetMinimapRadius()
    if not playerX or not playerY or not instanceID or not currentMapID or not radius or radius <= 0 then
        return nil
    end

    local halfWidth = (Minimap:GetWidth() or 0) * 0.5
    local halfHeight = (Minimap:GetHeight() or 0) * 0.5
    if halfWidth <= 0 or halfHeight <= 0 then
        return nil
    end

    local rotate = (GetCVar("rotateMinimap") == "1")
    local facing = rotate and GetPlayerFacing() or 0
    if rotate and not facing then
        return nil
    end

    local mapSin = rotate and sin(facing) or 0
    local mapCos = rotate and cos(facing) or 1

    return {
        currentMapID = currentMapID,
        playerWorldX = playerX,
        playerWorldY = playerY,
        instanceID = instanceID,
        radius = radius,
        halfWidth = halfWidth,
        halfHeight = halfHeight,
        rotate = rotate,
        facing = facing or 0,
        mapSin = mapSin,
        mapCos = mapCos,
    }
end

local function ToMinimapNormalizedFromWorldPoint(point, context)
    local worldX = point and point.worldX
    local worldY = point and point.worldY
    if type(worldX) ~= "number" or type(worldY) ~= "number" then
        return nil
    end

    local xDist = context.playerWorldX - worldX
    local yDist = context.playerWorldY - worldY

    if context.rotate then
        local dx = xDist
        local dy = yDist
        xDist = dx * context.mapCos - dy * context.mapSin
        yDist = dx * context.mapSin + dy * context.mapCos
    end

    return xDist / context.radius, yDist / context.radius
end

local function UpdateSegmentSlot(slot, startX, startY, endX, endY, color, thicknessScale, overlapPx)
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 0.9
    local dx = endX - startX
    local dy = endY - startY
    local length = sqrt(dx * dx + dy * dy)
    if length < 0.5 then
        slot:Hide()
        return false
    end

    overlapPx = overlapPx or MINIMAP_ROUTE_SEGMENT_OVERLAP_PX
    if overlapPx > 0 and length > 0 then
        local nx = dx / length
        local ny = dy / length
        startX = startX - (nx * overlapPx)
        startY = startY - (ny * overlapPx)
        endX = endX + (nx * overlapPx)
        endY = endY + (ny * overlapPx)
        dx = endX - startX
        dy = endY - startY
        length = sqrt(dx * dx + dy * dy)
    end

    local centerX = (startX + endX) * 0.5
    local centerY = (startY + endY) * 0.5
    local angle = NormalizeAngle(Atan2(dy, dx))

    slot:ClearAllPoints()
    slot:SetPoint("CENTER", minimapState.overlay, "CENTER", centerX, centerY)
    slot.line:ClearAllPoints()
    slot.line:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot.line:SetSize(length + 1, MINIMAP_ROUTE_LINE_THICKNESS * (thicknessScale or 1.0))
    slot.line:SetRotation(angle)
    slot.line:SetVertexColor(r, g, b, min(max(a, 0.96), 0.99))

    slot:Show()
    return true
end

local function AppendProjectedPoint(points, point, context)
    if not point or point.instanceID ~= context.instanceID then
        return false
    end

    local nx, ny = ToMinimapNormalizedFromWorldPoint(point, context)
    if not nx or not ny then
        return false
    end

    local last = points[#points]
    if last and math.abs(last.nx - nx) < 0.000001 and math.abs(last.ny - ny) < 0.000001 then
        return true
    end

    points[#points + 1] = {
        nx = nx,
        ny = ny,
    }
    return true
end

local function BuildScreenSmoothedPoints(points)
    if #points <= 2 then
        return points
    end

    local smoothed = points
    for _ = 1, MINIMAP_ROUTE_SCREEN_SMOOTH_PASSES do
        local nextPoints = { smoothed[1] }
        for index = 1, (#smoothed - 1) do
            local current = smoothed[index]
            local nextPoint = smoothed[index + 1]
            nextPoints[#nextPoints + 1] = {
                nx = (current.nx * 0.75) + (nextPoint.nx * 0.25),
                ny = (current.ny * 0.75) + (nextPoint.ny * 0.25),
            }
            nextPoints[#nextPoints + 1] = {
                nx = (current.nx * 0.25) + (nextPoint.nx * 0.75),
                ny = (current.ny * 0.25) + (nextPoint.ny * 0.75),
            }
        end
        nextPoints[#nextPoints + 1] = smoothed[#smoothed]
        smoothed = nextPoints
    end

    return smoothed
end

local function DrawMinimapScreenLine(self, stats, route, color, lineThickness, nx1, ny1, nx2, ny2, context)
    local cx1, cy1, cx2, cy2 = ClipLineToCircle(nx1, ny1, nx2, ny2, MINIMAP_ROUTE_CLIP_RADIUS)
    if not cx1 or not cy1 or not cx2 or not cy2 then
        return
    end

    stats.clippedSegments = stats.clippedSegments + 1
    local startX = cx1 * context.halfWidth
    local startY = -cy1 * context.halfHeight
    local endX = cx2 * context.halfWidth
    local endY = -cy2 * context.halfHeight
    local radiusPx = min(context.halfWidth, context.halfHeight) * MINIMAP_ROUTE_CLIP_RADIUS
    local nearEdge = (sqrt((startX * startX) + (startY * startY)) >= (radiusPx - MINIMAP_ROUTE_EDGE_PADDING_PX))
        or (sqrt((endX * endX) + (endY * endY)) >= (radiusPx - MINIMAP_ROUTE_EDGE_PADDING_PX))
    local overlapPx = nearEdge and 0 or MINIMAP_ROUTE_SEGMENT_OVERLAP_PX
    local dx = endX - startX
    local dy = endY - startY
    local pixelLength = sqrt(dx * dx + dy * dy)
    local steps = max(1, floor(pixelLength / MINIMAP_ROUTE_SEGMENT_STEP_PX))
    local prevX = startX
    local prevY = startY

    for stepIndex = 1, steps do
        local t = stepIndex / steps
        local markerX = startX + dx * t
        local markerY = startY + dy * t
        local slot = AcquireSegmentSlot()
        if not UpdateSegmentSlot(slot, prevX, prevY, markerX, markerY, color or route.color or {}, lineThickness, overlapPx) then
            minimapState.activeCount = minimapState.activeCount - 1
        else
            stats.drawnSegments = stats.drawnSegments + 1
        end
        prevX = markerX
        prevY = markerY
    end
end

local function BuildRefreshSignature(context)
    local facingBucket = context.rotate and math.floor(((context.facing or 0) * 180 / math.pi) + 0.5) or 0
    return table.concat({
        tostring(context.currentMapID),
        tostring(context.instanceID),
        string.format("%.1f", context.playerWorldX),
        string.format("%.1f", context.playerWorldY),
        tostring(Minimap:GetZoom() or 0),
        tostring(facingBucket),
        tostring(GetCVar("rotateMinimap") or "0"),
        string.format("%.1f", context.radius),
    }, ":")
end

local function ResolveActiveRouteMapID(currentMapID)
    local mapID = currentMapID
    while mapID do
        if minimapState.routesByMap[mapID] then
            return mapID
        end

        if not C_Map or not C_Map.GetMapInfo then
            break
        end

        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID or nil
    end
end

local function CollectVisibleFootprints(routes, context)
    local candidates = {}
    local limit = (YBP and YBP.GetMinimapNearbyPointLimit and YBP:GetMinimapNearbyPointLimit()) or 6

    for _, route in ipairs(routes or {}) do
        local points = YBP and YBP.GetFootprintsForPet and YBP:GetFootprintsForPet(route.petID, false) or nil
        local color = YBP and YBP.GetRouteLayerColor and YBP:GetRouteLayerColor(route.petID, "footprint") or { 1.00, 0.84, 0.10, 0.95 }
        for _, point in ipairs(points or {}) do
            if point.mapID == route.mapID then
                local worldX, worldY, instanceID = HBD:GetWorldCoordinatesFromZone(point.x, point.y, point.mapID)
                if worldX and worldY and instanceID == context.instanceID then
                    local nx, ny = ToMinimapNormalizedFromWorldPoint({
                        worldX = worldX,
                        worldY = worldY,
                    }, context)
                    if nx and ny then
                        local distance = sqrt((nx * nx) + (ny * ny))
                        if distance <= MINIMAP_ROUTE_CLIP_RADIUS then
                            candidates[#candidates + 1] = {
                                nx = nx,
                                ny = ny,
                                distance = distance,
                                color = color,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local visible = {}
    for index = 1, min(#candidates, limit) do
        visible[index] = candidates[index]
    end

    return candidates, visible
end

function YBP:InitializeMinimapRenderer()
    if minimapState.initialized or not Minimap then
        return
    end

    minimapState.overlay = CreateFrame("Frame", nil, Minimap)
    minimapState.overlay:SetAllPoints(Minimap)
    minimapState.overlay:SetFrameStrata("DIALOG")
    minimapState.overlay:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 15)
    minimapState.overlay:EnableMouse(false)

    minimapState.updateFrame = CreateFrame("Frame")
    minimapState.updateFrame.elapsed = 0
    minimapState.updateFrame:SetScript("OnEvent", function()
        if YBP.RefreshMinimapLayer then
            YBP:RefreshMinimapLayer(true)
        end
    end)
    minimapState.updateFrame:SetScript("OnUpdate", function(_, elapsed)
        minimapState.updateFrame.elapsed = minimapState.updateFrame.elapsed + elapsed
        if minimapState.updateFrame.elapsed < 0.05 then
            return
        end

        minimapState.updateFrame.elapsed = 0
        if YBP.RefreshMinimapLayer then
            YBP:RefreshMinimapLayer()
        end
    end)
    minimapState.updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    minimapState.updateFrame:RegisterEvent("ZONE_CHANGED")
    minimapState.updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    minimapState.updateFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    minimapState.updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    minimapState.updateFrame:RegisterEvent("CVAR_UPDATE")

    minimapState.initialized = true
end

function YBP:GetMinimapDebugReport()
    local stats = minimapState.debugStats or {}
    local lines = {
        "|cff4fd8ff[YiboBeastPaths Minimap]|r",
        string.format("initialized=%s visible=%s cacheBuilt=%s", tostring(minimapState.initialized or false), tostring(self.db and self.db.visible or false), tostring(minimapState.cacheBuilt or false)),
        string.format("hasHBD=%s hasMinimap=%s", tostring(HBD ~= nil), tostring(Minimap ~= nil)),
        string.format("currentMapID=%s activeRouteMapID=%s instanceID=%s radius=%s", tostring(stats.currentMapID), tostring(stats.activeRouteMapID), tostring(stats.instanceID), tostring(stats.radius)),
        string.format("routeCount=%s totalSegments=%s drawnSegments=%s footprints=%s/%s clippedSegments=%s skippedInstanceMismatch=%s", tostring(stats.routeCount), tostring(stats.totalSegments), tostring(stats.drawnSegments), tostring(stats.drawnFootprints), tostring(stats.footprintCandidates), tostring(stats.clippedSegments), tostring(stats.skippedInstanceMismatch)),
        string.format("overlaySize=%sx%s activeSlots=%s", tostring(stats.overlayWidth), tostring(stats.overlayHeight), tostring(minimapState.activeCount or 0)),
        string.format("contextOK=%s reason=%s refreshes=%s", tostring(stats.contextOK), tostring(stats.reason), tostring(stats.refreshes)),
    }
    return lines
end

function YBP:RefreshMinimapLayer(force)
    local stats = ResetDebugStats()
    if not minimapState.initialized then
        stats.reason = "not_initialized"
        return
    end

    if not self.db or not self.db.visible then
        minimapState.lastSignature = nil
        stats.reason = "addon_hidden"
        HideAllMinimapSegments()
        return
    end

    EnsureRouteCache()
    stats.cacheBuilt = minimapState.cacheBuilt or false

    local context = GetRouteTransformContext()
    if not context then
        minimapState.lastSignature = nil
        stats.reason = "missing_context"
        HideAllMinimapSegments()
        return
    end
    stats.contextOK = true
    stats.currentMapID = context.currentMapID
    stats.instanceID = context.instanceID
    stats.radius = context.radius
    stats.overlayWidth = context.halfWidth * 2
    stats.overlayHeight = context.halfHeight * 2

    local signature = BuildRefreshSignature(context)
    if not force and signature == minimapState.lastSignature then
        stats.reason = "signature_unchanged"
        return
    end
    minimapState.lastSignature = signature

    local activeRouteMapID = ResolveActiveRouteMapID(context.currentMapID)
    stats.activeRouteMapID = activeRouteMapID
    local routes = activeRouteMapID and minimapState.routesByMap[activeRouteMapID] or nil
    if not routes or #routes == 0 then
        stats.reason = "no_routes_for_map"
        HideAllMinimapSegments()
        return
    end
    stats.routeCount = #routes

    minimapState.activeCount = 0

    for _, route in ipairs(routes) do
        stats.totalSegments = stats.totalSegments + #route.segments
        local minimapTransform = self.GetResolvedMinimapTransform and self:GetResolvedMinimapTransform(route.petID) or nil
        local lineThickness = minimapTransform and minimapTransform.minimapLineThickness or 1.0
        local currentSegmentIndex
        local currentPoints = {}
        local currentColor = route.color or {}

        local function FlushCurrentPoints()
            if #currentPoints < 2 then
                currentPoints = {}
                return
            end

            local smoothedPoints = BuildScreenSmoothedPoints(currentPoints)
            for pointIndex = 1, (#smoothedPoints - 1) do
                local startPoint = smoothedPoints[pointIndex]
                local endPoint = smoothedPoints[pointIndex + 1]
                DrawMinimapScreenLine(self, stats, route, currentColor, lineThickness, startPoint.nx, startPoint.ny, endPoint.nx, endPoint.ny, context)
            end
            currentPoints = {}
        end

        for _, segment in ipairs(route.segments) do
            local sameRouteSegment = currentSegmentIndex == segment.segmentIndex
            if currentSegmentIndex and not sameRouteSegment then
                FlushCurrentPoints()
            end

            currentSegmentIndex = segment.segmentIndex
            currentColor = segment.color or route.color or {}

            local appendedStart = AppendProjectedPoint(currentPoints, segment.startPoint, context)
            local appendedEnd = AppendProjectedPoint(currentPoints, segment.endPoint, context)
            if not appendedStart or not appendedEnd then
                stats.skippedInstanceMismatch = stats.skippedInstanceMismatch + 1
                FlushCurrentPoints()
                currentSegmentIndex = nil
            else
                currentSegmentIndex = segment.segmentIndex
            end
        end

        FlushCurrentPoints()
    end

    local footprintCandidates, visibleFootprints = CollectVisibleFootprints(routes, context)
    stats.footprintCandidates = #footprintCandidates
    for _, footprint in ipairs(visibleFootprints) do
        local slot = AcquireFootprintSlot()
        slot:ClearAllPoints()
        slot:SetPoint("CENTER", minimapState.overlay, "CENTER", footprint.nx * context.halfWidth, -(footprint.ny * context.halfHeight))
        slot.icon:SetVertexColor(
            footprint.color[1] or 1,
            footprint.color[2] or 1,
            footprint.color[3] or 1,
            footprint.color[4] or 0.95
        )
        slot:Show()
        stats.drawnFootprints = stats.drawnFootprints + 1
    end

    stats.reason = (stats.drawnSegments > 0) and "drawn" or "no_visible_segments"
    TrimUnusedSegmentSlots()
end
