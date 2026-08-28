local Core = _G.YiboCore

-- Stable, value-free descriptions of Core-neutral facts. Character values stay
-- exclusively in DomainStore snapshots.
local Resources = {}
Core.Resources = Resources
Resources._definitions = Resources._definitions or {}

function Resources:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, "资源必须声明 owner。" end
    if type(definition) ~= "table" then return nil, "资源定义不能为空。" end
    if type(definition.id) ~= "string" or definition.id == "" then return nil, "资源必须提供 id。" end
    if type(definition.domain) ~= "string" or not Core.DataDomains._definitions[definition.domain] then return nil, "资源必须引用已注册领域。" end
    if type(definition.Read) ~= "function" then return nil, "资源必须提供 Read 回调。" end
    if self._definitions[definition.id] then return nil, "资源 ID 已被 " .. self._definitions[definition.id].owner .. " 占用: " .. definition.id end
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
