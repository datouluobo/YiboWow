-- Actual shared dropdowns: avoid repeated rendering and repeated state queries.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local options = {}
    for i = 1, 100 do options[i] = { value = i, label = 'Option ' .. i } end
    local dropdown = core.UITheme:CreateDropdown(env.UIParent, 180, options)
    dropdown:SetMenuPageSize(10); dropdown:SetValue(23)
    local renders, original = 0, dropdown.SetOptions
    dropdown.SetOptions = function(self, value) renders = renders + 1; return original(self, value) end
    dropdown:Fire('OnClick')
    print(target .. ': paged dropdown open renders=' .. renders)
    if not baseline then assert(renders == 1) end
    assert(dropdown.menuPage == 3 and dropdown.menu.buttons[1].option.value == 21)
    local chosen
    dropdown:SetOnValueChanged(function(value) chosen = value end)
    dropdown.menu.buttons[5]:Fire('OnClick')
    assert(chosen == 25 and dropdown.value == 25 and not dropdown.menu:IsShown())
    local short = {}; for i = 1, 21 do short[i] = options[i] end
    dropdown:SetOptions(short); dropdown:SetValue(21)
    dropdown.GetBottom = function() return 100 end
    dropdown:Fire('OnClick')
    assert(dropdown.menuPage == 3 and dropdown.menu.buttons[1].option.value == 21)
    assert(dropdown.menu.points[1][1] == 'TOPLEFT', 'partial final page uses its own height for positioning')
    assert(dropdown.menu.buttons[1]:GetFrameLevel() == dropdown.menu:GetFrameLevel() + 1)
    local states, checks, count = {}, {}, 0
    for i = 1, 100 do
        local index = i; states[i] = i % 2 == 1
        checks[i] = { title = 'Field ' .. i,
            isSelected = function() count = count + 1; return states[index] end,
            setSelected = function(value) states[index] = value end }
    end
    local multi = core.UITheme:CreateMultiSelectDropdown(env.UIParent, 180, {})
    multi:SetSummary('Fields')
    multi:SetOptions(checks)
    print(target .. ': 100 multi-select options, state queries=' .. count)
    if not baseline then assert(count == 100) end
    assert(multi.label:GetText() == 'Fields 50/100' and multi.menu.checks[1]:GetChecked())
    multi.menu.checks[1]:Fire('OnClick')
    assert(states[1] == false and multi.label:GetText() == 'Fields 49/100')
    states[2] = true; count = 0; multi:RefreshSummary()
    assert(multi.label:GetText() == 'Fields 50/100' and multi.menu.checks[2]:GetChecked())
    if not baseline then assert(count == 100) end
    -- Switching groups does not mix row state, and queries remain live.
    for index, check in ipairs(multi.menu.checks) do
        local slot = index
        check:HookScript('OnShow', function(control)
            local option = multi.displayedOptions[slot]
            if option then assert(control:GetChecked() == states[tonumber(option.title:match('%d+'))]) end
        end)
    end
    for i, option in ipairs(checks) do option.group = i <= 50 and 'First' or 'Second' end
    multi:SetOptions(checks)
    multi.activeGroup = 'Second'; count = 0; multi:RenderOptions()
    assert(#multi.displayedOptions == 50)
    assert(multi.menu.checks[1]:GetChecked() == states[51])
    if not baseline then assert(count == 100) end
end
print('PASS: dropdown single render, page selection/callbacks and live multi-select state/grouping')
