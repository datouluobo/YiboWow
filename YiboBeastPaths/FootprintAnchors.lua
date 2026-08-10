local ns = select(2, ...)

ns.footprintAnchors = ns.footprintAnchors or {}

for petID in pairs(ns.pets or {}) do
    if ns.footprintAnchors[petID] == nil then
        ns.footprintAnchors[petID] = {
            petID = petID,
            points = {},
        }
    end
end
