local _, ns = ...
if not ns.YBP_TARGET_OK then return end

-- Renderer uses Core's scroll surface; both page and preview receive the same
-- already-filtered projection from OfflinePetPage.
function ns.CreateOfflinePetRenderer(core, text)
    local theme = core.UITheme
    local renderer, selectedID = {}, nil
    local selectedPet, familyFilter, searchQuery = nil, "", ""
    local pageID = "yibo-beastpaths-offline-pets"
    local function refresh() core.AccountView:NotifyPageChanged(pageID) end
    local function petName(pet)
        return type(pet.name) == "string" and pet.name ~= "" and pet.name or text("OFFLINE_UNNAMED")
    end
    local function petFamily(pet)
        return type(pet.family) == "string" and pet.family ~= "" and pet.family or text("OFFLINE_PET_FAMILY_UNKNOWN")
    end
    local function sourceMap(pet)
        local creatureID = pet and pet.creatureID
        if type(creatureID) ~= "number" or creatureID <= 0 or creatureID % 1 ~= 0 then return text("STABLE_SOURCE_MAP") end
        local mapID
        for routeID, node in pairs(ns.routeNodeTooltips or {}) do
            local route = ns.pets and ns.pets[routeID]
            if type(node) == "table" and node.npcID == creatureID and route and type(route.mapID) == "number" then
                if mapID and mapID ~= route.mapID then return text("STABLE_SOURCE_MAP") end
                mapID = route.mapID
            end
        end
        if mapID and _G.C_Map and type(_G.C_Map.GetMapInfo) == "function" then
            local ok, info = pcall(_G.C_Map.GetMapInfo, mapID)
            if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                return text("STABLE_SOURCE_MAP_CATALOG", info.name)
            end
        end
        return text("STABLE_SOURCE_MAP")
    end
    local function configureModel(model)
        if type(model.SetModelScale) == "function" then pcall(model.SetModelScale, model, 1) end
        if type(model.SetCamera) == "function" then pcall(model.SetCamera, model, 0) end
        if type(model.SetPortraitZoom) == "function" then pcall(model.SetPortraitZoom, model, 0) end
        if type(model.SetCamDistanceScale) == "function" then pcall(model.SetCamDistanceScale, model, model.ybpCameraDistance or 1.5) end
        if type(model.RefreshCamera) == "function" then pcall(model.RefreshCamera, model) end
        if type(model.SetFacing) == "function" then pcall(model.SetFacing, model, 0.8) end
    end
    local function setModel(model, label, pet, icon)
        local id = pet and pet.displayID
        local valid = type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
        local ok = valid and model and model.ybpDisplayID == id
        if model and not ok then
            if model.ClearModel then model:ClearModel() end
            model.ybpDisplayID = nil
            ok = valid and type(model.SetDisplayInfo) == "function" and pcall(model.SetDisplayInfo, model, id)
            if ok then
                model.ybpDisplayID = id
                configureModel(model)
            end
        end
        if model then model:SetShown(ok == true) end
        label:SetShown(ok ~= true)
        local texture = pet and pet.icon
        if type(texture) == "number" then
            if texture <= 0 or texture >= math.huge or texture % 1 ~= 0 then texture = nil end
        elseif type(texture) ~= "string" or texture == "" or texture:find("|", 1, true)
            or texture:find(":", 1, true) or texture:find("[%c]") then texture = nil end
        if icon then
            if ok ~= true and texture then icon:SetTexture(texture); icon:Show() else icon:Hide() end
        end
    end
    local function makeModel(parent, distance)
        local ok, model = pcall(CreateFrame, "PlayerModel", nil, parent)
        if not ok then return nil end
        model:EnableMouse(false)
        model.ybpCameraDistance = distance or 1.5
        model:SetScript("OnModelLoaded", configureModel)
        return model
    end
    local function createCard(parent)
        local card = theme:CreateButton(parent, 120, "", "secondary")
        card.label:Hide()
        card.model = makeModel(card)
        if card.model then
            card.model:SetPoint("TOPLEFT", 5, -5)
            card.model:SetPoint("BOTTOMRIGHT", -5, 43)
        end
        card.unknown = theme:CreateText(card, theme.Font.assist, theme.Colors.muted, "CENTER")
        card.unknown:SetPoint("BOTTOMLEFT", 4, 44); card.unknown:SetPoint("BOTTOMRIGHT", -4, 44)
        card.unknown:SetText(text("STABLE_APPEARANCE_UNKNOWN"))
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(42, 42); card.icon:SetPoint("CENTER", card, "CENTER", 0, 17)
        card.name = theme:CreateText(card, theme.Font.body, theme.Colors.text, "CENTER")
        card.name:SetPoint("BOTTOMLEFT", 4, 24); card.name:SetPoint("BOTTOMRIGHT", -4, 24)
        card.info = theme:CreateText(card, theme.Font.assist, theme.Colors.muted, "CENTER")
        card.info:SetPoint("BOTTOMLEFT", 4, 7); card.info:SetPoint("BOTTOMRIGHT", -4, 7)
        card:SetScript("OnClick", function(self)
            if self.entry then selectedPet = self.entry.key; refresh() end
        end)
        return card
    end
    local function createMain(parent)
        parent.search = theme:CreateInput(parent, { width = 190, placeholder = text("STABLE_SEARCH"),
            OnChanged = function(value, userInput)
                if userInput then searchQuery = value or ""; refresh() end
            end })
        parent.search:SetPoint("TOPLEFT", parent.characterSelect, "TOPRIGHT", 8, 0)
        parent.familySelect = theme:CreateDropdown(parent, 145, {})
        parent.familySelect:SetPoint("TOPLEFT", parent.search, "TOPRIGHT", 8, 0)
        parent.familySelect:SetMenuPageSize(8)
        parent.familySelect:SetOnValueChanged(function(value) familyFilter = value or ""; refresh() end)
        parent.detail = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        parent.detail:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        parent.detail:SetBackdropColor(unpack(theme.Colors.panel)); parent.detail:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        parent.detail:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -42)
        parent.detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
        parent.detail:SetWidth(210)
        parent.detail.model = makeModel(parent.detail, 1.3)
        if parent.detail.model then parent.detail.model:SetPoint("TOPLEFT", 8, -8); parent.detail.model:SetPoint("TOPRIGHT", -8, -8); parent.detail.model:SetHeight(160) end
        parent.detail.unknown = theme:CreateText(parent.detail, theme.Font.body, theme.Colors.muted, "CENTER")
        parent.detail.unknown:SetPoint("TOPLEFT", 8, -130); parent.detail.unknown:SetPoint("TOPRIGHT", -8, -130)
        parent.detail.unknown:SetText(text("STABLE_APPEARANCE_UNKNOWN"))
        parent.detail.icon = parent.detail:CreateTexture(nil, "ARTWORK")
        parent.detail.icon:SetSize(64, 64); parent.detail.icon:SetPoint("TOP", parent.detail, "TOP", 0, -36)
        parent.detail.info = theme:CreateText(parent.detail, theme.Font.body, theme.Colors.text, "LEFT")
        parent.detail.info:SetPoint("TOPLEFT", 12, -180); parent.detail.info:SetPoint("TOPRIGHT", -12, -180)
        parent.detail.info:SetWordWrap(true); parent.detail.info:SetJustifyV("TOP")
        parent.cards, parent.headers = {}, {}
        parent.scroll:ClearAllPoints(); parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -42)
        parent.scroll:SetPoint("BOTTOMRIGHT", parent.detail, "BOTTOMLEFT", -8, 0)
        parent.scroll:HookScript("OnVerticalScroll", function() if parent.renderVisible then parent.renderVisible() end end)
        parent.scroll:HookScript("OnSizeChanged", function(_, width)
            if not width or width < 1 or math.abs(width - (parent.lastStableWidth or 0)) < 1 then return end
            parent.lastStableWidth = width
            if parent.stableResizePending then return end
            parent.stableResizePending = true
            local function update()
                parent.stableResizePending = nil
                if parent:IsShown() then refresh() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, update) else update() end
        end)
    end
    local function renderMain(parent, context, row, invalidStore)
        local width = math.max(240, (parent.scroll:GetWidth() or 0) - 16)
        parent.content:SetWidth(width)
        local families, seen = { { value = "", label = text("STABLE_ALL_FAMILIES") } }, {}
        for _, group in ipairs({ row and row.active or {}, row and row.stable or {} }) do
            for _, pet in ipairs(group.items or {}) do
                local family = petFamily(pet)
                if not seen[family] then seen[family] = true; families[#families + 1] = { value = family, label = family } end
            end
        end
        table.sort(families, function(a, b)
            if a.value == b.value then return false end
            if a.value == "" then return true elseif b.value == "" then return false end
            return a.label < b.label
        end)
        if familyFilter ~= "" and not seen[familyFilter] then familyFilter = "" end
        parent.familySelect:SetOptions(families); parent.familySelect:SetValue(familyFilter)
        local columns = math.max(1, math.min(4, math.floor((width + 8) / 155)))
        local cardWidth = math.floor((width - (columns - 1) * 8) / columns)
        local cardHeight, headerHeight, y = 148, 30, 0
        local entries, headers = {}, {}
        local query = string.lower(searchQuery or "")
        local function groupItems(groupName, group)
            local label = text(groupName == "active" and "OFFLINE_ACTIVE" or "OFFLINE_STABLE")
            local captured = group and type(group.capturedAt) == "number" and date("%Y-%m-%d %H:%M", group.capturedAt) or "?"
            local heading = group and text("OFFLINE_GROUP", label, captured) or text("OFFLINE_UNKNOWN", label)
            if group and group.items then heading = heading .. " · " .. text("OFFLINE_PET_COUNT", tostring(#group.items)) end
            headers[#headers + 1] = { y = y, value = heading }; y = y + headerHeight
            local count = 0
            for _, pet in ipairs(group and group.items or {}) do
                local family, name = petFamily(pet), petName(pet)
                if (familyFilter == "" or family == familyFilter)
                    and (query == "" or string.find(string.lower(name .. " " .. family), query, 1, true)) then
                    local column, rowIndex = count % columns, math.floor(count / columns)
                    entries[#entries + 1] = { pet = pet, group = groupName, capturedAt = group.capturedAt,
                        key = groupName .. ":" .. tostring(pet.slotID), x = column * (cardWidth + 8), y = y + rowIndex * (cardHeight + 8) }
                    count = count + 1
                end
            end
            if count == 0 then
                local empty = group and group.items and #group.items == 0 and group.completeness == "complete"
                headers[#headers + 1] = { y = y, value = empty and text("OFFLINE_EMPTY")
                    or group and text("STABLE_NO_MATCH") or text("OFFLINE_UNKNOWN", label) }
                y = y + 28
            else y = y + math.ceil(count / columns) * (cardHeight + 8) end
            y = y + 8
        end
        if row then
            local attempt = row.lastAttempt
            if type(attempt) == "table" and attempt.status == "unavailable" then
                local when = type(attempt.at) == "number" and date("%Y-%m-%d %H:%M", attempt.at) or "?"
                headers[#headers + 1] = { y = y, value = text("OFFLINE_ATTEMPT_UNAVAILABLE", when) }; y = y + 28
            end
            groupItems("active", row.active); groupItems("stable", row.stable)
        else headers[1] = { y = 0, value = text(invalidStore and "OFFLINE_STORE_INVALID" or "OFFLINE_NO_DATA") }; y = 35 end
        local selected
        for _, entry in ipairs(entries) do if entry.key == selectedPet then selected = entry; break end end
        selected = selected or entries[1]; selectedPet = selected and selected.key or nil
        for index, header in ipairs(headers) do
            local label = parent.headers[index]
            if not label then label = theme:CreateText(parent.content, theme.Font.body, theme.Colors.text, "LEFT"); parent.headers[index] = label end
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", 4, -header.y); label:SetWidth(width - 8); label:SetText(header.value); label:Show()
        end
        for index = #headers + 1, #parent.headers do parent.headers[index]:Hide() end
        parent.content:SetHeight(math.max(1, y)); parent.scroll:SetContentHeight(y)
        parent.renderVisible = function()
            local offset, viewport = parent.scroll:GetVerticalScroll() or 0, parent.scroll:GetHeight() or 0
            if viewport < 1 then viewport = 600 end
            local used = 0
            for _, entry in ipairs(entries) do
                if entry.y + cardHeight >= offset - cardHeight and entry.y <= offset + viewport + cardHeight then
                    used = used + 1
                    local card = parent.cards[used]
                    if not card then card = createCard(parent.content); parent.cards[used] = card end
                    card.entry = entry; card:ClearAllPoints(); card:SetPoint("TOPLEFT", entry.x, -entry.y); card:SetSize(cardWidth, cardHeight)
                    card:SetState(entry.key == selectedPet and "selected" or "default")
                    card.name:SetText(petName(entry.pet))
                    local level = type(entry.pet.level) == "number" and entry.pet.level > 0 and text("OFFLINE_PET_LEVEL", tostring(entry.pet.level)) or text("OFFLINE_PET_LEVEL_UNKNOWN")
                    card.info:SetText(level .. " · " .. text("STABLE_SLOT", tostring(entry.pet.slotID)))
                    setModel(card.model, card.unknown, entry.pet, card.icon); card:Show()
                end
            end
            for index = used + 1, #parent.cards do parent.cards[index]:Hide() end
        end
        parent.renderVisible()
        setModel(parent.detail.model, parent.detail.unknown, selected and selected.pet, parent.detail.icon)
        if selected then
            local pet = selected.pet
            local level = type(pet.level) == "number" and pet.level > 0 and text("OFFLINE_PET_LEVEL", tostring(pet.level)) or text("OFFLINE_PET_LEVEL_UNKNOWN")
            local captured = type(selected.capturedAt) == "number" and date("%Y-%m-%d %H:%M", selected.capturedAt) or "?"
            parent.detail.info:SetText(text("STABLE_DETAIL_NAME", petName(pet)) .. "\n\n"
                .. text("STABLE_DETAIL_FAMILY", petFamily(pet)) .. "\n\n" .. level .. "\n\n"
                .. text("STABLE_DETAIL_LOCATION", text(selected.group == "active" and "OFFLINE_ACTIVE" or "OFFLINE_STABLE"), text("STABLE_SLOT", tostring(pet.slotID)))
                .. "\n\n" .. text("STABLE_DETAIL_CAPTURE", captured) .. "\n\n" .. sourceMap(pet))
        else parent.detail.unknown:Hide(); parent.detail.info:SetText("") end
    end
    function renderer.Create(parent, context)
        if not (context and context.preview) then
            parent.characterSelect = theme:CreateDropdown(parent, 220, {})
            parent.characterSelect:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
            parent.characterSelect:SetMenuPageSize(8)
            parent.characterSelect:SetOnValueChanged(function(id)
                selectedID = id
                selectedPet = nil
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
        if not (context and context.preview) then createMain(parent) end
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
        if not context.preview then
            renderMain(parent, context, showPets ~= false and selected or nil, invalidStore)
            return
        end
        local lines = {}
        local function add(value) lines[#lines + 1] = value end
        local function addGroup(label, group)
            if type(group) ~= "table" or type(group.items) ~= "table" then
                add(text("OFFLINE_UNKNOWN", label)); return
            end
            local captured = type(group.capturedAt) == "number" and date("%Y-%m-%d %H:%M", group.capturedAt) or "?"
            add(text("OFFLINE_GROUP", label, captured))
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
                if type(attempt) == "table" and attempt.status == "unavailable" then
                    local when = type(attempt.at) == "number" and date("%Y-%m-%d %H:%M", attempt.at) or "?"
                    add(text("OFFLINE_ATTEMPT_UNAVAILABLE", when))
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
        return { minContentWidth = context.preview and 320 or 700, naturalContentWidth = context.preview and 540 or 1100,
            minContentHeight = context.preview and 120 or 400, naturalContentHeight = context.preview and 300 or 720,
            scrollContentHeight = count * 88, scrollFixedHeight = 30 }
    end
    return renderer
end
