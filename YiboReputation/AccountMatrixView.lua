local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core.UITheme
local function Text(parent, size, color, justify) return Theme:CreateText(parent, size, color, justify or "LEFT") end
local function Snapshot(character) return Core.DataDomains:Get(character.id, "reputation") end
local function Faction(snapshot, id) return Addon:GetFactionData(snapshot, id) end
local function NodeFaction(snapshot, node)
    local data = Faction(snapshot, node.factionID)
    if node.guildName and (not data or data.name ~= node.guildName) then return nil end
    return data
end

local function HideMatrixTooltip()
    if GameTooltip and GameTooltip.YiboReputationMatrix then
        GameTooltip:Hide()
        GameTooltip.YiboReputationMatrix = nil
    end
end

local function UpdateMatrixTooltip(row)
    if not (row.tooltipNode and row.tooltipNode.kind == "faction" and row.tooltipColumns) then HideMatrixTooltip(); return end
    local scale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local cursorX = (GetCursorPosition and GetCursorPosition() or 0) / scale
    local offset = cursorX - (row:GetLeft() or cursorX)
    local columnIndex
    for index = 2, #row.tooltipColumns do
        local column = row.tooltipColumns[index]
        if offset >= column.left and offset < column.left + column.width then columnIndex = index; break end
    end
    if row.tooltipColumn == columnIndex then return end
    row.tooltipColumn = columnIndex
    if not columnIndex then HideMatrixTooltip(); return end
    local character = row.tooltipContext.characters[columnIndex - 1]
    local snapshot = Snapshot(character)
    local data = NodeFaction(snapshot, row.tooltipNode)
    -- Tooltips are disclosure, not a second copy of the grid.  A compact
    -- numeric cell gains its standing and full progress here; labels such as
    -- 崇拜、挚友 and every unavailable value already say all they can say.
    if not data then HideMatrixTooltip(); return end
    local compact, detail = Addon:FormatCompact(data), Addon:FormatReputation(data)
    if compact == detail or not string.find(detail, "/", 1, true) then HideMatrixTooltip(); return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row.tooltipNode.title or "声望", Theme.Colors.accent[1], Theme.Colors.accent[2], Theme.Colors.accent[3])
    GameTooltip:AddLine(detail, Theme.Colors.text[1], Theme.Colors.text[2], Theme.Colors.text[3])
    GameTooltip:Show()
    GameTooltip.YiboReputationMatrix = true
end

local function FactionData(id, characters, guildName)
    for _, character in ipairs(characters) do local data = Faction(Snapshot(character), id); if data and (not guildName or data.name == guildName) then return data end end
end

function Addon:IsMonitored(factionID)
    for _, id in ipairs(self:GetSettings().monitoredFactionIDs) do if id == factionID then return true end end
    return false
end
function Addon:ToggleMonitored(factionID)
    local list = self:GetSettings().monitoredFactionIDs
    for index, id in ipairs(list) do if id == factionID then table.remove(list, index); self:NotifyChanged(); return true end end
    if #list >= 10 then self:Print("快速监控最多只能添加 10 项声望，请先在声望设置中移除一项。"); return nil end
    list[#list + 1] = factionID; self:NotifyChanged(); return true
end

function Addon:CreateMatrixView(parent)
    parent.matrixToolbar = CreateFrame("Frame", nil, parent)
    parent.matrixToolbar.filterButtons = {}
    parent.matrixHeader = CreateFrame("Frame", nil, parent)
    parent.matrixHeader:SetClipsChildren(true)
    parent.matrixScroll = Theme:CreateScrollFrame(parent)
    parent.matrixBody = CreateFrame("Frame", nil, parent.matrixScroll)
    parent.matrixScroll:SetScrollChild(parent.matrixBody)
    parent.matrixRows, parent.matrixHeaders = {}, {}
    parent.matrixNodeCache, parent.matrixNodeCacheKey = nil, nil
end

function Addon:GetMatrixNodes(characters)
    local nodes, seen = {}, {}
    local function MakeFaction(id, key, guildName)
        local data = FactionData(id, characters, guildName)
        -- Do not manufacture rows for catalog IDs absent from every retained
        -- snapshot.  Those only produce “未知声望 ####” and add no comparison
        -- value; a future scan will naturally add the row when data exists.
        if not data then return nil end
        local available = false
        for _, character in ipairs(characters) do
            local snapshot = Snapshot(character)
            if self:GetFactionState(snapshot, id) ~= "unavailable" and (not guildName or (Faction(snapshot, id) and Faction(snapshot, id).name == guildName)) then available = true; break end
        end
        if not available then return nil end
        return { key = key or ("matrix:faction:" .. id), kind = "faction", factionID = id, guildName = guildName, title = guildName or self:GetFactionName(id, data and data.name), icon = self:GetFactionIcon(id), children = {} }
    end
    for expansionIndex = #self.Catalog, 1, -1 do
        local expansion = self.Catalog[expansionIndex]
        local node = { key = "matrix:" .. expansion.id, kind = "expansion", title = expansion.title, children = {} }
        for _, category in ipairs(expansion.categories) do
            if category.primaryFactionID then
                local primary = MakeFaction(category.primaryFactionID, "matrix:group:" .. expansion.id .. ":" .. category.id); seen[category.primaryFactionID] = true
                if primary then for _, id in ipairs(category.factions) do if id ~= category.primaryFactionID and not seen[id] then seen[id] = true; local child=MakeFaction(id);if child then primary.children[#primary.children + 1] = child end end end end
                -- The primary faction is both the group label and the real
                -- reputation.  Rendering a category wrapper here created an
                -- identical extra level for 黑王子、阡陌客 and 垂钓翁.
                if primary then node.children[#node.children + 1] = primary end
            elseif category.guild then
                seen[1168] = true
                local guilds = {}
                for _, character in ipairs(characters) do local data=Faction(Snapshot(character),1168);if data and data.name and data.name~="" then guilds[data.name]=true end end
                for guildName in pairs(guilds) do local guild=MakeFaction(1168,"matrix:guild:"..guildName,guildName);if guild then node.children[#node.children+1]=guild end end
            else
                local container = { key = node.key .. ":" .. category.id, kind = "category", title = category.title, children = {} }
                for _, id in ipairs(category.factions) do if not seen[id] then seen[id] = true; local faction=MakeFaction(id);if faction then container.children[#container.children + 1] = faction end end end
                if category.flat then for _, faction in ipairs(container.children) do node.children[#node.children+1]=faction end elseif #container.children > 0 then node.children[#node.children + 1] = container end
            end
        end
        if #node.children > 0 then nodes[#nodes + 1] = node end
    end
    local facts = {}
    for _, character in ipairs(characters) do
        local snapshot = Snapshot(character)
        local trustworthy = snapshot and (tonumber(snapshot.schemaVersion) or 0) >= 3
        for id, data in pairs((trustworthy and snapshot.data and snapshot.data.factions) or {}) do
            local stableID = tonumber(type(data) == "table" and data.factionID) or tonumber(id) or id
            if not facts[stableID] then facts[stableID] = data end
        end
    end
    local function FindExpansion(title)
        for _, node in ipairs(nodes) do if node.title == title then return node end end
        local node = { key="matrix:detected:"..tostring(title), kind="expansion", title=title, children={} }
        nodes[#nodes + 1] = node
        return node
    end
    local function FindCategory(expansionNode, title)
        for _, node in ipairs(expansionNode.children) do if node.kind=="category" and node.title==title then return node end end
        local node = { key=expansionNode.key..":detected:"..tostring(title), kind="category", title=title, children={} }
        expansionNode.children[#expansionNode.children + 1] = node
        return node
    end
    for stableID, data in pairs(facts) do
        if not seen[stableID] then
            seen[stableID] = true
            local metadata = self:ResolveFactionMetadata(stableID, data)
            local expansionNode = FindExpansion(metadata.expansionTitle or "其它")
            local categoryNode = FindCategory(expansionNode, metadata.categoryTitle or "其它阵营")
            local title = self:GetFactionName(stableID,data.name)
            if not string.find(title, "未知声望 ", 1, true) then categoryNode.children[#categoryNode.children + 1] = { key="matrix:faction:"..stableID, kind="faction", factionID=stableID, title=title, icon=self:GetFactionIcon(stableID), children={} } end
        end
    end
    for _, expansionNode in ipairs(nodes) do
        for _, categoryNode in ipairs(expansionNode.children or {}) do
            if categoryNode.kind=="category" and string.find(categoryNode.key,":detected:",1,true) then table.sort(categoryNode.children,function(a,b)return a.title<b.title end) end
        end
    end
    return nodes
end

local function IsOpen(expanded, node)
    if expanded[node.key] ~= nil then return expanded[node.key] end
    if expanded.__all ~= nil then return expanded.__all == true end
    return node.kind == "expansion" and node.key == "matrix:mop"
end
local function Matches(addon, node, characters, filter, query)
    if node.kind ~= "faction" then return true end
    if query ~= "" and not string.find(string.lower(node.title), query, 1, true) then return false end
    if filter == "monitored" then return addon:IsMonitored(node.factionID) end
    return true
end

function Addon:GetMatrixSurfaceRowCount(characters)
    local settings, expanded = self:GetSettings(), self:EnsureDB().matrixExpanded
    local query, filter = string.lower(settings.matrixSearch or ""), settings.matrixFilter or "all"
    local count = 0
    local function Add(node, forced)
        local visible = Matches(self, node, characters, filter, query)
        local childVisible = false
        for _, child in ipairs(node.children or {}) do if Matches(self, child, characters, filter, query) then childVisible = true end end
        if node.kind ~= "faction" and not childVisible and query ~= "" then return end
        if node.kind == "faction" and not visible then return end
        count = count + 1
        if #node.children > 0 and (forced or IsOpen(expanded, node)) then
            for _, child in ipairs(node.children) do Add(child, forced) end
        end
    end
    for _, node in ipairs(self:GetMatrixNodes(characters or {})) do Add(node, query ~= "" or filter ~= "all") end
    return count
end

function Addon:RefreshMatrixView(parent, context)
    local settings, expanded = self:GetSettings(), self:EnsureDB().matrixExpanded
    local inset = Theme:GetMatrixInsets(false)
    if settings.matrixFilter ~= "monitored" then settings.matrixFilter = "all" end
    local toolbar = parent.matrixToolbar; toolbar:ClearAllPoints(); toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, -inset.top); toolbar:SetHeight(Theme.Size.standard)
    if not toolbar.search then
        toolbar.search = CreateFrame("EditBox", nil, toolbar, "BackdropTemplate"); toolbar.search:SetSize(168, Theme.Size.standard); toolbar.search:SetAutoFocus(false); toolbar.search:SetFont(STANDARD_TEXT_FONT, Theme.Font.body, ""); toolbar.search:SetTextInsets(8, 8, 0, 0); toolbar.search:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 }); toolbar.search:SetBackdropColor(Theme.Colors.bg[1],Theme.Colors.bg[2],Theme.Colors.bg[3],1); toolbar.search:SetBackdropBorderColor(Theme.Colors.lineSoft[1],Theme.Colors.lineSoft[2],Theme.Colors.lineSoft[3],1)
        toolbar.search:SetScript("OnTextChanged", function(box, user) if user then settings.matrixSearch = string.lower(box:GetText() or ""); Addon:NotifyChanged() end end)
    end
    toolbar.search:ClearAllPoints(); toolbar.search:SetPoint("LEFT", toolbar, "LEFT"); if toolbar.search:GetText() ~= (settings.matrixSearch or "") then toolbar.search:SetText(settings.matrixSearch or "") end
    local x = 180
    for index, choice in ipairs({ {"all", "全部"}, {"monitored", "已监控"} }) do
        local button = toolbar.filterButtons[index] or Theme:CreateButton(toolbar, 76, choice[2], "secondary"); toolbar.filterButtons[index] = button; button:ClearAllPoints(); button:SetPoint("LEFT", toolbar, "LEFT", x, 0); button:SetText(choice[2]); button:SetState(settings.matrixFilter == choice[1] and "selected" or "default"); button:SetScript("OnClick", function() settings.matrixFilter = choice[1]; Addon:RefreshMatrixView(parent, context) end); x = x + 82
    end
    for index = 3, #toolbar.filterButtons do toolbar.filterButtons[index]:Hide() end
    local function SetAllExpanded(value)
        -- Per-node overrides must not defeat an explicit global command. The
        -- table is tiny compared with the matrix; clearing it is not the
        -- source of the old hitch, which was the full account-page rebuild.
        for key in pairs(expanded) do if key ~= "__all" then expanded[key] = nil end end
        expanded.__all = value
        Addon:RefreshMatrixView(parent, context)
    end
    toolbar.expand = toolbar.expand or Theme:CreateButton(toolbar, 84, "全部展开", "secondary"); toolbar.expand:ClearAllPoints(); toolbar.expand:SetPoint("LEFT", toolbar, "LEFT", x + 4, 0); toolbar.expand:SetScript("OnClick", function() SetAllExpanded(true) end)
    toolbar.collapse = toolbar.collapse or Theme:CreateButton(toolbar, 84, "全部折叠", "secondary"); toolbar.collapse:ClearAllPoints(); toolbar.collapse:SetPoint("LEFT", toolbar.expand, "RIGHT", 6, 0); toolbar.collapse:SetScript("OnClick", function() SetAllExpanded(false) end)
    parent.matrixHeader:ClearAllPoints(); parent.matrixHeader:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); parent.matrixHeader:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset.right, 0); parent.matrixHeader:SetHeight(Theme.Table.headerHeight)
    parent.matrixScroll:ClearAllPoints(); parent.matrixScroll:SetPoint("TOPLEFT", parent.matrixHeader, "BOTTOMLEFT", 0, Theme.Space.xxs); parent.matrixScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local nameWidth, characterWidth, starWidth = 220, 68, 20
    local allCharacters = context.characters or {}
    local availableWidth = parent.matrixHeader:GetWidth() or parent:GetWidth() or 1
    local characters, pageInfo = Core.AccountView:GetColumnPage("reputation", "matrix", allCharacters, availableWidth, nameWidth, characterWidth)
    if pageInfo.pages > 1 then
        characters, pageInfo = Core.AccountView:GetColumnPage("reputation", "matrix", allCharacters, availableWidth - Core.AccountView:GetColumnPagerWidth(), nameWidth, characterWidth)
    end
    Core.AccountView:UpdateColumnPager(parent, "reputation", "matrix", pageInfo, parent.matrixHeader)
    local columns = { { title="声望", width=nameWidth } }
    for _, character in ipairs(characters) do columns[#columns + 1] = { title=Core.Characters:GetDisplayName(character, "short") or "未知", width=characterWidth, character=character } end
    local tableWidth = 0
    for index, column in ipairs(columns) do local header = parent.matrixHeaders[index] or Text(parent.matrixHeader, Theme.Font.assist, Theme.Colors.accent, index == 1 and "LEFT" or "CENTER"); parent.matrixHeaders[index] = header; header:ClearAllPoints(); header:SetPoint("LEFT", parent.matrixHeader, "LEFT", tableWidth + Theme.Space.xxs + (index == 1 and starWidth or 0), 0); header:SetWidth(column.width - Theme.Space.xs - (index == 1 and starWidth or 0)); header:SetJustifyH(index == 1 and "LEFT" or "CENTER"); header:SetText(column.title); local color = column.character and RAID_CLASS_COLORS and RAID_CLASS_COLORS[column.character.class] or Theme.Colors.accent; header:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3]); header:Show(); tableWidth = tableWidth + column.width end
    for index = #columns + 1, #parent.matrixHeaders do parent.matrixHeaders[index]:Hide() end
    local characterIDs = {}; for _, character in ipairs(characters) do characterIDs[#characterIDs + 1] = character.id end
    local cacheKey = table.concat(characterIDs, "|") .. ":" .. tostring(self._matrixDataRevision or 0)
    if parent.matrixNodeCacheKey ~= cacheKey then parent.matrixNodeCache, parent.matrixNodeCacheKey = self:GetMatrixNodes(characters), cacheKey end
    local query, filter = string.lower(settings.matrixSearch or ""), settings.matrixFilter or settings.defaultMatrixFilter
    local display = {}
    local function Add(node, depth, forced)
        local visible = Matches(self, node, characters, filter, query); local childVisible = false
        for _, child in ipairs(node.children or {}) do if Matches(self, child, characters, filter, query) then childVisible = true end end
        if node.kind ~= "faction" and not childVisible and query ~= "" then return false end
        if node.kind == "faction" and not visible then return false end
        display[#display + 1] = { node=node, depth=depth }
        if #node.children > 0 and (forced or IsOpen(expanded, node)) then for _, child in ipairs(node.children) do Add(child, depth + 1, forced) end end
        return true
    end
    for _, node in ipairs(parent.matrixNodeCache) do Add(node, 0, query ~= "" or filter ~= "all") end
    for rowIndex, entry in ipairs(display) do
        local node, row = entry.node, parent.matrixRows[rowIndex] or CreateFrame("Button", nil, parent.matrixBody, "BackdropTemplate"); parent.matrixRows[rowIndex] = row; row:SetSize(tableWidth, Theme.Table.rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.matrixBody, "TOPLEFT", 0, -((rowIndex-1)*Theme.Table.rowHeight)); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1}); row.matrixNode = node
        local grouped = #node.children > 0; local shade = node.kind == "expansion" and Theme.Colors.selected or (node.kind == "category" and Theme.Colors.toolbar or (rowIndex % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row)); row:SetBackdropColor(shade[1],shade[2],shade[3],shade[4] or 1); row:SetBackdropBorderColor(Theme.Colors.matrixLine[1],Theme.Colors.matrixLine[2],Theme.Colors.matrixLine[3],Theme.Colors.matrixLine[4])
        row.cells = row.cells or {}; row.icon = row.icon or row:CreateTexture(nil,"ARTWORK")
        if not row.star then
            row.star = Theme:CreateButton(row, starWidth, "☆", "secondary"); row.star:SetHeight(24); row.star:EnableMouse(true); row.star:RegisterForClicks("LeftButtonUp"); row.star:SetFrameLevel(row:GetFrameLevel() + 5)
        end
        row.star:ClearAllPoints(); row.star:SetPoint("LEFT", row, "LEFT", 0, 0); row.star:SetShown(node.kind == "faction"); if node.kind == "faction" then local monitored=self:IsMonitored(node.factionID); row.star:SetText(monitored and "★" or "☆"); row.star:SetState(monitored and "selected" or "default"); row.star.factionID=node.factionID; row.star:SetScript("OnClick", function(control) self:ToggleMonitored(control.factionID); Addon:RefreshMatrixView(parent, context) end) end
        local prefix = string.rep("　", entry.depth); local label = prefix .. ((grouped and (IsOpen(expanded,node) and "− " or "+ ")) or "") .. (node.icon and "   " or "") .. node.title; local values = { label }
        if node.kind == "faction" then
            for _, character in ipairs(characters) do local snapshot = Snapshot(character); values[#values + 1] = self:FormatSnapshotValue(snapshot, NodeFaction(snapshot,node), "compact", self:GetFactionState(snapshot,node.factionID)) end
            row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT",row,"LEFT",entry.depth*8+(grouped and 20 or 0),0); if node.icon then row.icon:SetTexture(node.icon);row.icon:Show() else row.icon:Hide() end
            row:SetScript("OnClick", function(control) local current=control.matrixNode;if #(current.children or {})>0 then expanded[current.key]=not IsOpen(expanded,current); Addon:RefreshMatrixView(parent, context) else settings.matrixFocusFactionID=current.factionID end end)
        else row.icon:Hide(); row:SetScript("OnClick", function(control) local current=control.matrixNode;expanded[current.key]=not IsOpen(expanded,current);Addon:RefreshMatrixView(parent, context) end) end
        row.tooltipNode, row.tooltipContext, row.tooltipColumns, row.tooltipColumn = node, { characters = characters }, {}, nil
        row.columnDividers = row.columnDividers or {}; local left=0; for ci,column in ipairs(columns) do row.tooltipColumns[ci]={left=left,width=column.width};local cell=row.cells[ci] or Text(row,Theme.Font.body,Theme.Colors.text,ci==1 and "LEFT" or "CENTER");row.cells[ci]=cell;cell:ClearAllPoints();cell:SetPoint("LEFT",row,"LEFT",left+Theme.Space.xxs+(ci==1 and starWidth or 0),0);cell:SetWidth(column.width-Theme.Space.xs-(ci==1 and starWidth or 0));cell:SetJustifyH(ci==1 and "LEFT" or "CENTER");cell:SetText(values[ci] or "");if node.kind=="faction" and ci>1 then local data=NodeFaction(Snapshot(characters[ci-1]),node);local color=data and self:GetReputationColor(data) or Theme.Colors.muted;cell:SetTextColor(color[1],color[2],color[3]) else cell:SetTextColor(Theme.Colors.text[1],Theme.Colors.text[2],Theme.Colors.text[3]) end;cell:Show();if ci>1 then local divider=row.columnDividers[ci] or row:CreateTexture(nil,"ARTWORK");row.columnDividers[ci]=divider;divider:ClearAllPoints();divider:SetPoint("TOPLEFT",row,"TOPLEFT",left,0);divider:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",left,0);divider:SetWidth(1);divider:SetColorTexture(Theme.Colors.matrixLine[1],Theme.Colors.matrixLine[2],Theme.Colors.matrixLine[3],Theme.Colors.matrixLine[4]);divider:Show() end;left=left+column.width end
        for ci=#columns+1,#row.columnDividers do row.columnDividers[ci]:Hide() end
        if not row.matrixTooltipBound then
            row.matrixTooltipBound=true
            row:SetScript("OnEnter",function(control) UpdateMatrixTooltip(control) end)
            row:SetScript("OnLeave",function(control) control.tooltipColumn=nil;HideMatrixTooltip() end)
        end
        for ci=#columns+1,#row.cells do row.cells[ci]:Hide() end; row:Show()
    end
    for i=#display+1,#parent.matrixRows do parent.matrixRows[i]:Hide() end
    parent.matrixBody:SetSize(tableWidth, math.max(1,#display*Theme.Table.rowHeight)); parent.matrixScroll:SetContentHeight(parent.matrixBody:GetHeight())
end
