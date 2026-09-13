local Addon = _G.YiboTodo
local Actions = {}
Addon.Actions = Actions

local function Call(fn, ...)
    if type(fn) ~= "function" then return false, "api-unavailable" end
    local ok, result = pcall(fn, ...)
    if not ok then return false, "api-error" end
    return result ~= false, result
end

function Actions:IsEligible(project, isCurrentCharacter)
    return isCurrentCharacter == true and type(project) == "table"
        and type(project.action) == "table"
end

function Actions:OpenProfession(project)
    local api = self.api or {}
    if api.openProfession then return Call(api.openProfession, project.professionID) end
    local tradeSkill = _G.C_TradeSkillUI
    if tradeSkill and type(tradeSkill.OpenTradeSkill) == "function" then
        return Call(tradeSkill.OpenTradeSkill, project.professionID)
    end
    if type(_G.TradeSkillFrame_OpenTradeSkill) == "function" then
        return Call(_G.TradeSkillFrame_OpenTradeSkill, project.professionID)
    end
    return false, "api-unavailable"
end

function Actions:SelectRecipe(project, action)
    local api = self.api or {}
    if api.selectRecipe then return Call(api.selectRecipe, project, action) end
    -- The target client may expose a recipe-ID selector under a different
    -- name. Keep this adapter explicit until a live probe confirms the API;
    -- never guess by clicking a list index or selecting a same-output recipe.
    return false, "api-unavailable"
end

function Actions:ChooseMember(project)
    local members = project.action and project.action.members
    if type(members) ~= "table" or #members == 0 then return project.action end
    for _, member in ipairs(members) do
        if member.learned and member.craftable ~= false and (not member.readyAt or member.readyAt <= Addon:Now()) then
            return member
        end
    end
    return members[1]
end

function Actions:Execute(project, isCurrentCharacter)
    if not self:IsEligible(project, isCurrentCharacter) then return false, "not-eligible" end
    if self.busy then return false, "busy" end
    local action = self:ChooseMember(project)
    if not action then return false, "missing-action" end

    -- Item use is protected by WoW and must be performed by the icon's
    -- SecureActionButtonTemplate binding, never from this Lua callback.
    if action.actionMode == "use-item" then return false, "secure-action-required" end

    self.busy = true
    local opened, openReason = self:OpenProfession(project)
    if not opened then self.busy = false; return false, openReason end
    local selected, selectReason = self:SelectRecipe(project, action)
    self.busy = false
    if selected then return true, "opened-and-selected" end
    if selectReason == "api-unavailable" then return true, "opened-profession" end
    return false, selectReason
end

function Actions:Release()
    self.busy = false
end
