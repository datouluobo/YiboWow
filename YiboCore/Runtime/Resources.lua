local Core = _G.YiboCore

-- Stable, value-free descriptions of Core-neutral facts. Character values stay
-- exclusively in DomainStore snapshots.
local Resources = {}
Core.Resources = Resources
Resources._definitions = Resources._definitions or {}

function Resources:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, Core:Text("CORE.RESOURCES_MUST_DECLARE_OWNER") end
    if type(definition) ~= "table" then return nil, Core:Text("CORE.RESOURCE_DEFINITION_CANNOT_BE_EMPTY") end
    if type(definition.id) ~= "string" or definition.id == "" then return nil, Core:Text("CORE.RESOURCES_REQUIRE_ID") end
    if type(definition.domain) ~= "string" or not Core.DataDomains._definitions[definition.domain] then return nil, Core:Text("CORE.RESOURCES_MUST_REFERENCE_A_REGISTERED_DOMAIN") end
    if type(definition.Read) ~= "function" then return nil, Core:Text("CORE.RESOURCES_REQUIRE_A_READ_CALLBACK") end
    if self._definitions[definition.id] then return nil, Core:Text("CORE.RESOURCE_ID_IS_ALREADY_OWNED_BY") .. self._definitions[definition.id].owner .. Core:Text("CORE.PUNCTUATION_79") .. definition.id end
    local claimed, errorMessage = Core.Registry:ClaimResource("resource", definition.id, owner, { domain = definition.domain, kind = definition.kind })
    if not claimed then return nil, errorMessage end
    local entry = { id = definition.id, owner = owner, domain = definition.domain, kind = definition.kind, title = definition.title, icon = definition.icon, Read = definition.Read, Format = definition.Format }
    self._definitions[entry.id] = entry
    return entry
end

function Resources:Get(id) return self._definitions[id] end
function Resources:GetAll()
    local result = {}
    for _, item in pairs(self._definitions) do result[#result + 1] = item end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

Core.Capabilities:Register("resources", 1)
