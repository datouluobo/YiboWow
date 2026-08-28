local Core = _G.YiboCore

local Fields = {}
Core.Fields = Fields
Fields._definitions = Fields._definitions or {}

local function Copy(value) return Core.Defaults:Copy(value) end

function Fields:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, "字段必须声明 owner。" end
    if type(definition) ~= "table" then return nil, "字段定义不能为空。" end
    if type(definition.id) ~= "string" or definition.id == "" then return nil, "字段必须提供 id。" end
    if type(definition.consumer) ~= "string" or definition.consumer == "" then return nil, "字段必须提供 consumer。" end
    if type(definition.domain) ~= "string" or not Core.DataDomains._definitions[definition.domain] then return nil, "字段必须引用已注册领域。" end
    if definition.resource ~= nil and (type(definition.resource) ~= "string" or not Core.Resources:Get(definition.resource)) then return nil, "字段必须引用已注册资源。" end
    if type(definition.Read) ~= "function" then return nil, "字段必须提供 Read 回调。" end
    if self._definitions[definition.id] then return nil, "字段 ID 已被 " .. self._definitions[definition.id].owner .. " 占用: " .. definition.id end
    local order = tonumber(definition.order)
    if not order then return nil, "字段必须提供数值 order。" end
    local claimed, errorMessage = Core.Registry:ClaimResource("field", definition.id, owner, { consumer = definition.consumer, domain = definition.domain })
    if not claimed then return nil, errorMessage end
    local entry = {
        id = definition.id, owner = owner, consumer = definition.consumer, domain = definition.domain, resource = definition.resource,
        title = definition.title or definition.id, order = order, width = tonumber(definition.width) or 80,
        minWidth = tonumber(definition.minWidth), maxWidth = tonumber(definition.maxWidth), gapAfter = tonumber(definition.gapAfter),
        defaultVisible = definition.defaultVisible == true, defaultPreviewVisible = definition.defaultPreviewVisible == true,
        align = definition.align == "RIGHT" and "RIGHT" or "LEFT", Read = definition.Read, Format = definition.Format,
        GetIcon = definition.GetIcon, GetColor = definition.GetColor,
    }
    self._definitions[entry.id] = entry
    return entry
end

function Fields:GetByConsumer(consumer)
    local result = {}
    for _, field in pairs(self._definitions) do if field.consumer == consumer then result[#result + 1] = field end end
    table.sort(result, function(left, right) return left.order == right.order and left.id < right.id or left.order < right.order end)
    return result
end

function Fields:GetValue(character, field)
    local domain = character and character.domains and character.domains[field.domain]
    return field.Read(character, domain and Copy(domain.data) or nil, domain and domain.state)
end

function Fields:FormatValue(character, field)
    local value = self:GetValue(character, field)
    if field.Format then return field.Format(value, character), value end
    return value == nil and "—" or tostring(value), value
end

Core.Capabilities:Register("fields", 1)
