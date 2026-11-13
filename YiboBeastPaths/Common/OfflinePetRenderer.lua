local _, ns = ...
if not ns.YBP_TARGET_OK then return end

-- Renderer uses Core's scroll surface; both page and preview receive the same
-- already-filtered projection from OfflinePetPage.
function ns.CreateOfflinePetRenderer(core, text)
    local theme = core.UITheme
    local renderer, selectedID = {}, nil
    function renderer.Create(parent, context)
        if not (context and context.preview) then
            parent.characterSelect = theme:CreateDropdown(parent, 220, {})
            parent.characterSelect:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
            parent.characterSelect:SetMenuPageSize(8)
            parent.characterSelect:SetOnValueChanged(function(id)
                selectedID = id
                core.AccountView:NotifyPageChanged("yibo-beastpaths-offline-pets")
            end)
        end
        parent.scroll = theme:CreateScrollFrame(parent)
        parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, context and context.preview and -8 or -42)
        parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
        parent.content = CreateFrame("Frame", nil, parent.scroll)
        parent.content:SetSize(500, 1)
        parent.scroll:SetScrollChild(parent.content)
        parent.scroll:BindScrollbarGutter(parent.content)
        parent.lines = {}
    end
    function renderer.Refresh(parent, context, rows, showPets, invalidStore)
        local selected
        if not context.preview and parent.characterSelect then
            local options = {}
            for _, row in ipairs(rows) do
                options[#options + 1] = { value = row.id, label = row.name }
                if row.id == selectedID then selected = row end
            end
            selected = selected or rows[1]
            selectedID = selected and selected.id or nil
            parent.characterSelect:SetOptions(options)
            if selected then
                parent.characterSelect:SetValue(selected.id)
                parent.characterSelect:Show()
            else
                parent.characterSelect:Hide()
            end
        end
        local lines = {}
        local function add(value) lines[#lines + 1] = value end
        local function addGroup(label, group)
            if type(group) ~= "table" or type(group.items) ~= "table" then
                add(text("OFFLINE_UNKNOWN", label)); return
            end
            local captured = type(group.capturedAt) == "number" and date("%Y-%m-%d %H:%M", group.capturedAt) or "?"
            add(text(group.completeness == "unverified" and "OFFLINE_GROUP_OBSERVED" or "OFFLINE_GROUP", label, captured))
            if #group.items == 0 then
                add(text(group.completeness == "unverified" and "OFFLINE_UNKNOWN", label) or text("OFFLINE_EMPTY"))
            else
                add(text("OFFLINE_PET_COUNT", tostring(#group.items)))
            end
            if context.preview then return end
            for _, pet in ipairs(group.items) do
                local name = type(pet.name) == "string" and pet.name ~= "" and pet.name or text("OFFLINE_UNNAMED")
                local family = type(pet.family) == "string" and pet.family ~= "" and pet.family or text("OFFLINE_PET_FAMILY_UNKNOWN")
                local level = type(pet.level) == "number" and pet.level > 0 and pet.level < math.huge
                    and text("OFFLINE_PET_LEVEL", tostring(pet.level)) or text("OFFLINE_PET_LEVEL_UNKNOWN")
                local icon = pet.icon
                if type(icon) == "number" and icon > 0 and icon < math.huge and icon % 1 == 0 then
                    icon = tostring(icon)
                elseif type(icon) ~= "string" or icon == "" or icon:find("|", 1, true)
                    or icon:find(":", 1, true) or icon:find("[%c]") then
                    icon = nil
                end
                local prefix = icon and ("|T" .. icon .. ":18:18|t ") or "  "
                add(prefix .. text("OFFLINE_PET_DETAIL", name, family, level))
            end
        end
        if invalidStore then add(text("OFFLINE_STORE_INVALID"))
        elseif #rows == 0 then add(text("OFFLINE_NO_DATA")) end
        local displayed = not context.preview and parent.characterSelect and (selected and { selected } or {}) or rows
        for _, row in ipairs(displayed) do
            add(row.name)
            if showPets ~= false then
                local attempt = row.lastAttempt
                if type(attempt) == "table" and (attempt.status == "unverified" or attempt.status == "unavailable") then
                    local when = type(attempt.at) == "number" and date("%Y-%m-%d %H:%M", attempt.at) or "?"
                    add(text(attempt.status == "unverified" and "OFFLINE_ATTEMPT_UNVERIFIED" or "OFFLINE_ATTEMPT_UNAVAILABLE", when))
                end
                addGroup(text("OFFLINE_ACTIVE"), row.active)
                addGroup(text("OFFLINE_STABLE"), row.stable)
            end
        end
        local width = core.AccountView:GetScrollSurfaceWidth(context, parent, #lines * 22, 0)
        parent.content:SetWidth(width)
        for i, value in ipairs(lines) do
            local line = parent.lines[i]
            if not line then
                line = theme:CreateText(parent.content, theme.Font.body, theme.Colors.text, "LEFT")
                parent.lines[i] = line
            end
            line:ClearAllPoints(); line:SetPoint("TOPLEFT", 8, -(i - 1) * 22)
            line:SetWidth(math.max(1, width - 16)); line:SetText(value); line:Show()
        end
        for i = #lines + 1, #parent.lines do parent.lines[i]:Hide() end
        local height = math.max(1, #lines * 22)
        parent.content:SetHeight(height); parent.scroll:SetContentHeight(height)
    end
    function renderer.GetSurfaceMetrics(context)
        local count = #(context.characters or {})
        return { minContentWidth = 320, naturalContentWidth = 540,
            minContentHeight = 120, naturalContentHeight = 300,
            scrollContentHeight = count * 88, scrollFixedHeight = 30 }
    end
    return renderer
end
