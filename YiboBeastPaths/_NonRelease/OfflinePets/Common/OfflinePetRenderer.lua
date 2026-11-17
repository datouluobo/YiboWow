local _, ns = ...

-- Renderer uses Core's scroll surface; both page and preview receive the same
-- already-filtered projection from OfflinePetPage.
function ns.CreateOfflinePetRenderer(core, text)
    local theme = core.UITheme
    local renderer = {}
    function renderer.Create(parent)
        parent.scroll = theme:CreateScrollFrame(parent)
        parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
        parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
        parent.content = CreateFrame("Frame", nil, parent.scroll)
        parent.content:SetSize(500, 1)
        parent.scroll:SetScrollChild(parent.content)
        parent.scroll:BindScrollbarGutter(parent.content)
        parent.lines = {}
    end
    function renderer.Refresh(parent, context, rows)
        local lines = {}
        local function add(value) lines[#lines + 1] = value end
        local function addGroup(label, group)
            if type(group) ~= "table" or type(group.items) ~= "table" then
                add(text("OFFLINE_UNKNOWN", label)); return
            end
            add(text("OFFLINE_GROUP", label, tostring(group.capturedAt or "?")))
            if #group.items == 0 then add(text("OFFLINE_EMPTY")) end
            for _, pet in ipairs(group.items) do
                add("  " .. tostring(pet.name or text("OFFLINE_UNNAMED")))
            end
        end
        if #rows == 0 then add(text("OFFLINE_NO_DATA")) end
        for _, row in ipairs(rows) do
            add(row.name)
            addGroup(text("OFFLINE_ACTIVE"), row.active)
            addGroup(text("OFFLINE_STABLE"), row.stable)
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
