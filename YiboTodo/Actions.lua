local Addon = _G.YiboTodo
local Actions = {}
Addon.Actions = Actions

-- Plain-value action description shared by Todo icons and optional consumers.
-- Only a hardware-clicked secure button may execute these attributes.
function Actions:Describe(project, isCurrentCharacter)
    if not self:IsEligible(project, isCurrentCharacter) then return nil end
    local action = project.action
    local itemID = action.actionMode == "use-item" and tonumber(action.itemID)
    local item = itemID and (action.itemName or (GetItemInfo and GetItemInfo(itemID)) or ("item:" .. itemID))
    local spellID = action.actionMode == "direct-craft" and tonumber(action.castSpellID)
    local spellName
    if spellID and C_Spell and C_Spell.GetSpellInfo then local info = C_Spell.GetSpellInfo(spellID); spellName = info and info.name
    elseif spellID and GetSpellInfo then spellName = GetSpellInfo(spellID) end
    local function Escape(value) return value and string.gsub(string.gsub(value, "\\", "\\\\"), '"', '\\"') end
    local profession = spellID and Escape(project.professionName)
    local recipe = spellID and Escape(spellName or project.label)
    local open = profession and string.format('/run if not TradeSkillFrame or not TradeSkillFrame:IsShown()or GetTradeSkillLine()~="%s"then CastSpellByName("%s")end', profession, profession)
    local craft = recipe and profession and string.format('/run for i=1,GetNumTradeSkills()do if GetTradeSkillInfo(i)=="%s"then DoTradeSkill(i,1);return end end;if GetTradeSkillLine()~="%s"then CastSpellByName("%s")end', recipe, profession, profession)
    local target = itemID and action.interactName and string.format("/targetexact %s", action.interactName)
    if not item and not craft and not open then return nil end
    return { attributes = { type1 = item and "item" or "macro", item1 = item, macrotext1 = craft or open,
        type2 = (target or open) and "macro" or "", macrotext2 = target or open },
        professionAction = spellID ~= nil, spellID = spellID, spellName = spellName,
        itemID = itemID, itemName = item, openProfessionMacro = open,
        leftTitle = item and Addon:T("ACTION.USE_ITEM") or Addon:T("ACTION.CRAFT_ONCE"), rightTitle = target and Addon:T("ACTION.TARGET_NOMI") or Addon:T("ACTION.OPEN_PROFESSION") }
end

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
