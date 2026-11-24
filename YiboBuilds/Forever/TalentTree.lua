local Addon = _G.YiboBuilds
local Theme = _G.YiboCore and _G.YiboCore.UITheme
local Tree = {}
Addon.TalentTree = Tree

local preferredTileSize, minimumTileSize, tileGap, padding = 34, 24, 6, 24

local function PaintNodeTooltip(owner, node, investedRank, description)
    local talents = Addon.Talents
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(talents:GetName(node))
    GameTooltip:AddLine(talents:GetRankText(node, investedRank), unpack(Theme.Colors.muted))
    if description then
        local r, g, b = unpack(Theme.Colors.text)
        GameTooltip:AddLine(description, r, g, b, true)
    else
        GameTooltip:AddLine(Addon:T("FOREVER.TALENT_DESCRIPTION_UNAVAILABLE"), unpack(Theme.Colors.muted))
    end
    GameTooltip:Show()
end

function Tree:HideNodeTooltip(owner)
    if self.hover and self.hover.owner==owner then self.hover=nil end
    if GameTooltip.IsOwned and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

function Tree:ShowNodeTooltip(owner, node, investedRank)
    local talents=Addon.Talents
    local description=talents:GetDescription(node)
    PaintNodeTooltip(owner,node,investedRank,description)
    local hover=self.hover
    if description then self.hover=nil; return end
    if hover and hover.owner==owner and hover.node.id==node.id and hover.node.spellID==node.spellID then
        hover.node,hover.rank=node,investedRank
        return
    end
    self.hover=nil
    if not talents:RequestDescription(node) then return end
    local after=C_Timer and C_Timer.After
    if type(after)~="function" or not GameTooltip.IsOwned then return end
    hover={owner=owner,node=node,rank=investedRank}
    self.hover=hover
    local remaining=8
    local function Refresh()
        if self.hover~=hover then return end
        if not GameTooltip:IsShown() or not GameTooltip:IsOwned(owner)
            or (owner.IsVisible and not owner:IsVisible()) then
            self.hover=nil
            return
        end
        local loaded=talents:GetDescription(hover.node)
        if loaded then
            self.hover=nil
            PaintNodeTooltip(owner,hover.node,hover.rank,loaded)
            return
        end
        remaining=remaining-1
        if remaining>0 then after(0.25,Refresh) end
    end
    after(0.25,Refresh)
end

local function Axis(nodes, key, spacing)
    local values = {}
    for _, node in ipairs(nodes) do values[#values + 1] = node[key] end
    table.sort(values)
    local gap = math.huge
    for index = 2, #values do
        local difference = values[index] - values[index - 1]
        if difference > 0 then gap = math.min(gap, difference) end
    end
    return values[1], values[#values] - values[1], gap < math.huge and spacing / gap or 1
end

local function Layout(tree, width)
    local graph = Addon.Talents:GetGraph(tree)
    if not graph then return nil, "geometry" end
    local minX, spanX, scaleX = Axis(graph, "x", 58)
    local minY, spanY, scaleY = Axis(graph, "y", 54)
    if spanX > 0 then scaleX = math.min(scaleX, (width - 2 * padding) / spanX) end
    if spanY > 0 then scaleY = math.min(scaleY, 1000 / spanY) end
    local left = (width - spanX * scaleX) / 2
    local ranks, positions, nodes = {}, {}, {}
    local tileSize = preferredTileSize
    for _, node in ipairs(tree.nodes) do ranks[node.id] = node.rank end
    for _, node in ipairs(graph) do
        local x, y = left + (node.x - minX) * scaleX, 42 + (node.y - minY) * scaleY
        for _, other in ipairs(nodes) do
            local separation = math.max(math.abs(x - other.x), math.abs(y - other.y))
            tileSize = math.min(tileSize, separation - tileGap)
        end
        local point = { x = x, y = y, rank = ranks[node.id] or 0, node = node }
        nodes[#nodes + 1], positions[node.id] = point, point
    end
    if tileSize < minimumTileSize then return nil, "width" end
    return { title = Addon.Talents:GetTreeTitle(tree), nodes = nodes, positions = positions,
        height = 70 + spanY * scaleY, tileSize = math.floor(tileSize) }
end

local function CreateTile(frame)
    local tile = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    Theme:ApplyPixelBackdrop(tile, { background = false })
    tile:EnableMouse(true)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", 2, -2)
    tile.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    tile.badge = tile:CreateTexture(nil, "OVERLAY")
    tile.badge:SetColorTexture(unpack(Theme.Colors.panel))
    tile.badge:SetSize(16, 15)
    tile.rank = Theme:CreateText(tile, Theme.Font.assist, Theme.Colors.text, "CENTER")
    tile.rank:SetAllPoints(tile.badge)
    tile:SetScript("OnEnter", function(self)
        Tree:ShowNodeTooltip(self, self.point.node, self.point.rank)
    end)
    tile:SetScript("OnLeave", function(self) Tree:HideNodeTooltip(self) end)
    tile:SetScript("OnHide", function(self) Tree:HideNodeTooltip(self) end)
    return tile
end

function Tree:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.tiles, frame.lines, frame.titles = {}, {}, {}
    frame:Hide()
    return frame
end

function Tree:Render(frame, snapshot, width, matches)
    local layouts = {}
    for _, tree in ipairs(snapshot and snapshot.trees or {}) do
        local layout, issue = Layout(tree, width)
        if not layout then frame:Hide(); return nil, nil, issue end
        layouts[#layouts + 1] = layout
    end
    if #layouts == 0 then frame:Hide(); return nil end
    local top, tileCount, lineCount, offsets = 0, 0, 0, {}
    for index, layout in ipairs(layouts) do
        local title = frame.titles[index] or Theme:CreateText(frame, Theme.Font.section, Theme.Colors.text)
        frame.titles[index] = title
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", 4, -top)
        title:SetText(layout.title)
        title:Show()
        local drawn = {}
        for _, point in ipairs(layout.nodes) do
            tileCount = tileCount + 1
            local tile = frame.tiles[tileCount] or CreateTile(frame)
            frame.tiles[tileCount] = tile
            local previous = tile.point
            tile.point = point
            if previous and GameTooltip.IsOwned and GameTooltip:IsOwned(tile) then
                if previous.node.id == point.node.id then
                    self:ShowNodeTooltip(tile, point.node, point.rank)
                else
                    self:HideNodeTooltip(tile)
                end
            end
            tile:ClearAllPoints()
            tile:SetSize(layout.tileSize, layout.tileSize)
            tile:SetPoint("CENTER", frame, "TOPLEFT", point.x, -top - point.y)
            -- The rank badge sits just inside the 1-pixel tile border; Core
            -- re-applies the inset whenever the pixel size changes.
            Theme:SetPixelAnchor(tile.badge, function()
                local inset = Theme:GetPixelSize(tile, 1)
                tile.badge:ClearAllPoints()
                tile.badge:SetPoint("BOTTOMRIGHT", -inset, inset)
            end)
            tile.icon:SetTexture(Addon.Talents:GetIcon(point.node))
            tile.icon:SetDesaturated(point.rank == 0)
            local matched=matches and matches[point.node]
            tile.icon:SetAlpha(matches and not matched and 0.45 or 1)
            tile.rank:SetText(point.rank)
            tile:SetBackdropBorderColor(unpack(matched and Theme.Colors.warning
                or point.rank > 0 and Theme.Colors.accent or Theme.Colors.line))
            if matched then offsets[#offsets+1]={y=top+point.y,x=point.x,tile=tile} end
            tile:Show()
            if frame.CreateLine then
                for _, id in ipairs(point.node.targets) do
                    local target = layout.positions[id]
                    local key = math.min(id, point.node.id) .. ":" .. math.max(id, point.node.id)
                    if target and target ~= point and not drawn[key] then
                        drawn[key] = true
                        lineCount = lineCount + 1
                        local line = frame.lines[lineCount] or frame:CreateLine(nil, "BACKGROUND")
                        frame.lines[lineCount] = line
                        line:SetStartPoint("TOPLEFT", frame, point.x, -top - point.y)
                        line:SetEndPoint("TOPLEFT", frame, target.x, -top - target.y)
                        line:SetThickness(2)
                        line:SetColorTexture(unpack(Theme.Colors.muted))
                        line:Show()
                    end
                end
            end
        end
        top = top + layout.height
    end
    for index = #layouts + 1, #frame.titles do frame.titles[index]:Hide() end
    for index = tileCount + 1, #frame.tiles do frame.tiles[index]:Hide() end
    for index = lineCount + 1, #frame.lines do frame.lines[index]:Hide() end
    frame:Show()
    table.sort(offsets,function(a,b) return a.y<b.y or a.y==b.y and a.x<b.x end)
    return top, offsets
end
