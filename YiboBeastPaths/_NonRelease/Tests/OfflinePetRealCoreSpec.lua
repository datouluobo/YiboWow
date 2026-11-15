local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
for _, target in ipairs({ "Retail", "Mists" }) do
    local env, core, fire, flush = Boot(target)
    local createFrame = env.CreateFrame
    env.CreateFrame = function(kind, ...)
        local frame = createFrame(kind, ...)
        if kind == "PlayerModel" then
            function frame:SetDisplayInfo(id) self.displayID = id; self.displayWrites = (self.displayWrites or 0) + 1 end
            function frame:ClearModel() self.displayID = nil end
            function frame:SetCamera(value) self.camera = value end
            function frame:SetPortraitZoom(value) self.zoom = value end
            function frame:SetCamDistanceScale(value) self.distance = value end
            function frame:RefreshCamera() self.cameraRefreshes = (self.cameraRefreshes or 0) + 1 end
        end
        return frame
    end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    assert(core:IsInitialized())
    assert(core:RegisterAddon("YiboBeastPaths", { requiredAPI = 13, version = "1.9.0" }))
    local ns = { YBP_TARGET_OK = true, pets = { [10] = { mapID = 371 } },
        routeNodeTooltips = { [10] = { npcID = 50998 } } }
    env.C_Map = { GetMapInfo = function(id) if id == 371 then return { name = "Test map" } end end }
    for _, name in ipairs({ "OfflinePetSnapshot", "OfflinePetCoreGate", "OfflinePetPage", "OfflinePetRenderer" }) do
        local chunk = assert(loadfile("YiboBeastPaths/Common/" .. name .. ".lua"))
        setfenv(chunk, env); chunk("YiboBeastPaths", ns)
    end
    assert(ns.CheckOfflinePetCore(core))
    local root = { offlinePets = { schema = 1, target = target, characters = {
        ["fixture"] = { active = { capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture", items = { { slotID = 1, name = "Pet", family = "Wolf", displayID = 123, creatureID = 50998 } } },
            stable = { capturedAt = 100, completeness = "complete", coverage = "synthetic", sourceBuild = "fixture", items = { { slotID = 6, name = "Stable pet", family = "Cat", icon = 456 } } },
            lastAttempt = { status = "unverified", at = 200 } },
    } } }
    local text = function(key, ...) if select("#", ...) > 0 then return key .. " " .. tostring((...)) end; return key end
    local invalidations = 0
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
    assert(parent.cards and #parent.cards >= 2)
    assert(parent.headers[1].text:match("OFFLINE_GROUP") and not parent.headers[1].text:match("UNVERIFIED"))
    assert(parent.cards[1].entry.pet.name == "Pet" and parent.cards[2].entry.pet.name == "Stable pet")
    assert(parent.cards[1].model.displayID == 123 and parent.cards[1].model:IsShown())
    assert(parent.cards[1].model.camera == 0 and parent.cards[1].model.zoom == 0 and parent.cards[1].model.distance == 1.5)
    parent.cards[1].model:Fire("OnModelLoaded")
    assert(parent.cards[1].model.cameraRefreshes == 2)
    local modelWrites = parent.cards[1].model.displayWrites
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.cards[1].model.displayWrites == modelWrites, "unchanged models must not reload")
    assert(not parent.cards[2].model:IsShown() and parent.cards[2].unknown:IsShown())
    assert(parent.cards[2].icon:IsShown() and not parent.cards[1].icon:IsShown())
    assert(parent.detail.info.text:find("STABLE_SOURCE_MAP_CATALOG Test map", 1, true))
    ns.routeNodeTooltips[11], ns.pets[11] = { npcID = 50998 }, { mapID = 999 }
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(not parent.detail.info.text:find("STABLE_SOURCE_MAP_CATALOG", 1, true), "ambiguous catalog maps must remain unknown")
    ns.routeNodeTooltips[11], ns.pets[11] = nil, nil
    parent.cards[2]:Fire("OnClick")
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.detail.info.text:find("Stable pet", 1, true))
    assert(parent.detail.info.text:find("STABLE_SOURCE_MAP", 1, true))
    parent.familySelect.onValueChanged("Wolf")
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.cards[1].entry.pet.name == "Pet" and not parent.cards[2]:IsShown())
    parent.familySelect.onValueChanged("")
    parent.search:InputText("Stable")
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.cards[1].entry.pet.name == "Stable pet" and not parent.cards[2]:IsShown())
    assert(not parent.cards[1].model:IsShown() and parent.cards[1].model.displayID == nil and parent.cards[1].unknown:IsShown())
    parent.search:InputText("")
    local originalItems = root.offlinePets.characters.fixture.stable.items
    local many = {}
    for i = 1, 65 do many[i] = { slotID = i + 5, name = "Pet " .. i, family = "Cat", displayID = 100 + i } end
    root.offlinePets.characters.fixture.stable.items = many
    parent.scroll:SetHeight(300)
    definition.Refresh(parent, { characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(#parent.cards < 30, "visible model pool must stay bounded")
    parent.scroll:SetVerticalScroll(1800)
    assert(parent.cards[1].entry.pet.slotID > 6, "scroll must rebind pooled cards")
    parent.scroll:SetVerticalScroll(0)
    local pooled = #parent.cards
    for i = 1, 3 do
        parent.scroll:SetVerticalScroll(1800)
        parent.scroll:SetVerticalScroll(0)
    end
    assert(#parent.cards == pooled, "scrolling must reuse model controls")
    root.offlinePets.characters.fixture.stable.items = originalItems
    assert(not parent.maintenanceView and not parent.businessTabs)
    local preview = env.CreateFrame("Frame")
    definition.Create(preview, { preview = true })
    definition.Refresh(preview, { preview = true, characters = { { id = "fixture", class = "HUNTER", name = "Hunter", realm = "Realm" } } })
    assert(parent.headers[1].text:find(preview.lines[2].text, 1, true) == 1 and not preview.businessTabs)
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
    definition.Refresh(parent, { characters = pair })
    assert(#parent.characterSelect.options == 2)
    parent.characterSelect.onValueChanged("other")
    definition.Refresh(parent, { characters = pair })
    local otherVisible = false
    for _, card in ipairs(parent.cards) do
        if card.entry and card.entry.pet.name == "Other pet" then otherVisible = true end
    end
    assert(otherVisible)
    root.offlinePets.characters.other = nil
    local originalStore = root.offlinePets
    root.offlinePets = "unknown future store"
    assert(page:Start())
    definition.Refresh(parent, { characters = {} })
    assert(parent.headers[1].text == "OFFLINE_STORE_INVALID")
    assert(root.offlinePets == "unknown future store")
    root.offlinePets = originalStore
    assert(definition.GetPreviewFields().pets == true)
    assert(definition.SetPreviewFieldVisible("pets", false))
    assert(root.settings.previewColumns.pets == false and not definition.GetPreviewFields().pets)
    local cleanup = core.CharacterCleanup:GetOwners().YiboBeastPaths
    assert(cleanup.Delete({ id = "fixture" }, {}, { replay = true, deletedAt = 50 }))
    assert(invalidations == 1 and root.offlinePets.characters.fixture.stable ~= nil)
end
print("OfflinePetRealCoreSpec: Retail and Mists registration and synthetic page rendering passed")
