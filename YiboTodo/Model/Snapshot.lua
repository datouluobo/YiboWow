local Addon = _G.YiboTodo
local Snapshot = { dirty = true }
Addon.Snapshot = Snapshot

function Snapshot:Invalidate() self.dirty = true end

local function BuildGroup(groupID)
    local group = Addon.Catalog.groups[groupID]
    group.members = {}
    for _, recipe in pairs(Addon.Catalog.recipes) do if recipe.active and recipe.cooldownGroupID == groupID then group.members[#group.members + 1] = recipe end end
    return group
end

local function ProfessionSlots(characterID)
    local core = Addon.Core
    local domain = core and core.DataDomains and core.DataDomains:Get(characterID, "professions")
    if not (domain and domain.state == "known" and domain.data) then return nil end
    local slots = {}
    for slot = 1, 2 do
        local profession = domain.data.primaryProfessions and domain.data.primaryProfessions[slot]
        local professionID = profession and tonumber(profession.id)
        slots[slot] = professionID and { id = professionID, name = profession.name, icon = profession.icon } or false
    end
    return slots
end

local function RecipeForGroup(group)
    for _, recipe in ipairs(group.members or {}) do
        if recipe.active then return recipe end
    end
end

local function SortProjects(left, right)
    local priority = { actionable = 1, estimated = 2, cooldown = 3, unknown = 4 }
    local leftPriority, rightPriority = priority[left.state] or 99, priority[right.state] or 99
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    return (left.order or 999) < (right.order or 999)
end

function Snapshot:Build()
    if not self.dirty and self.value then return self.value end
    local value = { revision = (self.value and self.value.revision or 0) + 1, builtAt = Addon:Now(), characters = {}, accountActivities = {} }
    local characters = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetAll() or {}
    for _, coreCharacter in ipairs(characters) do
        local characterID, slots = coreCharacter.id, ProfessionSlots(coreCharacter.id)
        if slots then
            local stored = (Addon.db.byCharacter or {})[characterID] or {}
            local provider = stored.providers and stored.providers["profession-cooldown"]
            local character = { updatedAt = provider and provider.lastSuccessAt or 0, providerState = provider and provider.state or "not-yet-scanned", activities = {}, professionSlots = slots, summary = { todo = 0, actionable = 0, cooldown = 0, items = {} } }
            for groupID, group in pairs(Addon.Catalog.groups) do
                if group.active then
                    local builtGroup, observation = BuildGroup(groupID), provider and provider.observations and provider.observations[groupID]
                    -- A recipe can only project into the Core-declared primary
                    -- profession slot.  Do not turn the catalog into a source
                    -- of profession ownership.
                    local slot
                    for index = 1, 2 do if slots[index] and slots[index].id == tonumber(builtGroup.professionID) then slot = index; break end end
                    local activity = Addon.Model.State:Evaluate(builtGroup, observation, value.builtAt)
                    if slot and observation and activity.state ~= "locked" then
                        local recipe = RecipeForGroup(builtGroup)
                        if recipe then
                            activity.groupID, activity.slot, activity.label = groupID, slot, builtGroup.label or groupID
                            activity.icon, activity.order, activity.period = recipe.resultItemID, builtGroup.order, builtGroup.resetKind
                            activity.observedAt = observation.observedAt or provider.lastSuccessAt
                            character.activities[groupID] = activity
                        end
                    end
                    if slot then
                        if activity.state == "actionable" then character.summary.todo = character.summary.todo + 1; character.summary.actionable = character.summary.actionable + 1; character.summary.items[#character.summary.items + 1] = group.label or groupID
                        elseif activity.state == "estimated" then character.summary.todo = character.summary.todo + 1; character.summary.items[#character.summary.items + 1] = "预计：" .. (group.label or groupID)
                        elseif activity.state == "cooldown" then
                            character.summary.cooldown = character.summary.cooldown + 1
                            if not character.summary.nearestReady or activity.readyAt < character.summary.nearestReady then character.summary.nearestReady = activity.readyAt end
                        elseif activity.state == "unknown" then
                            character.summary.items[#character.summary.items + 1] = "待确认：" .. (group.label or groupID)
                        end
                    end
                end
            end
            character.projectsBySlot = { {}, {} }
            for _, activity in pairs(character.activities) do character.projectsBySlot[activity.slot][#character.projectsBySlot[activity.slot] + 1] = activity end
            for slot = 1, 2 do table.sort(character.projectsBySlot[slot], SortProjects) end
            value.characters[characterID] = character
        end
    end
    self.value, self.dirty = value, false
    return value
end

function Snapshot:GetCharacter(id) return self:Build().characters[id] end
