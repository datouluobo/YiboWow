local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Count(values) local n = 0; for _ in pairs(values) do n = n + 1 end; return n end
for _, forever in ipairs({ false, true }) do
    local e, c, fire, flush, load = Boot(forever)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    Check(c:IsInitialized(), "target starts")
    local target = c._private.target
    local policies = target.addons
    load("YiboCore/" .. target.id .. "/Metadata.lua")
    Check(target.addons == policies, "metadata repeated load retains identity")
    Check(not pcall(load, "YiboCore/" .. (forever and "Mists" or "Forever") .. "/Metadata.lua"), "other metadata target rejected")
    for _, language in ipairs({ "zh", "en" }) do
        c.Locale.previewLanguage = language; c.Locale:RefreshBindings()
        Check(#c.AddonCatalog == (forever and 6 or 14), "catalog target selection")
        Check(Count(c.CharacterCleanup.EXPECTED_OWNERS) == (forever and 6 or 10), "all implemented cleanup owners, no unrelated target owners")
        local prior, beast = "", nil
        for _, addon in ipairs(c.AddonCatalog) do
            Check(prior < addon.name and policies[addon.name] ~= nil, "catalog technical-name order and explicit policy")
            prior = addon.name
            if forever then Check(addon.description == c:Text(policies[addon.name].descriptionKey), "Forever descriptions limited to implemented scope") end
            if addon.name == "YiboBeastPaths" then beast = addon end
        end
        Check(forever and beast == nil or not forever and beast and beast.supportedTargets.Retail and beast.description == c:Text("CORE.BEAST_PATHS_ROUTES"), "YBP existing route declaration, no offline-stable claim")
        -- A changed session language rebuilds frames after reload in the client.
        local help = e.CreateFrame("Frame", nil, e.UIParent)
        c.AccountView._pages.help.Create(help)
        Check(#help.cards == (forever and 7 or 15), "help target selection includes Core")
        prior = ""
        for index, card in ipairs(help.cards) do
            if index > 1 then
                Check(prior < card.addonName and policies[card.addonName] ~= nil, "help sorted by technical name")
                Check(card.description:GetText() == c:Text(policies[card.addonName].operation[2]), "target help rendered through locale")
                prior = card.addonName
            end
        end
        Check(#help.notes == (forever and 1 or 4), "no unsupported usage notes")
        for name, policy in pairs(policies) do
            if policy.cleanupKey then Check(c.CharacterCleanup.EXPECTED_OWNERS[name] == c:Text(policy.cleanupKey), "cleanup labels share metadata") end
            local keys = { policy.operation[1], policy.operation[2] }
            if policy.cleanupKey then keys[#keys + 1] = policy.cleanupKey end
            if policy.descriptionKey then keys[#keys + 1] = policy.descriptionKey end
            for _, key in ipairs(policy.note or {}) do keys[#keys + 1] = key end
            for _, key in ipairs(keys) do Check(type(c.Locale.resources.YiboCore[language][key]) == "string", "all target resource IDs have real session-language text") end
        end
        c.AccountView:ShowPage("about"); flush()
        Check(#c.AccountView.frame.instances.about.addonRows == #c.AddonCatalog, "about consumes filtered catalog")
    end
    local db, cleanup = c.Database:GetDB(), c.CharacterCleanup
    db.characterDataOwners = { DisabledOwner = true }
    db.characterDeletionHistory = {
        old = { id = "old", characterID = "Old", character = { id = "Old" }, aliases = {}, deletedAt = 1,
            acknowledgedOwners = { AcknowledgedOnly = true }, failures = { FailedOnly = "old failure" } },
        required = { id = "required", characterID = "Required", character = { id = "Required" }, aliases = {}, deletedAt = 2,
            requiredOwners = { RequiredOnly = true }, acknowledgedOwners = {}, failures = {} },
    }
    db.characters.byID.Other = { id = "Other", name = "Other", realm = "Elsewhere" }
    c.Characters:InvalidateAllCache()
    local impact = cleanup:GetImpact("Other")
    for _, name in ipairs({ "DisabledOwner", "AcknowledgedOnly", "FailedOnly", "RequiredOnly" }) do
        Check(impact.owners[name] and impact.owners[name].hasData == nil, "saved and historical owners survive target filtering: " .. name)
    end
    if forever then Check(impact.owners.YiboLegendary == nil, "unrelated Mists owner not invented on Forever") end
    local calls, failed = {}, true
    c:RegisterAddon("FailedOnly", { requiredAPI = 13 })
    Check(cleanup:RegisterOwner("FailedOnly", {
        Inspect = function() return { hasData = true, label = "FailedOnly" } end,
        Delete = function(character, _, context)
            calls[#calls + 1] = context
            character.id = "consumer-mutated"
            if failed then return nil, "temporary" end
            return true
        end,
    }), "late owner registers")
    Check(#calls == 2 and db.characterDeletionHistory.old.failures.FailedOnly == "temporary", "failed replay kept")
    failed = false
    local processed, failures = cleanup:RetryPending("FailedOnly")
    Check(processed == 2 and failures == 0 and #calls == 4, "explicit replay succeeds")
    Check(db.characterDeletionHistory.old.character.id == "Old" and calls[4].replay, "owner receives detached replay snapshot")
    Check(cleanup:RetryPending("FailedOnly") == 0 and #calls == 4, "acknowledged replay not repeated")
    Check(cleanup:RegisterOwner("FailedOnly", cleanup._owners.FailedOnly) == nil, "owner duplicate remains rejected")
    cleanup.MAX_HISTORY = 1
    local result = cleanup:Delete("Other")
    Check(result and not result.complete, "disabled owners remain pending")
    local tombstone = db.characterDeletionHistory[result.deletionID]
    Check(tombstone.requiredOwners.RequiredOnly and tombstone.requiredOwners.DisabledOwner, "new history records complete owner scope")
    Check(Count(db.characterDeletionHistory) == 3, "soft history cap never prunes pending owners")
    Check(cleanup:IsLegacyImportBlocked("RequiredOnly", nil, "Other"), "deleted character cannot return via late legacy import")
    local ownerDefinition = { Inspect = function() return { hasData = false } end, Delete = function() return true end }
    local names = {}; for name in pairs(tombstone.requiredOwners) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        if name ~= "FailedOnly" then c:RegisterAddon(name, { requiredAPI = 13 }); Check(cleanup:RegisterOwner(name, ownerDefinition), "missing owner late replay") end
    end
    db.characters.byID.Last = { id = "Last", name = "Last", realm = "Elsewhere" }; c.Characters:InvalidateAllCache()
    Check(cleanup:Delete("Last").complete and Count(db.characterDeletionHistory) == 1, "fully acknowledged histories may be pruned")
    local saved = c.Defaults:Copy(db); saved.characterDeletionHistory = { malformed = { requiredOwners = "bad" } }
    Check(not c._private.ValidateStore(saved), "malformed new optional history field fails preflight")
    c._private.target = nil; c.Locale:RefreshBindings()
    Check(#c.AddonCatalog == 0 and Count(cleanup.EXPECTED_OWNERS) == 0, "missing target never defaults to Mists")
    c._private.target = { id = "Retail" }; c.Locale:RefreshBindings()
    Check(#c.AddonCatalog == 0 and Count(cleanup.EXPECTED_OWNERS) == 0, "route metadata does not create a Retail Core directory")
    c._private.target = target
end
print("CoreMetadataContractsR1 MetadataSpec passed: " .. checks .. " checks (target catalog/help, owner replay and retained history)")
