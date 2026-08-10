local addonName, ns = ...
local YBP = _G.YiboBeastPaths

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = DeepCopy(child)
    end
    return copy
end

local function GetSavedReferenceDisplayTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.referenceDisplayTransforms then
        return nil
    end

    local transform = db.referenceDisplayTransforms[petID]
    if not transform then
        return nil
    end

    return DeepCopy(transform)
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function Lerp(a, b, t)
    return a + ((b - a) * t)
end

local defaultTransform = {
    offsetX = 0.0,
    offsetY = 0.0,
    scale = 1.0,
    scaleX = 1.0,
    scaleY = 1.0,
}

local function EnsureFusionDB()
    if type(_G.YiboBeastPathsDebugDB) ~= "table" then
        _G.YiboBeastPathsDebugDB = {}
    end

    local debugDB = _G.YiboBeastPathsDebugDB
    debugDB.routeFusion = debugDB.routeFusion or {
        autoResolve = true,
        display = {
            showResolved = true,
            showReference = false,
            showFootprints = true,
            showLegacyOverlay = false,
        },
        footprintAnchors = {},
        visual = {},
    }

    local fusionDB = debugDB.routeFusion
    fusionDB.display = fusionDB.display or {}
    if fusionDB.display.showResolved == nil then
        fusionDB.display.showResolved = true
    end
    if fusionDB.display.showReference == nil then
        fusionDB.display.showReference = false
    end
    if fusionDB.display.showFootprints == nil then
        fusionDB.display.showFootprints = true
    end
    if fusionDB.display.showLegacyOverlay == nil then
        fusionDB.display.showLegacyOverlay = false
    end
    fusionDB.footprintAnchors = fusionDB.footprintAnchors or {}
    fusionDB.visual = fusionDB.visual or {}

    return fusionDB
end

local function GetActiveFootprintStore(petID)
    local fusionDB = EnsureFusionDB()
    if not fusionDB.footprintAnchors[petID] then
        local seed = ns.footprintAnchors and ns.footprintAnchors[petID] or nil
        fusionDB.footprintAnchors[petID] = DeepCopy(seed or {
            petID = petID,
            points = {},
        })
    end

    return fusionDB.footprintAnchors[petID]
end

local function GetDisplayMeta(petID)
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    local perPet = ns.routeDisplayMeta and ns.routeDisplayMeta.perPet and ns.routeDisplayMeta.perPet[petID] or {}
    return defaults, perPet
end

local function GetVisualOverrides()
    return EnsureFusionDB().visual
end

local function GetDisplayValue(key, fallback)
    local overrides = GetVisualOverrides()
    local value = overrides[key]
    if type(value) == "number" then
        return value
    end
    return fallback
end

local function GetRouteTransformForPet(petID)
    if YBP and YBP.GetResolvedTransform then
        return YBP:GetResolvedTransform(petID) or defaultTransform
    end
    return defaultTransform
end

local function InvertMapPointToRouteSpace(petID, point)
    if not point then
        return nil
    end

    local transform = GetRouteTransformForPet(petID)
    local scaleX = (transform.scale or 1) * (transform.scaleX or 1)
    local scaleY = (transform.scale or 1) * (transform.scaleY or 1)
    if math.abs(scaleX) < 0.0001 then
        scaleX = 1
    end
    if math.abs(scaleY) < 0.0001 then
        scaleY = 1
    end

    return {
        x = 0.5 + (((point.x or 0.5) - 0.5 - (transform.offsetX or 0)) / scaleX),
        y = 0.5 + (((point.y or 0.5) - 0.5 - (transform.offsetY or 0)) / scaleY),
    }
end

function YBP:GetRouteFusionSettings()
    return EnsureFusionDB()
end

function YBP:GetRouteDisplaySettings()
    return EnsureFusionDB().display
end

function YBP:SetRouteDisplaySetting(key, value)
    local display = self:GetRouteDisplaySettings()
    display[key] = value and true or false
    self:RefreshRouteFusionViews()
end

function YBP:ApplyRouteDisplayPreset(preset)
    local display = self:GetRouteDisplaySettings()
    if preset == "all" then
        display.showResolved = true
        display.showReference = true
        display.showFootprints = true
        display.showLegacyOverlay = true
    elseif preset == "resolvedOnly" then
        display.showResolved = true
        display.showReference = false
        display.showFootprints = false
        display.showLegacyOverlay = false
    else
        display.showResolved = true
        display.showReference = false
        display.showFootprints = true
        display.showLegacyOverlay = false
    end
    self:RefreshRouteFusionViews()
end

function YBP:RefreshRouteFusionViews()
    if self.InvalidateMinimapRouteCache then
        self:InvalidateMinimapRouteCache()
    end
    if self.RefreshMapLayer then
        self:RefreshMapLayer()
    end
    if self.RefreshMinimapLayer then
        self:RefreshMinimapLayer(true)
    end
    if self.RefreshDebugPanel then
        self:RefreshDebugPanel()
    end
end

function YBP:IsRouteAutoResolveEnabled()
    return EnsureFusionDB().autoResolve and true or false
end

function YBP:SetRouteAutoResolveEnabled(enabled)
    EnsureFusionDB().autoResolve = enabled and true or false
    if enabled then
        self:ResolveAllRoutes()
    else
        self:RefreshRouteFusionViews()
    end
end

function YBP:GetRouteVisualSettings()
    return GetVisualOverrides()
end

function YBP:SetRouteVisualSetting(key, value)
    local visual = GetVisualOverrides()
    if type(value) ~= "number" then
        visual[key] = nil
    else
        visual[key] = value
    end

    if key == "footprintInfluenceArc" and self.IsRouteAutoResolveEnabled and self:IsRouteAutoResolveEnabled() then
        self:ResolveAllRoutes()
        return
    end

    self:RefreshRouteFusionViews()
end

function YBP:ResetRouteVisualSettings()
    EnsureFusionDB().visual = {}

    if self.IsRouteAutoResolveEnabled and self:IsRouteAutoResolveEnabled() then
        self:ResolveAllRoutes()
        return
    end

    self:RefreshRouteFusionViews()
end

function YBP:GetReferenceRoute(petID)
    local route = ns.referenceRoutes and ns.referenceRoutes[petID] or nil
    if route then
        local savedTransform = GetSavedReferenceDisplayTransform(petID)
        if not savedTransform then
            return route
        end

        local copy = DeepCopy(route)
        copy.referenceDisplayTransform = savedTransform
        return copy
    end

    local curated = ns.curatedRoutes and ns.curatedRoutes[petID] or nil
    if not curated then
        return nil
    end

    local fallback = {
        petID = petID,
        mapID = curated.mapID,
        color = curated.color,
        source = curated.source,
        version = "1.4.0-fallback",
        migratedFrom = "CuratedRoutes.lua",
        segments = DeepCopy(curated.segments),
    }

    local savedTransform = GetSavedReferenceDisplayTransform(petID)
    if savedTransform then
        fallback.referenceDisplayTransform = savedTransform
    end

    return fallback
end

function YBP:GetFootprintStore(petID)
    return GetActiveFootprintStore(petID)
end

function YBP:GetFootprintsForPet(petID, includeDisabled)
    local store = GetActiveFootprintStore(petID)
    local points = {}

    for _, point in ipairs(store.points or {}) do
        if includeDisabled or point.enabled ~= false then
            points[#points + 1] = point
        end
    end

    return points
end

function YBP:AddFootprintAnchor(petID, mapID, x, y, note, isKeyPoint)
    if not petID or not mapID or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    local store = GetActiveFootprintStore(petID)
    local point = {
        petID = petID,
        mapID = mapID,
        x = x,
        y = y,
        enabled = true,
        note = note,
        source = "debug-panel",
        createdAt = date("!%Y-%m-%dT%H:%M:%SZ"),
        isKeyPoint = isKeyPoint and true or false,
    }

    store.mapID = mapID
    store.points[#store.points + 1] = point

    if self:IsRouteAutoResolveEnabled() then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshRouteFusionViews()
    end

    return point
end

function YBP:RemoveLastFootprintAnchor(petID)
    local store = GetActiveFootprintStore(petID)
    if not store.points or #store.points == 0 then
        return false
    end

    table.remove(store.points, #store.points)

    if self:IsRouteAutoResolveEnabled() then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshRouteFusionViews()
    end

    return true
end

function YBP:RemoveFootprintAnchor(petID, index)
    local store = GetActiveFootprintStore(petID)
    if not store.points or not index or index < 1 or index > #store.points then
        return false
    end

    table.remove(store.points, index)

    if self:IsRouteAutoResolveEnabled() then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshRouteFusionViews()
    end

    return true
end

function YBP:ClearFootprintAnchors(petID)
    local store = GetActiveFootprintStore(petID)
    store.points = {}

    if self:IsRouteAutoResolveEnabled() then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshRouteFusionViews()
    end
end

function YBP:SetFootprintAnchorEnabled(petID, index, enabled)
    local store = GetActiveFootprintStore(petID)
    local point = store.points and store.points[index] or nil
    if not point then
        return false
    end

    point.enabled = enabled and true or false

    if self:IsRouteAutoResolveEnabled() then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshRouteFusionViews()
    end

    return true
end

local function BuildRouteIndex(route)
    local indexed = {
        points = {},
        segments = {},
        totalLength = 0,
    }

    local cumulative = 0

    for segmentIndex, segment in ipairs(route.segments or {}) do
        local segmentInfo = {
            segmentIndex = segmentIndex,
            entries = {},
        }

        for pointIndex, point in ipairs(segment.points or {}) do
            local entry = {
                segmentIndex = segmentIndex,
                pointIndex = pointIndex,
                point = point,
                x = point.x,
                y = point.y,
                distance = cumulative,
            }

            indexed.points[#indexed.points + 1] = entry
            segmentInfo.entries[#segmentInfo.entries + 1] = entry

            local nextPoint = segment.points[pointIndex + 1]
            if nextPoint then
                local dx = nextPoint.x - point.x
                local dy = nextPoint.y - point.y
                cumulative = cumulative + math.sqrt((dx * dx) + (dy * dy))
            elseif segment.loop and #segment.points > 1 then
                local firstPoint = segment.points[1]
                local dx = firstPoint.x - point.x
                local dy = firstPoint.y - point.y
                cumulative = cumulative + math.sqrt((dx * dx) + (dy * dy))
            end
        end

        indexed.segments[#indexed.segments + 1] = segmentInfo
    end

    indexed.totalLength = math.max(cumulative, 0.001)
    return indexed
end

local function FindNearestProjectionOnRoute(routeIndex, footprint)
    local best = nil

    for _, segmentInfo in ipairs(routeIndex.segments or {}) do
        local entries = segmentInfo.entries or {}
        local entryCount = #entries
        if entryCount >= 2 then
            local edgeCount = entryCount - 1

            for edgeIndex = 1, edgeCount do
                local startEntry = entries[edgeIndex]
                local endEntry = entries[edgeIndex + 1]
                local dx = endEntry.x - startEntry.x
                local dy = endEntry.y - startEntry.y
                local segmentLengthSquared = (dx * dx) + (dy * dy)
                if segmentLengthSquared > 0 then
                    local t = (((footprint.x - startEntry.x) * dx) + ((footprint.y - startEntry.y) * dy)) / segmentLengthSquared
                    t = Clamp(t, 0, 1)
                    local projectedX = Lerp(startEntry.x, endEntry.x, t)
                    local projectedY = Lerp(startEntry.y, endEntry.y, t)
                    local offsetX = footprint.x - projectedX
                    local offsetY = footprint.y - projectedY
                    local distanceSquared = (offsetX * offsetX) + (offsetY * offsetY)

                    if not best or distanceSquared < best.distanceSquared then
                        local edgeLength = math.sqrt(segmentLengthSquared)
                        best = {
                            segmentIndex = segmentInfo.segmentIndex,
                            startPointIndex = startEntry.pointIndex,
                            endPointIndex = endEntry.pointIndex,
                            projectedX = projectedX,
                            projectedY = projectedY,
                            distanceSquared = distanceSquared,
                            distance = math.sqrt(distanceSquared),
                            routeDistance = startEntry.distance + (edgeLength * t),
                        }
                    end
                end
            end

            local segment = routeIndex.route and routeIndex.route.segments and routeIndex.route.segments[segmentInfo.segmentIndex] or nil
            if segment and segment.loop and entryCount > 2 then
                local startEntry = entries[entryCount]
                local endEntry = entries[1]
                local dx = endEntry.x - startEntry.x
                local dy = endEntry.y - startEntry.y
                local segmentLengthSquared = (dx * dx) + (dy * dy)
                if segmentLengthSquared > 0 then
                    local t = (((footprint.x - startEntry.x) * dx) + ((footprint.y - startEntry.y) * dy)) / segmentLengthSquared
                    t = Clamp(t, 0, 1)
                    local projectedX = Lerp(startEntry.x, endEntry.x, t)
                    local projectedY = Lerp(startEntry.y, endEntry.y, t)
                    local offsetX = footprint.x - projectedX
                    local offsetY = footprint.y - projectedY
                    local distanceSquared = (offsetX * offsetX) + (offsetY * offsetY)

                    if not best or distanceSquared < best.distanceSquared then
                        local edgeLength = math.sqrt(segmentLengthSquared)
                        best = {
                            segmentIndex = segmentInfo.segmentIndex,
                            startPointIndex = startEntry.pointIndex,
                            endPointIndex = endEntry.pointIndex,
                            projectedX = projectedX,
                            projectedY = projectedY,
                            distanceSquared = distanceSquared,
                            distance = math.sqrt(distanceSquared),
                            routeDistance = startEntry.distance + (edgeLength * t),
                        }
                    end
                end
            end
        end
    end

    return best
end

local function CollectProjectionCandidates(routeIndex, footprint, limit)
    local candidates = {}
    limit = math.max(1, math.floor(limit or 1))

    for _, segmentInfo in ipairs(routeIndex.segments or {}) do
        local entries = segmentInfo.entries or {}
        local entryCount = #entries
        if entryCount >= 2 then
            local edgeCount = entryCount - 1

            for edgeIndex = 1, edgeCount do
                local startEntry = entries[edgeIndex]
                local endEntry = entries[edgeIndex + 1]
                local dx = endEntry.x - startEntry.x
                local dy = endEntry.y - startEntry.y
                local segmentLengthSquared = (dx * dx) + (dy * dy)
                if segmentLengthSquared > 0 then
                    local t = (((footprint.x - startEntry.x) * dx) + ((footprint.y - startEntry.y) * dy)) / segmentLengthSquared
                    t = Clamp(t, 0, 1)
                    local projectedX = Lerp(startEntry.x, endEntry.x, t)
                    local projectedY = Lerp(startEntry.y, endEntry.y, t)
                    local offsetX = footprint.x - projectedX
                    local offsetY = footprint.y - projectedY
                    local distanceSquared = (offsetX * offsetX) + (offsetY * offsetY)
                    local edgeLength = math.sqrt(segmentLengthSquared)

                    candidates[#candidates + 1] = {
                        segmentIndex = segmentInfo.segmentIndex,
                        startPointIndex = startEntry.pointIndex,
                        endPointIndex = endEntry.pointIndex,
                        projectedX = projectedX,
                        projectedY = projectedY,
                        distanceSquared = distanceSquared,
                        distance = math.sqrt(distanceSquared),
                        routeDistance = startEntry.distance + (edgeLength * t),
                    }
                end
            end

            local segment = routeIndex.route and routeIndex.route.segments and routeIndex.route.segments[segmentInfo.segmentIndex] or nil
            if segment and segment.loop and entryCount > 2 then
                local startEntry = entries[entryCount]
                local endEntry = entries[1]
                local dx = endEntry.x - startEntry.x
                local dy = endEntry.y - startEntry.y
                local segmentLengthSquared = (dx * dx) + (dy * dy)
                if segmentLengthSquared > 0 then
                    local t = (((footprint.x - startEntry.x) * dx) + ((footprint.y - startEntry.y) * dy)) / segmentLengthSquared
                    t = Clamp(t, 0, 1)
                    local projectedX = Lerp(startEntry.x, endEntry.x, t)
                    local projectedY = Lerp(startEntry.y, endEntry.y, t)
                    local offsetX = footprint.x - projectedX
                    local offsetY = footprint.y - projectedY
                    local distanceSquared = (offsetX * offsetX) + (offsetY * offsetY)
                    local edgeLength = math.sqrt(segmentLengthSquared)

                    candidates[#candidates + 1] = {
                        segmentIndex = segmentInfo.segmentIndex,
                        startPointIndex = startEntry.pointIndex,
                        endPointIndex = endEntry.pointIndex,
                        projectedX = projectedX,
                        projectedY = projectedY,
                        distanceSquared = distanceSquared,
                        distance = math.sqrt(distanceSquared),
                        routeDistance = startEntry.distance + (edgeLength * t),
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.distanceSquared == b.distanceSquared then
            return a.routeDistance < b.routeDistance
        end
        return a.distanceSquared < b.distanceSquared
    end)

    local trimmed = {}
    for index = 1, math.min(limit, #candidates) do
        trimmed[index] = candidates[index]
    end

    return trimmed
end

local function SelectSequentialFootprintAnchors(routeIndex, footprints)
    local footprintCandidates = {}
    local orderedFootprints = {}

    for _, footprint in ipairs(footprints) do
        if footprint.enabled ~= false and footprint.mapID == routeIndex.route.mapID and footprint.routeSpace then
            orderedFootprints[#orderedFootprints + 1] = footprint
            footprintCandidates[#footprintCandidates + 1] = CollectProjectionCandidates(routeIndex, footprint.routeSpace, 8)
        end
    end

    if #orderedFootprints == 0 then
        return {}
    end

    for index, candidates in ipairs(footprintCandidates) do
        if #candidates == 0 then
            local fallback = FindNearestProjectionOnRoute(routeIndex, orderedFootprints[index].routeSpace)
            if fallback then
                footprintCandidates[index] = { fallback }
            end
        end
    end

    local selected = {}
    local previousProjection = nil

    for footprintIndex, candidates in ipairs(footprintCandidates) do
        local footprint = orderedFootprints[footprintIndex]
        local chosen = nil
        local chosenScore = nil

        if footprintIndex == 1 then
            chosen = candidates[1]
        else
            local previousFootprint = orderedFootprints[footprintIndex - 1]
            local footprintStepX = footprint.routeSpace.x - previousFootprint.routeSpace.x
            local footprintStepY = footprint.routeSpace.y - previousFootprint.routeSpace.y
            local footprintStep = math.sqrt((footprintStepX * footprintStepX) + (footprintStepY * footprintStepY))
            local allowedStep = math.max(0.04, footprintStep * 3.5)
            local minimumForwardStep = -0.02

            for _, candidate in ipairs(candidates) do
                local routeStep = candidate.routeDistance - previousProjection.routeDistance
                if routeStep >= minimumForwardStep then
                    local overflow = math.max(0, routeStep - allowedStep)
                    local score = candidate.distanceSquared + (overflow * overflow * 0.25) + (math.abs(routeStep) * 0.0005)
                    if not chosen or score < chosenScore then
                        chosen = candidate
                        chosenScore = score
                    end
                end
            end

            if not chosen then
                for _, candidate in ipairs(candidates) do
                    local routeStep = candidate.routeDistance - previousProjection.routeDistance
                    local backwardPenalty = 0
                    if routeStep < minimumForwardStep then
                        backwardPenalty = (math.abs(routeStep - minimumForwardStep) ^ 2) * 4
                    end
                    local overflow = math.max(0, routeStep - allowedStep)
                    local score = candidate.distanceSquared + backwardPenalty + (overflow * overflow * 0.5)
                    if not chosen or score < chosenScore then
                        chosen = candidate
                        chosenScore = score
                    end
                end
            end
        end

        if chosen then
            selected[#selected + 1] = {
                footprint = footprint,
                projection = chosen,
            }
            previousProjection = chosen
        else
            break
        end
    end

    return selected
end

local function BuildFootprintAnchors(route, footprints)
    local routeIndex = BuildRouteIndex(route)
    routeIndex.route = route
    local anchors = {}
    local routeSpaceFootprints = {}

    for _, footprint in ipairs(footprints) do
        if footprint.enabled ~= false and footprint.mapID == route.mapID then
            local routeSpace = InvertMapPointToRouteSpace(route.petID, footprint)
            if routeSpace and routeSpace.x and routeSpace.y then
                local transformedFootprint = DeepCopy(footprint)
                transformedFootprint.routeSpace = routeSpace
                routeSpaceFootprints[#routeSpaceFootprints + 1] = transformedFootprint
            end
        end
    end

    local selectedAnchors = SelectSequentialFootprintAnchors(routeIndex, routeSpaceFootprints)
    for _, anchor in ipairs(selectedAnchors) do
        local footprint = anchor.footprint
        local projection = anchor.projection
        if footprint and projection then
            local strength = 1.0
            if footprint.isKeyPoint then
                strength = 1.5
            end

            anchors[#anchors + 1] = {
                footprint = footprint,
                routeDistance = projection.routeDistance,
                projectedX = projection.projectedX,
                projectedY = projection.projectedY,
                deltaX = footprint.routeSpace.x - projection.projectedX,
                deltaY = footprint.routeSpace.y - projection.projectedY,
                distance = projection.distance,
                strength = strength,
            }
        end
    end

    return routeIndex, anchors
end

local function ResolvePointAgainstFootprintAnchors(point, pointDistance, routeIndex, anchors)
    local candidates = {}
    local strongestWeight = 0

    for _, anchor in ipairs(anchors) do
        local arcScale = YBP.GetFootprintInfluenceArc and YBP:GetFootprintInfluenceArc() or 1.0
        local baseRadius = math.min(0.045, math.max(0.026, routeIndex.totalLength * 0.018)) * arcScale
        local influenceRadius = math.min(0.095, math.max(0.055, routeIndex.totalLength * 0.045)) * arcScale
        local routeDelta = math.abs(pointDistance - anchor.routeDistance)
        if routeDelta <= influenceRadius then
            local routeFalloff = math.exp(-((routeDelta * routeDelta) / (2 * baseRadius * baseRadius)))
            local footprintPenalty = 1 / (1 + ((anchor.distance / 0.10) * (anchor.distance / 0.10)))
            local weight = routeFalloff * footprintPenalty * anchor.strength
            candidates[#candidates + 1] = {
                anchor = anchor,
                weight = weight,
            }
            if weight > strongestWeight then
                strongestWeight = weight
            end
        end
    end

    if strongestWeight <= 0 or #candidates == 0 then
        return {
            x = point.x,
            y = point.y,
            weight = 0,
        }
    end

    local shiftX = 0
    local shiftY = 0
    local totalWeight = 0
    local threshold = strongestWeight * 0.72

    for _, candidate in ipairs(candidates) do
        if candidate.weight >= threshold then
            local normalizedWeight = candidate.weight / strongestWeight
            shiftX = shiftX + (candidate.anchor.deltaX * normalizedWeight)
            shiftY = shiftY + (candidate.anchor.deltaY * normalizedWeight)
            totalWeight = totalWeight + normalizedWeight
        end
    end

    if totalWeight <= 0 then
        return {
            x = point.x,
            y = point.y,
            weight = 0,
        }
    end

    local normalizedShiftX = shiftX / totalWeight
    local normalizedShiftY = shiftY / totalWeight
    local blend = Clamp(strongestWeight, 0, 0.85)

    return {
        x = point.x + (normalizedShiftX * blend),
        y = point.y + (normalizedShiftY * blend),
        weight = strongestWeight,
    }
end

local function BuildResolvedRouteForPet(self, petID)
    local referenceRoute = self:GetReferenceRoute(petID)
    if not referenceRoute then
        ns.resolvedRoutes[petID] = nil
        return nil
    end

    local footprints = self:GetFootprintsForPet(petID, false)
    local resolved = DeepCopy(referenceRoute)
    resolved.derivedFrom = {
        reference = "ReferenceRoutes.lua",
        footprints = #footprints,
    }
    resolved.resolvedAt = date("!%Y-%m-%dT%H:%M:%SZ")
    resolved.sectionStates = {}

    if #footprints == 0 then
        for segmentIndex = 1, #(resolved.segments or {}) do
            resolved.sectionStates[segmentIndex] = "reference"
        end
        ns.resolvedRoutes[petID] = resolved
        return resolved
    end

    local routeIndex, anchors = BuildFootprintAnchors(referenceRoute, footprints)
    if #anchors == 0 then
        for segmentIndex = 1, #(resolved.segments or {}) do
            resolved.sectionStates[segmentIndex] = "reference"
        end
        ns.resolvedRoutes[petID] = resolved
        return resolved
    end

    for segmentIndex, segment in ipairs(resolved.segments or {}) do
        local strongestWeight = 0

        for pointIndex, point in ipairs(segment.points or {}) do
            local pointEntry = routeIndex.segments
                and routeIndex.segments[segmentIndex]
                and routeIndex.segments[segmentIndex].entries
                and routeIndex.segments[segmentIndex].entries[pointIndex]
                or nil
            local adjusted = ResolvePointAgainstFootprintAnchors(
                point,
                pointEntry and pointEntry.distance or 0,
                routeIndex,
                anchors
            )
            segment.points[pointIndex].x = Clamp(adjusted.x, -0.5, 1.8)
            segment.points[pointIndex].y = Clamp(adjusted.y, -0.8, 1.8)
            if adjusted.weight > strongestWeight then
                strongestWeight = adjusted.weight
            end
        end

        if strongestWeight >= 1.0 then
            resolved.sectionStates[segmentIndex] = "footprint-led"
        elseif strongestWeight > 0 then
            resolved.sectionStates[segmentIndex] = "footprint-mixed"
        else
            resolved.sectionStates[segmentIndex] = "reference"
        end
    end

    ns.resolvedRoutes[petID] = resolved
    return resolved
end

function YBP:ResolveRouteForPet(petID, silent)
    local resolved = BuildResolvedRouteForPet(self, petID)
    if not silent then
        self:RefreshRouteFusionViews()
    end
    return resolved
end

function YBP:ResolveRoutesForMap(mapID)
    if not mapID then
        return
    end

    for petID, pet in pairs(ns.pets or {}) do
        if pet.mapID == mapID then
            self:ResolveRouteForPet(petID, true)
        end
    end

    self:RefreshRouteFusionViews()
end

function YBP:ResolveAllRoutes()
    for petID in pairs(ns.pets or {}) do
        self:ResolveRouteForPet(petID, true)
    end

    self:RefreshRouteFusionViews()
end

function YBP:GetResolvedRoute(petID)
    if not ns.resolvedRoutes[petID] then
        return BuildResolvedRouteForPet(self, petID)
    end

    return ns.resolvedRoutes[petID]
end

function YBP:GetResolvedSectionStateSummary(petID)
    local route = self:GetResolvedRoute(petID)
    local summary = {
        reference = 0,
        mixed = 0,
        footprintLed = 0,
        total = 0,
    }
    if not route or not route.sectionStates then
        return summary
    end

    for _, state in pairs(route.sectionStates) do
        summary.total = summary.total + 1
        if state == "footprint-led" then
            summary.footprintLed = summary.footprintLed + 1
        elseif state == "footprint-mixed" then
            summary.mixed = summary.mixed + 1
        else
            summary.reference = summary.reference + 1
        end
    end
    return summary
end

function YBP:GetRouteLayerColor(petID, layer)
    local defaults, perPet = GetDisplayMeta(petID)
    if layer == "reference" then
        local color = perPet.referenceColor or defaults.referenceColor or { 0.65, 0.75, 1.00, 0.35 }
        return { color[1], color[2], color[3], GetDisplayValue("referenceAlpha", color[4] or 0.35) }
    end
    if layer == "footprint" then
        local color = perPet.evidenceColor or defaults.footprintColor or { 1.00, 0.84, 0.10, 0.95 }
        return { color[1], color[2], color[3], GetDisplayValue("footprintAlpha", color[4] or 0.95) }
    end
    local color = perPet.routeColor or defaults.routeColor or { 0.15, 0.95, 0.85, 0.95 }
    return { color[1], color[2], color[3], GetDisplayValue("resolvedAlpha", color[4] or 0.95) }
end

function YBP:GetRouteLayerThickness(petID, layer)
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    if layer == "reference" then
        return GetDisplayValue("referenceThickness", defaults.referenceThickness or 2)
    end
    return GetDisplayValue("resolvedThickness", defaults.resolvedThickness or 3)
end

function YBP:GetFootprintDisplaySize()
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    return GetDisplayValue("footprintSize", defaults.footprintSize or 12)
end

function YBP:GetRouteDisplayDensity()
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    return math.max(1, math.floor(GetDisplayValue("routeDensity", defaults.routeDensity or 2) + 0.5))
end

function YBP:GetFootprintInfluenceArc()
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    return GetDisplayValue("footprintInfluenceArc", defaults.footprintInfluenceArc or 1.0)
end

function YBP:GetMinimapNearbyPointLimit()
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    return math.max(0, math.floor(GetDisplayValue("minimapNearbyPointLimit", defaults.minimapNearbyPointLimit or 6)))
end

function YBP:GetMinimapDualLaneBoost()
    local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
    return GetDisplayValue("minimapDualLaneBoost", defaults.minimapDualLaneBoost or 1.15)
end
