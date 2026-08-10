local addonName, ns = ...

local DELETE = {}
ns.DELETE_OVERRIDE = ns.DELETE_OVERRIDE or DELETE

local function ApplyTableOverrides(target, overrides)
    if type(target) ~= "table" or type(overrides) ~= "table" then
        return
    end

    for key, value in pairs(overrides) do
        if value == ns.DELETE_OVERRIDE then
            target[key] = nil
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyTableOverrides(target[key], value)
        elseif type(value) == "table" then
            target[key] = {}
            ApplyTableOverrides(target[key], value)
        else
            target[key] = value
        end
    end
end

local overrideTargets = {
    pets = ns.pets,
    referenceRoutes = ns.referenceRoutes,
    resolvedRoutes = ns.resolvedRoutes,
    referenceRoutePoints = ns.referenceRoutePoints,
    referenceRouteSources = ns.referenceRouteSources,
    routeDisplayMeta = ns.routeDisplayMeta,
    routeOverlays = ns.routeOverlays,
    routeNodes = ns.routeNodes,
    routeNodeTooltips = ns.routeNodeTooltips,
    routeNodeStyles = ns.routeNodeStyles,
    mapCanvasBounds = ns.mapCanvasBounds,
    routeTransforms = ns.routeTransforms,
    minimapTransforms = ns.minimapTransforms,
    footprintAnchors = ns.footprintAnchors,
}

function ns.ApplyFlavorOverrides(overrides)
    if type(overrides) ~= "table" then
        return
    end

    for name, values in pairs(overrides) do
        ApplyTableOverrides(overrideTargets[name], values)
    end
end

ns.flavorOverrides = ns.flavorOverrides or {
    retail = {},
    mists = {},
}

ns.ApplyFlavorOverrides(ns.flavorOverrides[ns.FLAVOR])
