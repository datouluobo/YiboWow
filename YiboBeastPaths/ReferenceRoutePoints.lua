local ns = select(2, ...)
if not ns.YBP_TARGET_OK then return end

ns.referenceRoutePoints = ns.referenceRoutePoints or {}
