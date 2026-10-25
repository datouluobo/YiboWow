local Addon = _G.YiboVault

function Addon:MarkLocationError(source, key, location, errorMessage)
    local character = self.Core and self.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then return end
    local store = self:GetCharacterStore(character.id)
    local coverage = store.coverage[source][key] or {}
    local errorCode = tostring(errorMessage or "scan-failed")
    local changed = coverage.status ~= "error" or coverage.error ~= errorCode
    coverage.status = "error"
    coverage.error = errorCode
    coverage.location = location
    coverage.observedAt = select(1, self:Now())
    if changed then coverage.revision = (tonumber(self.db.revision) or 0) + 1 end
    store.coverage[source][key] = coverage
    if changed then self:NotifyLocationStatusChanged(source, character.id, coverage.observedAt) end
end
