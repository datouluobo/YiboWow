local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
for _, target in ipairs({ "Retail", "Mists" }) do
    local env, core, fire, flush = Boot(target)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    assert(core:IsInitialized())
    assert(core:RegisterAddon("YiboBeastPaths", { requiredAPI = 13, version = "1.9.0" }))
    local ns = { YBP_TARGET_OK = true }
    for _, name in ipairs({ "OfflinePetSnapshot", "OfflinePetCoreGate", "OfflinePetPage", "OfflinePetRenderer" }) do
        local chunk = assert(loadfile("YiboBeastPaths/Common/" .. name .. ".lua"))
        setfenv(chunk, env); chunk("YiboBeastPaths", ns)
    end
    assert(ns.CheckOfflinePetCore(core))
    local root = { offlinePets = { schema = 1, target = target, characters = {
        ["fixture"] = { active = { capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture", items = { { slotID = 1, name = "Pet" } } },
            stable = { capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture", items = { { slotID = 6, name = "Stable pet" } } },
            lastAttempt = { status = "unverified", at = 200 } },
    } } }
    local text = function(key, ...) if select("#", ...) > 0 then return key .. " " .. tostring((...)) end; return key end
    local invalidations = 0
    local maintenanceRefreshes = 0
    ns.CreateMaintenancePage = function(parent) parent.maintenanceCreated = true end
    ns.RefreshMaintenancePage = function() maintenanceRefreshes = maintenanceRefreshes + 1 end
    ns.CreateMaintenanceSettingsPanel = function() return 1 end
    local page = ns.OfflinePetPage.New(core, root, target, ns.CreateOfflinePetRenderer(core, text), text,
        function() invalidations = invalidations + 1 end)
    assert(page:Start()); assert(page:Start())
    assert(core.CharacterCleanup:GetOwners().YiboBeastPaths)
    local definition = core.AccountView._pages["yibo-beastpaths-offline-pets"]
    assert(definition)
    assert(definition.settings and definition.settings.CreateSettingsPanel == ns.CreateMaintenanceSettingsPanel)
    local parent = env.CreateFrame("Frame")
    definition.Create(parent, { preview = false })
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.stableView.lines and #parent.stableView.lines >= 4)
    assert(parent.stableView.lines[2].text:match("OFFLINE_ATTEMPT_UNVERIFIED"))
    assert(parent.maintenanceView.maintenanceCreated)
    page:SelectTab("maintenance")
    definition.Refresh(parent, { characters = {} })
    assert(maintenanceRefreshes == 1)
    local preview = env.CreateFrame("Frame")
    definition.Create(preview, { preview = true })
    definition.Refresh(preview, { preview = true, characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(preview.lines[2].text == parent.stableView.lines[2].text and not preview.businessTabs)
    local previewCount, previewDetail = false, false
    for _, line in ipairs(preview.lines) do
        if line.text and line.text:find("OFFLINE_PET_COUNT", 1, true) then previewCount = true end
        if line.text and line.text:find("OFFLINE_PET_DETAIL", 1, true) then previewDetail = true end
    end
    assert(previewCount and not previewDetail)
    assert(root.offlinePets.characters.fixture.stable.items[1].name == "Stable pet")
    root.offlinePets.characters.other = ns.OfflinePetSnapshot.Copy(root.offlinePets.characters.fixture)
    root.offlinePets.characters.other.stable.items[1].name = "Other pet"
    local pair = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" },
        { id = "other", class = "HUNTER", name = "Other", realm = "Realm" } }
    page:SelectTab("stable")
    definition.Refresh(parent, { characters = pair })
    assert(#parent.stableView.characterSelect.options == 2)
    parent.stableView.characterSelect.onValueChanged("other")
    definition.Refresh(parent, { characters = pair })
    local otherVisible = false
    for _, line in ipairs(parent.stableView.lines) do
        if line.text and line.text:find("Other pet", 1, true) then otherVisible = true end
    end
    assert(otherVisible)
    root.offlinePets.characters.other = nil
    local originalStore = root.offlinePets
    root.offlinePets = "unknown future store"
    assert(page:Start())
    page:SelectTab("stable")
    definition.Refresh(parent, { characters = {} })
    assert(parent.stableView.lines[1].text == "OFFLINE_STORE_INVALID")
    page:SelectTab("maintenance")
    definition.Refresh(parent, { characters = {} })
    assert(maintenanceRefreshes == 2 and root.offlinePets == "unknown future store")
    root.offlinePets = originalStore
    assert(definition.GetPreviewFields().pets == true)
    assert(definition.SetPreviewFieldVisible("pets", false))
    assert(root.settings.previewColumns.pets == false and not definition.GetPreviewFields().pets)
    local cleanup = core.CharacterCleanup:GetOwners().YiboBeastPaths
    assert(cleanup.Delete({ id = "fixture" }, {}, { replay = true, deletedAt = 50 }))
    assert(invalidations == 1 and root.offlinePets.characters.fixture.stable ~= nil)
end
print("OfflinePetRealCoreSpec: Retail and Mists registration and synthetic page rendering passed")
