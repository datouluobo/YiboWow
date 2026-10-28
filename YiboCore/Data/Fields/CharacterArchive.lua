local Core = _G.YiboCore

local function Profile(character) return character and character.profile or {} end
local function Profession(character, data, slot, skillLine, state)
    local profile = data or Profile(character)
    if state ~= "known" and (not data or (data.professions == nil and data.primaryProfessions == nil)) then
        profile = Profile(character)
    end
    if slot then
        if profile.primaryProfessions then return profile.primaryProfessions[slot] end
        if profile.skillLineIDsAuthoritative then return nil end
        local hasSlots = false
        for _, item in ipairs(profile.professions or {}) do
            if item.slot ~= nil then
                hasSlots = true
                if tonumber(item.slot) == slot then return item end
            end
        end
        if hasSlots then return nil end
        return profile.professions and profile.professions[slot]
    end
    for _, item in ipairs(profile.professions or {}) do
        if item.id == skillLine or (not profile.skillLineIDsAuthoritative and (Core._private.professionSlotIDs or {})[tonumber(item.slot)] == skillLine) then return item end
    end
end
local function ProfessionValue(slot, skillLine)
    return function(character, data, state) return Profession(character, data, slot, skillLine, state) end
end
local function ProfessionFormat(value) return value and tostring(value.skillLevel or "?") or "—" end
local function ProfessionIcon(value) return value and value.icon end

local function Register(definition)
    -- Target manifests load only the domains whose collection is implemented.
    local policy = Core._private.archiveFields or {}
    if not policy[definition.id] or not Core.DataDomains._definitions[definition.domain] then return end
    definition.title = Core:Text(definition.titleKey)
    local entry = assert(Core.Fields:Register("YiboCore", definition))
    Core.Locale:BindText(entry, "title", definition.titleKey)
end

Register({ id = "character.identity", consumer = "character-archive", domain = "identity", titleKey = "CORE.CHARACTER", order = 10, width = 210, maxWidth = 260, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character) return character end, Format = function(value) return value and Core.Characters:FormatName({ name = tostring(value.name or Core:Text("CORE.UNKNOWN_CHARACTER")), realm = tostring(value.realm or Core:Text("CORE.UNKNOWN_REALM")) }, { realmMode = "full" }) or "—" end,
    GetColor = function(_, character) local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]; return color and { color.r, color.g, color.b } end })
Register({ id = "character.level", consumer = "character-archive", domain = "identity", titleKey = "CORE.LEVEL", order = 20, width = 42, gapAfter = 12, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character) return character and character.level end })
Register({ id = "character.item-level", consumer = "character-archive", domain = "equipment", titleKey = "CORE.ITEM_LEVEL", order = 30, width = 50, gapAfter = 12, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character, data) return data and data.itemLevel or Profile(character).itemLevel end, Format = function(value) return value and string.format("%.0f", value) or "—" end })
Register({ id = "character.zone", consumer = "character-archive", domain = "location", titleKey = "CORE.LOCATION", order = 40, width = 110, maxWidth = 140, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character, data) return data and data.zone or Profile(character).zone end, Format = function(value) return value or Core:Text("CORE.UNKNOWN_LOCATION") end })
Register({ id = "character.profession-primary", consumer = "character-archive", domain = "professions", titleKey = "CORE.PRIMARY_PROFESSION", order = 50, width = 92, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(1), Format = ProfessionFormat, GetIcon = ProfessionIcon })
Register({ id = "character.profession-secondary", consumer = "character-archive", domain = "professions", titleKey = "CORE.SECOND_PROFESSION", order = 60, width = 92, gapAfter = 4, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(2), Format = ProfessionFormat, GetIcon = ProfessionIcon })
Register({ id = "character.archaeology", consumer = "character-archive", domain = "professions", titleKey = "CORE.ARCHAEOLOGY", order = 70, width = 54, defaultVisible = false, defaultPreviewVisible = false, Read = ProfessionValue(nil, 794), Format = ProfessionFormat })
Register({ id = "character.fishing", consumer = "character-archive", domain = "professions", titleKey = "CORE.FISHING", order = 80, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 356), Format = ProfessionFormat })
Register({ id = "character.cooking", consumer = "character-archive", domain = "professions", titleKey = "CORE.COOKING", order = 90, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 185), Format = ProfessionFormat })
Register({ id = "character.first-aid", consumer = "character-archive", domain = "professions", titleKey = "CORE.FIRST_AID", order = 100, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 129), Format = ProfessionFormat })
