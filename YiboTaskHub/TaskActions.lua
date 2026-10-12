local Addon = _G.YiboTaskHub
local Actions = {}
Addon.TaskActions = Actions
local keys = { "type", "item", "spell", "macrotext", "type1", "item1", "macrotext1", "type2", "macrotext2", "type3", "type4", "type5" }
function Actions:Resolve(task)
    local goal = task and task.goalID and Addon.db.goals.byID[task.goalID]
    if not goal or (goal.state ~= "active" and not (task.retainedInView and goal.state == "completed")) then return nil end
    for _, ref in ipairs(Addon.Core.Contracts:List("action.targets", { major = 1, minMinor = 2 })) do
        if ref.providerID == goal.intent.providerID then
            local descriptor = Addon.Core.Contracts:Call(Addon.NAME, ref, "GetClickAction", { intent = goal.intent })
            if type(descriptor) == "table" and type(descriptor.attributes) == "table" then return descriptor, ref, goal.intent end
        end
    end
end
function Actions:Bind(band, workOffset, task)
    if InCombatLockdown and InCombatLockdown() then return end
    if band.executeIcon then band.executeIcon:Hide(); band.executeIcon.ref = nil; for _, key in ipairs(keys) do band.executeIcon:SetAttribute(key, nil) end end
    if type(workOffset) ~= "number" or not task then return end
    local descriptor, ref, intent = self:Resolve(task)
    if not descriptor then return end
    local button = band.executeIcon
    if not button then
        button = CreateFrame("Button", nil, band, "SecureActionButtonTemplate")
        band.executeIcon = button; button:SetSize(24, 24); button:EnableMouse(true)
        button:RegisterForClicks("AnyUp"); button:SetAttribute("useOnKeyDown", false)
        button:HookScript("PostClick", function(control, mouseButton)
            if control.ref and (mouseButton == "LeftButton" or mouseButton == "RightButton") then
                Addon.Core.Contracts:Call(Addon.NAME, control.ref, "AfterClick", { intent = control.intent, button = mouseButton })
            end
        end)
    end
    button.ref, button.intent = ref, intent
    for _, key in ipairs(keys) do button:SetAttribute(key, descriptor.attributes[key]) end
    -- No default action may fall through to middle/extra physical buttons.
    for _, key in ipairs({ "type3", "type4", "type5" }) do button:SetAttribute(key, "") end
    -- Secure frames cannot anchor to FontStrings. Reuse the column layout's
    -- numeric offset while anchoring exclusively to the containing row Frame.
    button:ClearAllPoints(); button:SetPoint("LEFT", band, "LEFT", workOffset, 0)
    Addon.Core.UITheme:BindTooltip(button, task.title, {
        { kind = "text", text = Addon:T("TEXT.LEFT_CLICK.E72B04") .. (descriptor.leftTitle or Addon:T("TEXT.RUN.28FEBB")) },
        { kind = "text", text = Addon:T("TEXT.RIGHT_CLICK.A79B20") .. (descriptor.rightTitle or Addon:T("TEXT.VIEW.F7ACEF")) },
    })
    button:Show()
end
