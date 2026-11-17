local _, ns = ...
local Snapshot = ns.OfflinePetSnapshot
local Page = {}
ns.OfflinePetPage = Page

-- The context supplied by Core already contains its hidden/realm/level filters.
-- Never add characters back or return references to the business database.
function Page.Eligible(root, target, characters)
    if not Snapshot.CheckStore(root, target) then return {} end
    local records = root.offlinePets and root.offlinePets.characters or {}
    local eligible = {}
    for _, character in ipairs(characters or {}) do
        local record = records[character.id]
        if character.class == "HUNTER" and type(record) == "table"
            and type(record.stable) == "table" and type(record.stable.capturedAt) == "number"
            and type(record.stable.items) == "table" then
            eligible[#eligible + 1] = character
        end
    end
    return eligible
end

function Page.Project(root, target, characters, formatName)
    local out = {}
    for _, character in ipairs(Page.Eligible(root, target, characters)) do
        local record = root.offlinePets.characters[character.id]
        out[#out + 1] = { id = character.id, name = formatName(character),
            active = Snapshot.Copy(record.active), stable = Snapshot.Copy(record.stable) }
    end
    return out
end

-- Registration state belongs to one owner/session. The runtime caller supplies
-- the already registered YBP owner and a renderer; no second settings owner.
function Page.New(core, root, target, renderer, text)
    local self = { active = false, cleanupRegistered = false, pageRegistered = false, entryRegistered = false }
    local owner, pageID = "YiboBeastPaths", "yibo-beastpaths-offline-pets"
    local function admitted(character)
        return #Page.Eligible(root, target, { character }) == 1
    end
    function self:Start()
        local ready, reason = ns.CheckOfflinePetCore(core)
        if not ready then return false, reason end
        local valid, invalidReason = Snapshot.CheckStore(root, target)
        if not valid then return false, invalidReason end
        if not self.cleanupRegistered then
            local registered, err = core.CharacterCleanup:RegisterOwner(owner, {
                Inspect = function(character)
                    local current = root.offlinePets and root.offlinePets.characters[character.id]
                    return { hasData = current ~= nil, label = text("OFFLINE_TITLE") }
                end,
                Delete = function(character, _, context)
                    return Snapshot.Delete(root, target, character.id, context)
                end,
            })
            if not registered then return false, err end
            self.cleanupRegistered = true
        end
        if not self.pageRegistered then
            local page, err = core.AccountView:RegisterPage(owner, {
                id = pageID, title = text("OFFLINE_TITLE"), defaultEnabled = true,
                previewEnabled = true, scope = { mode = "realms" },
                HasCharacterSnapshot = admitted,
                GetEligibleCharacters = function(characters) return Page.Eligible(root, target, characters) end,
                fields = { { id = "pets", title = text("OFFLINE_TITLE"),
                    defaultVisible = true, defaultPreviewVisible = true } },
                Create = renderer.Create,
                Refresh = function(parent, context)
                    local rows = Page.Project(root, target, context.characters, function(character)
                        return core.Characters:FormatName(character)
                    end)
                    renderer.Refresh(parent, context, rows)
                end,
                GetSurfaceMetrics = renderer.GetSurfaceMetrics,
            })
            if not page then return false, err end
            self.pageRegistered = true
        end
        if not self.entryRegistered then
            local entry, err = core.Entry:RegisterBusinessEntry(owner, {
                id = "ybp-offline-pets", pageID = pageID, text = text("OFFLINE_TITLE"),
                defaultChannels = { minimap = false, broker = false, builtinBar = false },
            })
            if not entry then return false, err end
            self.entryRegistered = true
        end
        self.active = true
        return true
    end
    return self
end
