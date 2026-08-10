local ns = select(2, ...)

ns.routeDisplayMeta = {
    defaults = {
        resolvedThickness = 3,
        referenceThickness = 2.4,
        routeDensity = 2,
        footprintSize = 12,
        footprintAlpha = 0.95,
        footprintInfluenceArc = 1.0,
        referenceAlpha = 0.52,
        resolvedAlpha = 0.95,
        minimapNearbyPointLimit = 6,
        minimapDualLaneBoost = 1.15,
        footprintColor = { 1.00, 0.84, 0.10, 0.95 },
        referenceColor = { 0.78, 0.86, 1.00, 0.52 },
    },
    perPet = {},
}

for petID, route in pairs(ns.referenceRoutes or {}) do
    ns.routeDisplayMeta.perPet[petID] = {
        routeColor = route.color,
        evidenceColor = { 1.00, 0.84, 0.10, 0.95 },
    }
end
