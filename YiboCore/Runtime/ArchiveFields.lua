local Core = _G.YiboCore
local Archive = { name = "character-archive.fields", warned = {} }
Core.ArchiveFields = Archive

local function Number(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function Warn(id)
    if Archive.warned[id] then return end
    Archive.warned[id] = true
    Core:Print(Core:Text("ARCHIVE.FIELD_CONFLICT", id))
end

function Archive:GetDefinitions(static)
    local definitions, byID, conflicts = {}, {}, {}
    for _, field in ipairs(static or {}) do byID[field.id] = false end
    for _, descriptor in ipairs(Core.Contracts:List(self.name, { major = 1, minMinor = 0 }) or {}) do
        local fields = Core.Contracts:Call(Core.NAME, descriptor, "GetFields", {})
        if type(fields) == "table" then
            local seen, valid, count = {}, true, 0
            for _, field in ipairs(fields) do
                if type(field) ~= "table" or type(field.id) ~= "string" or field.id == ""
                    or type(field.title) ~= "string" or not Number(field.order)
                    or field.formatKind ~= "money" or seen[field.id] then valid = false; break end
                seen[field.id] = true; count = count + 1
            end
            for key in pairs(fields) do if not Number(key) or key % 1 ~= 0 or key < 1 or key > #fields then valid = false end end
            if count ~= #fields then valid = false end
            if valid then
                for _, supplied in ipairs(fields) do
                    local id = supplied.id
                    if byID[id] ~= nil or conflicts[id] then
                        conflicts[id] = true; Warn(id)
                    else
                        local field = { id = id, title = supplied.title, order = supplied.order, formatKind = supplied.formatKind,
                            width = supplied.width, align = supplied.align,
                            defaultVisible = supplied.defaultVisible, defaultPreviewVisible = supplied.defaultPreviewVisible }
                        field.consumer, field.archiveProvider = "character-archive", descriptor
                        field.width = Number(field.width) and math.max(32, math.min(400, field.width)) or 80
                        field.align = field.align == "RIGHT" and "RIGHT" or "LEFT"
                        field.defaultVisible = field.defaultVisible == true
                        field.defaultPreviewVisible = field.defaultPreviewVisible == true
                        byID[id] = field
                    end
                end
            end
        end
    end
    for id, field in pairs(byID) do if field and not conflicts[id] then definitions[#definitions + 1] = field end end
    return definitions
end

function Archive:Read(characters, fields)
    local snapshot, groups, ids, seen = {}, {}, {}, {}
    for _, character in ipairs(characters or {}) do
        if type(character.id) == "string" and not seen[character.id] then ids[#ids + 1] = character.id; seen[character.id] = true end
    end
    for _, field in ipairs(fields or {}) do
        local descriptor = field.archiveProvider
        if descriptor then
            local ref = descriptor.registrationRef
            local group = groups[ref] or { descriptor = descriptor, fields = {} }; groups[ref] = group
            group.fields[#group.fields + 1] = field.id
        end
    end
    for ref, group in pairs(groups) do
        local response = Core.Contracts:Call(Core.NAME, group.descriptor, "Read", { characterIDs = ids, fieldIDs = group.fields })
        if type(response) == "table" and response.sourceID == group.descriptor.providerID and type(response.characters) == "table" then
            snapshot[ref] = response.characters
        end
    end
    return snapshot
end

function Archive:GetCell(character, field, snapshot)
    if not character then return nil, "unknown" end
    snapshot = snapshot or self:Read({ character }, { field })
    local rows = snapshot[field.archiveProvider.registrationRef]
    local row = rows and rows[character.id]
    local cell = type(row) == "table" and type(row.fields) == "table" and row.fields[field.id]
    if type(cell) ~= "table" or not Number(cell.value) or cell.value < 0
        or (cell.state ~= "known" and cell.state ~= "stale") then return nil, "unknown" end
    return cell.value, cell.state
end

function Archive:FormatValue(character, field, snapshot)
    local value, state = self:GetCell(character, field, snapshot)
    if value == nil then return "?", nil end
    local text = tostring(math.floor(value / 10000)) .. Core:Text("CORE.G")
    return text .. (state == "stale" and "~" or ""), value
end

for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
    Core.Events:Register(event, Archive, function(_, descriptor)
        if descriptor.name == Archive.name and Core.AccountView then Core.AccountView:NotifyPageChanged("characters") end
    end)
end
Core.Capabilities:Register("character-archive-providers", 1)
