local Addon, Core = _G.YiboReputation, _G.YiboCore
local Migration = {}
Addon.Migration = Migration

function Migration:CheckCoreHandoff()
    local major, minor, patch = tostring(Core:GetVersion()):match("^(%d+)%.(%d+)%.(%d+)")
    local version = major and (tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)) or 0
    if version < 1012004 then return nil, Addon:T("ERROR.CORE_COLLECTOR") end
    for _, definition in ipairs(Core.DataDomains:GetDefinitions()) do
        if definition.id == "reputation" then return nil, Addon:T("ERROR.CORE_COLLECTOR") end
    end
    return true
end

function Migration:ImportCharacter(id)
    local store, character = Addon.Store, Core.Characters:Get(id, { identityOnly=true })
    if not store.db or not character then return false end
    local db, now = store.db, store.Now()
    local migration = db.migrations.coreReputationV1
    if migration.blocked[id] or Core.CharacterCleanup:IsLegacyImportBlocked(Addon.NAME, nil, id, character) then
        migration.blocked[id] = true
        return false
    end
    local previous = migration.characters[id]
    if db.characters[id] and not store:IsEmptyPlaceholder(db.characters[id]) then
        if previous and previous.status == "failed" then
            migration.characters[id] = { status="existing", resolvedAt=now, previousFailure=previous.reason }
        else migration.characters[id] = previous or { status="existing", importedAt=now } end
        return false
    end
    local ok, source = pcall(Core.DataDomains.Get, Core.DataDomains, id, "reputation")
    if not ok then migration.characters[id] = { status="failed", reason=tostring(source) }; return nil end
    if not source then return false end
    local valid, reason = store:Validate(source)
    if not valid then migration.characters[id] = { status="failed", reason=reason }; return nil end
    local snapshot = store.Copy(source)
    if snapshot.schemaVersion < 5 or not snapshot.updatedAt then snapshot.state = "not-yet-scanned" end
    snapshot.revision = 1
    db.characters[id] = { snapshot=snapshot, origin={ kind="core-import", importedAt=now }, identityAliases=Core.Characters:GetAliases(id) }
    migration.characters[id] = { status="imported", importedAt=now, sourceSchema=source.schemaVersion,
        sourceRevision=source.revision, sourceUpdatedAt=source.updatedAt }
    Addon:InitializeFactionRegistry()
    store:Changed(id, "legacy-import")
    return true
end

function Addon:ImportLegacySnapshots()
    local ok, err = self.Migration:CheckCoreHandoff()
    if not ok then return nil, err end
    local imported, failed = 0, 0
    for _, character in ipairs(Core.Characters:GetAll({ identityOnly=true })) do
        local result = self.Migration:ImportCharacter(character.id)
        if result then imported = imported + 1 elseif result == nil then failed = failed + 1 end
    end
    if failed > 0 then self:Print(self:T("ERROR.MIGRATION_FAILED", failed)) end
    return imported, failed
end
