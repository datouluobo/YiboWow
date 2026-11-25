local Addon,Core=_G.YiboBuilds,_G.YiboCore or {}
local Page,Theme={},Core.UITheme; Addon.AccountPage=Page
local EquipmentView = Addon.EquipmentView
local slotKeys={"FOREVER.SLOT_HEAD","FOREVER.SLOT_NECK","FOREVER.SLOT_SHOULDER","FOREVER.SLOT_SHIRT","FOREVER.SLOT_CHEST","FOREVER.SLOT_WAIST","FOREVER.SLOT_LEGS","FOREVER.SLOT_FEET","FOREVER.SLOT_WRIST","FOREVER.SLOT_HANDS","FOREVER.SLOT_FINGER1","FOREVER.SLOT_FINGER2","FOREVER.SLOT_TRINKET1","FOREVER.SLOT_TRINKET2","FOREVER.SLOT_BACK","FOREVER.SLOT_MAINHAND","FOREVER.SLOT_OFFHAND","FOREVER.SLOT_RANGED","FOREVER.SLOT_TABARD"}
local weaponSlots = { 16, 17, 18 }
local slotOrder, slotPositions = EquipmentView.PaperDollSlots(weaponSlots)
local labelIDs = { "slot", "item" }
local function TalentMatches(snapshot, query)
    if not query then return end
    local matches = {}
    for _, tree in ipairs(snapshot and snapshot.trees or {}) do
        for _, node in ipairs(Addon.Talents:GetGraph(tree) or {}) do
            local name = Addon.Talents:GetName(node)
            if name:lower():find(query, 1, true) or tostring(node.id) == query then
                matches[node] = true
            end
        end
    end
    return matches
end

local function JumpToTalent(parent)
    local offsets = parent.talentMatchOffsets
    if not offsets or #offsets==0 then return end
    parent.talentMatchIndex=((parent.talentMatchIndex or 0)%#offsets)+1
    local scroll = parent.scroll
    local match = offsets[parent.talentMatchIndex]
    for _, entry in ipairs(offsets) do
        entry.tile:SetBackdropBorderColor(unpack(entry==match and Theme.Colors.text or Theme.Colors.warning))
    end
    local position = match.y-scroll:GetHeight()/2
    scroll:SetVerticalScroll(math.max(0,math.min(position,scroll:GetVerticalScrollRange())))
end

function Page:Fields() return {{id="slot",title=Addon:T("FOREVER.SLOT"),defaultVisible=true},{id="item",title=Addon:T("FOREVER.ITEM"),defaultVisible=true}} end
function Page:Status(id, mode)
    local _,state=Addon.Store:Get(id or Core.Characters:GetCurrentID(), mode)
    local keys={known="FOREVER.KNOWN",stale="FOREVER.STALE",error="FOREVER.ERROR",unknown="FOREVER.UNKNOWN"}
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
local function SavedItemLabel(item)
    local link = item.itemLink
    if not Addon.Store:Plain(link) or type(link) ~= "string" then return end
    local id, name = link:match("|Hitem:(%d+):[^|]*|h%[([^|]+)%]|h")
    if tonumber(id) ~= item.itemID then return end
    return name
end

local function ItemDisplay(item)
    if item.itemID == 0 then return Addon:T("FOREVER.EMPTY"), nil, Theme.Colors.muted end
    local savedName = SavedItemLabel(item)
    local name = savedName
    local ok,info=pcall(Core.ItemResolver.GetInfo,Core.ItemResolver,item.itemID)
    local icon, quality
    if ok and type(info) == "table" then
        if not name and Addon.Store:Plain(info.name) and type(info.name) == "string" and info.name ~= "" then name = info.name end
        if Addon.Store:Plain(info.icon) then icon = info.icon end
        if Addon.Store:Plain(info.quality) then quality = info.quality end
    end
    local red, green, blue = EquipmentView.ItemQualityColor(savedName and item.itemLink, quality)
    local color = red and {red, green, blue} or nil
    return name or Addon:T("FOREVER.UNCACHED", item.itemID), icon or "Interface\\Icons\\INV_Misc_QuestionMark", color
end

local function ShowItemTooltip(owner, item, slotName, itemName, inspectable)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if not item or item.itemID == 0 or not pcall(GameTooltip.SetHyperlink, GameTooltip, item.itemLink or ("item:" .. item.itemID)) then
        GameTooltip:AddLine(slotName)
        GameTooltip:AddLine(itemName)
    end
    if inspectable then GameTooltip:AddLine(Addon:T("FOREVER.INSPECT_ENHANCEMENT"), unpack(Theme.Colors.muted)) end
    GameTooltip:Show()
end
local function SameItem(before, current)
    return before and current and before.itemID==current.itemID and before.itemLink==current.itemLink
end
local function EnchantDisplay(item, enchant)
    if enchant==nil then return Addon:T("FOREVER.ENHANCEMENT_UNKNOWN") end
    if enchant==0 then return Addon:T("FOREVER.NO_ENCHANT") end
    return Addon.Enhancements:GetEnchantEffect(item,enchant) or Addon:T("FOREVER.ENCHANT_ID",enchant)
end

local function ItemLevel(item, slot)
    if item.itemID == 0 or not item.itemLink or slot == 4 or slot == 19 then return "" end
    local read = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    if not read then return "" end
    local ok, level = pcall(read, item.itemLink)
    if ok and Addon.Store:Plain(level) and type(level) == "number" and level > 0 then
        return string.format("%.0f", level)
    end
    return ""
end

local function OpenEnhancement(parent, slot)
    parent.detailSlot = parent.detailSlot ~= slot and slot or nil
    parent.jumpToDetail = parent.detailSlot ~= nil
    GameTooltip:Hide()
    Page:Refresh(parent, parent.context)
end

local function CreateSlot(doll, parent, slot, side)
    local button = CreateFrame("Button", nil, doll, "BackdropTemplate")
    Theme:ApplyPixelBackdrop(button)
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    local weapon = slot >= 16 and slot <= 18
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.iconFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.iconFrame:SetAllPoints(button.icon)
    Theme:ApplyPixelBackdrop(button.iconFrame, {background=false})
    button.level = EquipmentView.CreatePaperDollItemLevel(button.iconFrame)
    button.enchant = CreateFrame("Button", nil, button.iconFrame, "BackdropTemplate")
    button.enchant:SetSize(18, 18)
    if (weapon and slot ~= 16) or (not weapon and side == "LEFT") then button.enchant:SetPoint("BOTTOMLEFT", button.iconFrame, "BOTTOMRIGHT", 3, 0)
    else button.enchant:SetPoint("BOTTOMRIGHT", button.iconFrame, "BOTTOMLEFT", -3, 0) end
    Theme:ApplyPixelBackdrop(button.enchant, {background=false})
    button.enchant:SetBackdropBorderColor(unpack(Theme.Colors.accent))
    button.enchant.icon = button.enchant:CreateTexture(nil, "ARTWORK")
    button.enchant.icon:SetAllPoints()
    button.enchant.icon:SetTexture("Interface\\Icons\\INV_Enchant_DustStrange")
    button.enchant:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(Addon:T("FOREVER.ENCHANT"))
        GameTooltip:AddLine(EnchantDisplay(button.item, button.enchantID), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button.enchant:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button.enchant:SetScript("OnHide", button.enchant:GetScript("OnLeave"))
    button.enchant:SetScript("OnClick", function() OpenEnhancement(parent, slot) end)
    button.slotLabel = EquipmentView.CreateSlotLabel(button)
    button.slotLabel:SetText(Addon:T(slotKeys[slot]))
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.alternate))
        ShowItemTooltip(self, self.item, self.slotLabel:GetText(), self.itemName, self.item and self.item.itemID>0)
    end)
    button:SetScript("OnClick", function(self)
        if self.item and self.item.itemID>0 then OpenEnhancement(parent,slot) end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
    end)
    button:SetScript("OnHide", function(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    doll.slots[slot] = button
end
local function CreateDoll(content, parent)
    local doll = EquipmentView.CreateEquipmentPane(content)
    doll.slots = {}
    for _, slot in ipairs(slotOrder) do
        CreateSlot(doll, parent, slot, slotPositions[slot].side == "right" and "RIGHT" or "LEFT")
    end
    local appearance = CreateFrame("Frame", nil, doll)
    doll.appearance = appearance
    local ok, model = pcall(CreateFrame, "DressUpModel", nil, appearance)
    if ok and type(model.SetUnit) == "function" then
        doll.model = model
        model:EnableMouse(false)
        doll.modelControl = EquipmentView.CreateModelControl(appearance, model)
    elseif ok then
        model:Hide()
    end
    doll.appearanceTitle = Theme:CreateText(appearance, Theme.Font.assist, Theme.Colors.muted, "CENTER")
    doll.appearanceTitle:SetPoint("TOPLEFT", 4, -4)
    doll.appearanceTitle:SetPoint("TOPRIGHT", -4, -4)
    doll.appearanceTitle:SetHeight(18)
    doll.appearanceTitle:SetText(Addon:T("FOREVER.LIVE_APPEARANCE"))
    doll.appearanceToggle = EquipmentView.CreateAppearanceToggle(appearance)
    doll.appearanceToggle:SetPoint("TOP", 0, -3)
    doll.appearanceToggle:SetFrameLevel((doll.modelControl or appearance):GetFrameLevel() + 1)
    doll.appearanceToggle:SetScript("OnClick", function()
        doll.original = not doll.original
        Page:Refresh(parent, parent.context)
    end)
    doll.appearanceFallback = Theme:CreateText(appearance, Theme.Font.body, Theme.Colors.muted, "CENTER")
    doll.appearanceFallback:SetPoint("LEFT", 12, 0)
    doll.appearanceFallback:SetPoint("RIGHT", -12, 0)
    doll.appearanceFallback:SetText(Addon:T("FOREVER.MODEL_UNAVAILABLE"))
    doll:Hide()
    return doll
end
local function SameEquipment(previous, current)
    if not previous or not current then return false end
    for slot, item in ipairs(current.slots) do
        if not SameItem(previous.slots[slot], item) then return false end
    end
    return true
end

local function RenderDoll(doll, width, height, snapshot, modelSource, detailSlot)
    local layout = EquipmentView.GetPaperDollLayout(width, height)
    doll.appearance:SetAllPoints(doll)
    EquipmentView.LayoutModel(doll.appearance, doll.model, doll.modelControl, doll.appearanceToggle, layout)
    for slot, button in pairs(doll.slots) do
        local position = slotPositions[slot]
        EquipmentView.AnchorEquipmentSlot(button, layout, position.side, position.index, #weaponSlots)
        local item = snapshot.slots[slot]
        if not SameItem(button.item,item) and GameTooltip.IsOwned
            and (GameTooltip:IsOwned(button) or GameTooltip:IsOwned(button.enchant)) then GameTooltip:Hide() end
        button.item = item
        local name, icon, color = ItemDisplay(item)
        button.itemName = name
        button.icon:SetTexture(icon)
        button.iconFrame:SetBackdropBorderColor(unpack(detailSlot == slot and Theme.Colors.accent or color or Theme.Colors.line))
        EquipmentView.RenderPaperDollItemLevel(button.level, ItemLevel(item, slot), layout.iconSize)
        button.enchantID = Addon.Enhancements:Read(item)
        button.enchant:SetShown((button.enchantID or 0) > 0)
    end
    local model = doll.model
    local showToggle = model and modelSource and type(model.TryOn) == "function"
    doll.appearanceToggle:SetShown(not not showToggle)
    doll.appearanceTitle:SetShown(not showToggle)
    doll.appearanceToggle:SetText(Addon:T(doll.original and "FOREVER.APPEARANCE_ORIGINAL" or "FOREVER.APPEARANCE_TRANSMOG"))
    local original = showToggle and doll.original or false
    if model and modelSource and (model.snapshot ~= modelSource or model.original ~= original) then
        if model.original == original and SameEquipment(model.snapshot, modelSource) then
            model.snapshot = modelSource
        else
            if model.ClearModel then pcall(model.ClearModel, model) end
            local ok, result = pcall(model.SetUnit, model, "player")
            model.snapshot = ok and result ~= false and modelSource or nil
            model.original = original
            if model.snapshot and original then
                for _, item in ipairs(modelSource.slots) do
                    if item.itemLink then pcall(model.TryOn, model, item.itemLink) end
                end
            end
            EquipmentView.RestoreModelView(model)
        end
    end
    if model then model:SetShown(modelSource ~= nil and model.snapshot == modelSource) end
    local showingModel = model and modelSource ~= nil and model.snapshot == modelSource
    if doll.modelControl then doll.modelControl:SetShown(not not showingModel) end
    doll.appearanceFallback:SetShown(not showingModel)
end
function Page:Create(parent)
    parent.roster = EquipmentView.CreateCharacterSelector(parent, Addon:T("FOREVER.CHARACTERS"), function(id)
        parent.selectedCharacterID = id
        parent.scroll:SetVerticalScroll(0)
        Page:Refresh(parent, parent.context)
    end)
    parent.heading=Theme:CreateText(parent,Theme.Font.section,Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT",12,-10); parent.heading:SetPoint("RIGHT",-130,0); parent.heading:SetHeight(26)
    parent.refresh=Theme:CreateButton(parent,100,Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT",-12,-10)
    parent.refresh:SetScript("OnClick",function()
        if parent.buildMode == "backup" or parent.selectedCharacterID ~= Core.Characters:GetCurrentID() then return end
        if parent.showTalents then Addon.Talents:Scan() else Addon.Scanner:Scan(true) end
        if parent.showCombined then Addon.Talents:Scan() end
    end)
    parent.saveNow = Theme:CreateButton(parent, 108, Addon:T("FOREVER.SAVE_EQUIPMENT_NOW"))
    parent.saveNow:SetScript("OnClick", function()
        if not parent.saveConfig or parent.selectedCharacterID ~= Core.Characters:GetCurrentID() then return end
        if not Addon.Scanner:Scan(true, parent.saveConfig) then
            Addon:Print(Addon:T("FOREVER.SAVE_EQUIPMENT_FAILED"))
        end
    end)
    parent.saveNow:Hide()
    parent.buildModeButton = Theme:CreateButton(parent, 112, "")
    parent.buildModeButton:SetPoint("RIGHT", parent.refresh, "LEFT", -6, 0)
    parent.buildModeButton:SetScript("OnClick", function()
        parent.buildMode = parent.buildMode == "backup" and "current" or "backup"
        parent.detailSlot = nil
        parent.scroll:SetVerticalScroll(0)
        Page:Refresh(parent, parent.context)
    end)
    parent.talentsTab=Theme:CreateButton(parent,76,Addon:T("FOREVER.TALENTS"))
    parent.talentsTab:SetPoint("TOPRIGHT",-12,-48)
    parent.equipmentTab=Theme:CreateButton(parent,76,Addon:T("FOREVER.EQUIPMENT"))
    parent.equipmentTab:SetPoint("RIGHT",parent.talentsTab,"LEFT",-6,0)
    parent.tabs={equipment=parent.equipmentTab, talents=parent.talentsTab}
    for tab, button in pairs(parent.tabs) do
        button:SetScript("OnClick",function()
            parent.selectedTab=tab
            parent.detailSlot = nil
            Page:Refresh(parent,parent.context)
        end)
    end
    parent.status=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT",12,-48); parent.status:SetPoint("RIGHT",-12,0); parent.status:SetHeight(42)
    parent.talentSearch=Theme:CreateInput(parent,{
        width=180,placeholder=Addon:T("FOREVER.TALENT_SEARCH"),clearable=true,
        OnChanged=function(value)
            local query=value:match("^%s*(.-)%s*$"):lower()
            query=query~="" and query or nil
            if parent.talentQuery==query then return end
            parent.talentQuery,parent.talentMatchIndex,parent.talentSearchJump=query,0,true
            if parent.context then Page:Refresh(parent,parent.context) end
        end,
        OnSubmit=function() JumpToTalent(parent) end,
    })
    parent.talentSearch:SetPoint("TOPLEFT",12,-95)
    parent.talentNext=Theme:CreateButton(parent,105,Addon:T("FOREVER.TALENT_NEXT_MATCH"))
    parent.talentNext:SetPoint("TOPRIGHT",-12,-128)
    parent.talentNext:SetScript("OnClick",function() JumpToTalent(parent) end)
    parent.talentSearchCount=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.talentSearchCount:SetHeight(28)
    parent.talentTreeHint = Theme:CreateText(parent, Theme.Font.body, Theme.Colors.muted)
    parent.talentTreeHint:SetPoint("TOPLEFT", 12, -134)
    parent.talentTreeHint:SetPoint("TOPRIGHT", -12, -134)
    parent.talentTreeHint:SetHeight(32)
    parent.talentTreeHint:Hide()
    parent.talentSearch:Hide(); parent.talentNext:Hide(); parent.talentSearchCount:Hide()
    parent.header=CreateFrame("Frame",nil,parent); parent.header:SetPoint("TOPLEFT",12,-96); parent.header:SetPoint("TOPRIGHT",-12,-96); parent.header:SetHeight(26)
    parent.scroll=Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT",12,-126); parent.scroll:SetPoint("BOTTOMRIGHT",-12,10)
    parent.content=CreateFrame("Frame",nil,parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.doll = CreateDoll(parent.content,parent)
    parent.talentTree = Addon.TalentTree:Create(parent.content)
    parent.talentHeading = Theme:CreateText(parent.content, Theme.Font.section, Theme.Colors.text)
    parent.talentHeading:SetText(Addon:T("FOREVER.TALENTS"))
    parent.talentHeading:SetHeight(28)
    parent.talentHeading:Hide()
    local detail = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
    parent.slotDetail = detail
    Theme:ApplyPixelBackdrop(detail)
    detail:SetBackdropColor(unpack(Theme.Colors.panel))
    detail.icon = detail:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(38, 38)
    detail.icon:SetPoint("TOPLEFT", 12, -12)
    detail.close = Theme:CreateButton(detail, 68, Addon:T("FOREVER.CLOSE_DETAIL"))
    detail.close:SetPoint("TOPRIGHT", -12, -12)
    detail.close:SetScript("OnClick", function()
        parent.detailSlot = nil
        parent.scroll:SetVerticalScroll(0)
        Page:Refresh(parent, parent.context)
    end)
    detail.slot = Theme:CreateText(detail, Theme.Font.assist, Theme.Colors.muted)
    detail.slot:SetPoint("TOPLEFT", 60, -12)
    detail.slot:SetPoint("RIGHT", detail.close, "LEFT", -8, 0)
    detail.slot:SetWordWrap(false)
    detail.item = Theme:CreateText(detail, Theme.Font.section, Theme.Colors.text)
    detail.item:SetPoint("TOPLEFT", 60, -31)
    detail.item:SetPoint("RIGHT", detail.close, "LEFT", -8, 0)
    detail.item:SetWordWrap(false)
    detail.enchant = Theme:CreateText(detail, Theme.Font.assist, Theme.Colors.muted)
    detail.enchant:SetPoint("TOPLEFT", 12, -66)
    detail.enchant:SetText(Addon:T("FOREVER.ENCHANT"))
    detail.effect = Theme:CreateText(detail, Theme.Font.body, Theme.Colors.text)
    detail.effect:SetPoint("TOPLEFT", 12, -86)
    detail.effect:SetPoint("TOPRIGHT", -12, -86)
    detail.effect:SetWordWrap(true)
    detail.candidateHeading = Theme:CreateText(detail, Theme.Font.section, Theme.Colors.text)
    detail.candidateHeading:SetText(Addon:T("FOREVER.ENCHANT_CANDIDATES"))
    detail.candidateStatus = Theme:CreateText(detail, Theme.Font.assist, Theme.Colors.muted)
    detail.candidateStatus:SetWordWrap(true)
    detail.candidateRows = {}
    detail:Hide()
    parent.collapseTalents = Theme:CreateButton(parent, 106, Addon:T("FOREVER.HIDE_TALENTS"))
    parent.collapseTalents:SetPoint("RIGHT", parent.equipmentTab, "LEFT", -6, 0)
    parent.collapseTalents:SetScript("OnClick", function()
        parent.talentsCollapsed = not parent.talentsCollapsed
        Page:Refresh(parent, parent.context)
    end)
    parent.labels,parent.rows={},{}
    for _,id in ipairs(labelIDs) do parent.labels[id]=Theme:CreateText(parent.header,Theme.Font.assist,Theme.Colors.muted) end
    parent.scroll:HookScript("OnVerticalScroll",function() Page:PaintRows(parent) end)
    parent.scroll:HookScript("OnSizeChanged",function(scroll)
        if parent.layoutInProgress then return end
        if parent.context and parent:IsShown()
            and (parent.scrollWidth ~= scroll:GetWidth() or parent.scrollHeight ~= scroll:GetHeight()) then
            Page:Refresh(parent, parent.context)
        else
            Page:PaintRows(parent)
        end
    end)
end

local function Layout(container,labels,columns)
    for _,label in pairs(labels) do label:Hide() end
    for _,column in ipairs(columns) do local label=labels[column.id]; label:ClearAllPoints(); label:SetPoint("TOPLEFT",container,"TOPLEFT",column.x,0); label:SetSize(column.width,30); label:Show() end
end

local previewSlots = {1,3,5,10,7,9,6,8,2,15,11,12,13,14,16,17,19,4,18}
local previewCaptions = {
    [3]="FOREVER.PREVIEW_SHOULDER", [9]="FOREVER.PREVIEW_WRIST",
    [11]="FOREVER.PREVIEW_RING1", [12]="FOREVER.PREVIEW_RING2",
    [13]="FOREVER.PREVIEW_TRINKET1", [14]="FOREVER.PREVIEW_TRINKET2",
    [16]="FOREVER.PREVIEW_MAINHAND", [17]="FOREVER.PREVIEW_OFFHAND",
}
local previewGaps = {[7]=true, [8]=true, [15]=true, [14]=true, [18]=true}

local function PreviewFieldID(slot)
    return "equipment-slot-" .. slot
end

local function CreatePreviewCell(parent, open)
    local cell = CreateFrame("Button", nil, parent)
    EquipmentView.CreatePreviewItem(cell)
    cell:SetScript("OnClick", function() open(parent.characterID) end)
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(self)
        ShowItemTooltip(self, self.item, self.slotName, self.itemName)
        if self.itemChanged:IsShown() then
            GameTooltip:AddLine(Addon:T("FOREVER.SLOT_CHANGED"), unpack(Theme.Colors.warning))
            GameTooltip:Show()
        end
    end)
    local function HideTooltip(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    cell:SetScript("OnLeave", HideTooltip)
    cell:SetScript("OnHide", HideTooltip)
    return cell
end

local previewModes = {
    {"current", "equipment", "FOREVER.CURRENT_EQUIPMENT"},
    {"backup", "equipment", "FOREVER.BACKUP_EQUIPMENT"},
    {"current", "talents", "FOREVER.CURRENT_TALENTS"},
    {"backup", "talents", "FOREVER.BACKUP_TALENTS"},
}

local function PreviewModeButtons()
    local options = {}
    for index, option in ipairs(previewModes) do
        options[index] = {id=index, label=Addon:T(option[3])}
    end
    return options
end

local backupEmpty = {equipment="FOREVER.NO_BACKUP_EQUIPMENT", talents="FOREVER.NO_BACKUP_TALENTS"}

local function RenderPreviewTalents(row, snapshot, start, width, open)
    row.talentCells = row.talentCells or {}
    local count, shown, points = 0, 0, 0
    local room = math.max(0, math.floor((width - 100) / 30))
    for _, tree in ipairs(snapshot.trees) do
        points = points + tree.points
        local graph = {}
        for _, node in ipairs(Addon.Talents:GetGraph(tree) or {}) do graph[node.id] = node end
        for _, entry in ipairs(tree.nodes) do
            count = count + 1
            if shown < room then
                shown = shown + 1
                local cell = row.talentCells[shown]
                if not cell then
                    cell = CreateFrame("Button", nil, row, "BackdropTemplate")
                    cell:SetSize(26, 26)
                    Theme:ApplyPixelBackdrop(cell, {background=false})
                    cell.icon = cell:CreateTexture(nil, "ARTWORK")
                    cell.icon:SetAllPoints()
                    cell.rankText = Theme:CreateText(cell, Theme.Font.assist, Theme.Colors.text, "RIGHT")
                    cell.rankText:SetPoint("BOTTOMRIGHT", -1, 1)
                    cell:SetScript("OnClick", function() open(row.characterID) end)
                    cell:SetScript("OnEnter", function(self) Addon.TalentTree:ShowNodeTooltip(self, self.node, self.rank) end)
                    cell:SetScript("OnLeave", function(self) Addon.TalentTree:HideNodeTooltip(self) end)
                    cell:SetScript("OnHide", cell:GetScript("OnLeave"))
                    row.talentCells[shown] = cell
                end
                local node = graph[entry.id] or entry
                if cell.node ~= node then Addon.TalentTree:HideNodeTooltip(cell) end
                cell.node, cell.rank = node, entry.rank
                cell:SetPoint("LEFT", row, "LEFT", start + (shown - 1) * 30, 0)
                cell.icon:SetTexture(Addon.Talents:GetIcon(node))
                cell.rankText:SetText(entry.rank)
                cell:Show()
            end
        end
    end
    for index = shown + 1, #row.talentCells do row.talentCells[index]:Hide() end
    return Addon:T("FOREVER.PREVIEW_POINTS", points, count), shown * 30
end

function Page:RefreshEquipmentPreview(parent, context)
    local previewRowHeight = EquipmentView.EquipmentPreviewRowHeight()
    if not parent.previewHeader then
        parent.previewHeader = CreateFrame("Frame", nil, parent)
        parent.previewHeader:SetFrameLevel(parent.scroll:GetFrameLevel() + 2)
        parent.previewRows = {}
        parent.previewModeStrip = CreateFrame("Frame", nil, parent)
    end
    local chosen = self.previewMode or 1
    local mode, kind = unpack(previewModes[chosen])
    EquipmentView.RenderPreviewModes(parent.previewModeStrip, PreviewModeButtons(), chosen, function(option)
        self.previewMode = option.id
        parent.scroll:SetVerticalScroll(0)
        self:Refresh(parent, parent.context)
    end, context)
    local inset = Theme:GetMatrixInsets(true)
    parent.previewHeader:ClearAllPoints()
    parent.previewHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    parent.previewHeader:Show()
    parent.heading:Hide()
    parent.roster:Hide()
    parent.roster.picker:Hide()
    parent.talentHeading:Hide()
    parent.slotDetail:Hide()
    parent.collapseTalents:Hide()
    parent.status:Hide()
    parent.refresh:Hide()
    parent.saveNow:Hide()
    parent.buildModeButton:Hide()
    parent.header:Hide()
    parent.doll:Hide()
    parent.talentTree:Hide()
    parent.talentTreeHint:Hide()
    parent.talentSearch:Hide()
    parent.talentNext:Hide()
    parent.talentSearchCount:Hide()
    for _, button in pairs(parent.tabs) do button:Hide() end
    for _, row in ipairs(parent.rows) do row:Hide() end
    parent.showTalents = false
    parent.activeTab = "equipment"
    parent.scroll:ClearAllPoints()
    parent.scroll:SetPoint("TOPLEFT", parent.previewHeader, "BOTTOMLEFT", 0, 0)
    parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)

    local width = math.max(1, (context.surfaceAvailableWidth or parent.scrollWidth) - 28)
    local nameWidth = math.min(170, math.floor(width * 0.23))
    local visibleSlots = {}
    local preferences = Addon.Store.db.settings.previewColumns
    if kind == "equipment" then
        for _, slot in ipairs(previewSlots) do
            if preferences[PreviewFieldID(slot)] ~= false then visibleSlots[#visibleSlots + 1] = slot end
        end
    end
    local characters = context.characters or {}
    local columns = {{id="character", title=#characters == 0 and Addon:T("FOREVER.UNKNOWN") or Core:Text("CORE.CHARACTER"), width=nameWidth}}
    if kind == "talents" then
        columns[#columns + 1] = {id="talents", title=Addon:T("FOREVER.TALENTS"), width=width-nameWidth}
    end
    for _, slot in ipairs(visibleSlots) do
        columns[#columns + 1] = {id=slot, title=Addon:T(previewCaptions[slot] or slotKeys[slot]), gapAfter=previewGaps[slot]}
    end
    if kind == "equipment" then EquipmentView.FitEquipmentColumns(columns, width) end
    nameWidth = columns[1].width
    width = EquipmentView.RenderPreviewHeader(parent.previewHeader, columns)

    local count = 0
    local function Open(characterID)
        local option = previewModes[self.previewMode or 1]
        self.requestedBuild = {id=characterID, mode=option[1], tab=option[2]}
        if Core.AccountView:Toggle(Addon.PAGE_ID) == false then self.requestedBuild = nil end
    end
    for _, character in ipairs(characters) do
        local snapshot = Addon.Store:ReadSnapshot(character.id, kind, mode)
        count = count + 1
        local row = parent.previewRows[count]
        if not row then
            row = CreateFrame("Button", nil, parent.content)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row:SetScript("OnClick", function(self) Open(self.characterID) end)
            row.name = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
            row.name:SetPoint("LEFT", 2, 0)
            row.name:SetWordWrap(false)
            row.summary = Theme:CreateText(row, Theme.Font.assist, Theme.Colors.muted, "LEFT")
            row.summary:SetWordWrap(false)
            row.cells = {}
            parent.previewRows[count] = row
        end
        row:SetPoint("TOPLEFT", 0, -(count - 1) * previewRowHeight)
        row.characterID = character.id
        row:SetSize(width, previewRowHeight)
        row.background:SetColorTexture(unpack(Theme:GetDataRowColor(count)))
        row.name:SetWidth(math.max(1, nameWidth - 4))
        local level = mode == "current" and character.profile and character.profile.itemLevel
        local name = Core.Characters:FormatName(character, {realmMode = context.scope == "all" and "full" or "omit"})
        row.name:SetText(type(level) == "number" and level > 0 and string.format("%s [%.0f]", name, level) or name)
        local store = Addon.Store
        local _, activeConfig = store:Configuration(character.id)
        local changes
        if mode == "current" and kind == "equipment" then
            if activeConfig then
                local _, _, changedSlots = store:EquipmentSaveState(character.id)
                changes = changedSlots
            elseif store.changedSlots then
                changes = store.changedSlots[character.id]
            end
        end
        for slot, cell in pairs(row.cells) do
            if not snapshot or kind ~= "equipment" or preferences[PreviewFieldID(slot)] == false then cell:Hide() end
        end
        if not snapshot or kind ~= "talents" then
            for _, cell in ipairs(row.talentCells or {}) do cell:Hide() end
        end
        if snapshot and kind == "equipment" then
            row.summary:Hide()
            for index, slot in ipairs(visibleSlots) do
                local cell = row.cells[slot] or CreatePreviewCell(row, Open)
                row.cells[slot] = cell
                local item = snapshot.slots[slot]
                if GameTooltip.IsOwned and GameTooltip:IsOwned(cell) and not SameItem(cell.item, item) then GameTooltip:Hide() end
                local name, icon, color = ItemDisplay(item)
                cell.item, cell.slotName, cell.itemName = item, Addon:T(slotKeys[slot]), name
                local column = columns[index + 1]
                cell:SetPoint("LEFT", row, "LEFT", column.x, 0)
                cell:SetSize(column.width, previewRowHeight)
                EquipmentView.RenderPreviewItem(cell, math.max(1, math.min(32, column.width - 3)),
                    icon, color or Theme.Colors.line, ItemLevel(item, slot), changes and changes[slot])
                cell:Show()
            end
        else
            local summary, used
            if snapshot then
                summary, used = RenderPreviewTalents(row, snapshot, nameWidth, width-nameWidth, Open)
            else
                summary = Addon:T(mode == "backup" and backupEmpty[kind] or "FOREVER.UNKNOWN")
            end
            row.summary:SetPoint("LEFT", row, "LEFT", nameWidth + (used or 0), 0)
            row.summary:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.summary:SetText(summary)
            row.summary:Show()
        end
        row:Show()
    end
    for index = count + 1, #parent.previewRows do parent.previewRows[index]:Hide() end
    parent.content:SetSize(width, math.max(1, count * previewRowHeight))
    parent.scroll:SetContentHeight(count * previewRowHeight)
end

local function RenderEnchantCandidates(detail, slot, item, current)
    local top = 100 + detail.effect:GetStringHeight()
    local candidates, unavailable
    if current then candidates, unavailable = Addon.Enhancements:GetCandidates(slot, item.itemLink) end
    detail.candidateHeading:SetShown(current)
    detail.candidateStatus:SetShown(current and not (candidates and #candidates > 0))
    detail.candidateHeading:SetPoint("TOPLEFT", 12, -top)
    if detail.candidateStatus:IsShown() then
        detail.candidateStatus:SetPoint("TOPLEFT", 12, -(top + 26))
        detail.candidateStatus:SetPoint("TOPRIGHT", -12, -(top + 26))
        detail.candidateStatus:SetText(Addon:T(unavailable or "FOREVER.ENCHANT_NO_CANDIDATES"))
    end
    local count = candidates and #candidates or 0
    for index = count + 1, #detail.candidateRows do detail.candidateRows[index]:Hide() end
    local rowTop = top + 28
    local materialInfo = {}
    for index, candidate in ipairs(candidates or {}) do
        local row = detail.candidateRows[index]
        if not row then
            row = CreateFrame("Frame", nil, detail)
            row.name = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
            row.name:SetPoint("TOPLEFT", 0, -6)
            row.name:SetWordWrap(false)
            row.action = Theme:CreateButton(row, 118, "")
            row.action:SetPoint("TOPRIGHT", 0, 0)
            row.name:SetPoint("TOPRIGHT", row.action, "TOPLEFT", -8, -6)
            row.materials = Theme:CreateText(row, Theme.Font.assist, Theme.Colors.muted)
            row.materials:SetPoint("TOPLEFT", 0, -34)
            row.materials:SetPoint("TOPRIGHT", -4, -34)
            row.materials:SetWordWrap(true)
            row.action:SetScript("OnClick", function()
                local enchant = Addon.Enhancements
                local apply = row.candidate.ready and enchant.Apply or enchant.OpenRecipe
                if not apply(enchant, row.slot, row.itemLink, row.candidate) then
                    Addon:Print(Addon:T("FOREVER.ENCHANT_ACTION_UNAVAILABLE"))
                end
            end)
            detail.candidateRows[index] = row
        end
        row:SetPoint("TOPLEFT", 12, -rowTop)
        row:SetPoint("TOPRIGHT", -12, -rowTop)
        row.slot, row.itemLink, row.candidate = slot, item.itemLink, candidate
        row.name:SetText(candidate.name)
        row.action:SetText(Addon:T(candidate.ready and "FOREVER.ENCHANT_APPLY" or "FOREVER.ENCHANT_OPEN_RECIPE"))
        local lines = {}
        for _, material in ipairs(candidate.materials) do
            local cached = materialInfo[material.id]
            if not cached then
                local info = Core.ItemResolver:GetInfo(material.id)
                cached = {
                    name=info and Addon.Store:Plain(info.name) and info.name or Addon:T("FOREVER.UNCACHED", material.id),
                    carried=Addon.Enhancements:ReadCarriedMaterial(material.id),
                }
                materialInfo[material.id] = cached
            end
            if cached.carried == nil then
                lines[#lines + 1] = Addon:T("FOREVER.ENCHANT_MATERIAL_UNKNOWN", cached.name, material.quantity)
            else
                local key = cached.carried < material.quantity and "FOREVER.ENCHANT_MATERIAL_SHORT" or "FOREVER.ENCHANT_MATERIAL"
                lines[#lines + 1] = Addon:T(key, cached.name, cached.carried, material.quantity)
            end
        end
        if candidate.needsNativeMaterials then lines[#lines + 1] = Addon:T("FOREVER.ENCHANT_MATERIAL_NATIVE") end
        row.materials:SetText(table.concat(lines, "\n"))
        row.materials:SetShown(#lines > 0)
        row:Show()
        local height = #lines > 0 and 38 + row.materials:GetStringHeight() or 32
        row:SetHeight(height)
        rowTop = rowTop + height + 6
    end
    if current then
        if count > 0 then return rowTop + 6 end
        return top + 36 + detail.candidateStatus:GetStringHeight()
    end
    return top
end

function Page:Refresh(parent,context)
    parent.layoutInProgress = true
    local previousContext = parent.context
    parent.context = context
    parent.scrollWidth, parent.scrollHeight = parent.scroll:GetWidth(), parent.scroll:GetHeight()
    if previousContext and previousContext.preview ~= context.preview then parent.scroll:SetVerticalScroll(0) end
    if context.preview then
        self:RefreshEquipmentPreview(parent, context)
        parent.scrollWidth, parent.scrollHeight = parent.scroll:GetWidth(), parent.scroll:GetHeight()
        parent.layoutInProgress = nil
        return
    end
    if parent.previewHeader then
        parent.previewHeader:Hide()
        parent.previewModeStrip:Hide()
        for _, row in ipairs(parent.previewRows) do row:Hide() end
    end
    parent.heading:Show()
    parent.status:Show()
    local requested = self.requestedBuild
    local characters = context.characters or {}
    local character = EquipmentView.SelectCharacter(characters, requested and requested.id or parent.selectedCharacterID, Core.Characters:GetCurrentID())
    self.requestedBuild = nil
    if requested then
        parent.buildMode, parent.selectedTab = requested.mode, requested.tab
        parent.detailSlot = nil
    end
    local id = character and character.id
    local mode = parent.buildMode
    local current = mode ~= "backup" and id and id == Core.Characters:GetCurrentID()
    local backup = id and Addon.Store:Configuration(id, "backup")
    local showModeButton = backup ~= nil or mode == "backup"
    parent.buildModeButton:SetText(Addon:T(mode == "backup" and "FOREVER.BACKUP_BUILD" or "FOREVER.CURRENT_BUILD"))
    parent.buildModeButton:SetState(mode == "backup" and "selected" or "default")
    parent.buildModeButton:SetShown(showModeButton)
    if id ~= parent.renderedCharacterID then
        parent.detailSlot = nil
        parent.scroll:SetVerticalScroll(0)
    end
    parent.selectedCharacterID = id
    parent.renderedCharacterID = id
    local surfaceWidth = context.surfaceAvailableWidth or parent:GetWidth()
    local layout = EquipmentView.GetMainLayout(surfaceWidth)
    local inset, left = layout.inset, layout.left
    EquipmentView.RenderCharacterSelector(parent.roster, parent, layout, characters, character, context)
    parent.heading:ClearAllPoints()
    parent.heading:SetPoint("TOPLEFT", left, -inset.top)
    parent.heading:SetPoint("RIGHT", showModeButton and -244 or -130, 0)
    parent.heading:SetShown(layout.rosterWidth ~= nil or not character)
    parent.scroll:ClearAllPoints()
    parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -96)
    parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local activeTab=not context.preview and parent.selectedTab or "equipment"
    local showTalents=activeTab=="talents"
    local saveState, saveConfig
    if id and not showTalents then saveState, saveConfig=Addon.Store:EquipmentSaveState(id, mode) end
    local showSaveButton = current and Addon.Scanner.inWorld and activeTab=="equipment" and saveConfig ~= nil
    parent.saveConfig = showSaveButton and saveState ~= "saved" and saveConfig or nil
    parent.saveNow:SetShown(not not showSaveButton)
    parent.saveNow:SetState(parent.saveConfig and "default" or "disabled")
    local snapshot
    if character and not showTalents then snapshot=Addon.Store:Get(id, mode) end
    local equipment={}
    for slot=1,19 do if snapshot then equipment[#equipment+1]={slot=slot,item=snapshot.slots[slot]} end end
    parent.heading:SetText(character and Core.Characters:FormatName(character,{realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    for tab, button in pairs(parent.tabs) do
        button:SetShown(not context.preview)
        button:SetState(activeTab==tab and "selected" or "default")
    end
    local rows,status,talentSnapshot=equipment,id and self:Status(id, mode) or Addon:T("FOREVER.UNKNOWN")
    local saveLabels={saved="FOREVER.EQUIPMENT_SAVED",pending="FOREVER.EQUIPMENT_PENDING",
        changed="FOREVER.EQUIPMENT_CHANGED",incomplete="FOREVER.EQUIPMENT_SAVE_INCOMPLETE"}
    if saveState then status=Addon:T(saveLabels[saveState]) end
    if showTalents then
        local state
        if character then talentSnapshot,state=Addon.Talents:Get(id, mode) end
        local keys={known="FOREVER.TALENT_KNOWN",stale="FOREVER.TALENT_STALE",unknown="FOREVER.TALENT_UNKNOWN"}
        status=Addon:T(keys[state or "unknown"])
        if current and Addon.Talents:HasStagedChanges() then status=Addon:T("FOREVER.TALENT_STAGED") end
        rows={}
    end
    if mode == "backup" and not (snapshot or talentSnapshot) then
        status=Addon:T(backupEmpty[showTalents and "talents" or "equipment"])
    end
    parent.status:SetText(status); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(current and Addon.Scanner.inWorld and "default" or "disabled")
    local width,columns,x,total=math.max(320,math.min(layout.width-20, parent.scroll:GetWidth()-20)),{},0,0
    local fields,weights=context.fields or self:Fields(),{slot=1,item=3}
    local canCombine = activeTab == "equipment" and character and width >= 810 and #fields == 2
    local detailItem = snapshot and parent.detailSlot and snapshot.slots[parent.detailSlot]
    local showDetail = detailItem and detailItem.itemID > 0
    if not showDetail then parent.detailSlot = nil end
    local combined = canCombine and not parent.talentsCollapsed and not showDetail
    parent.collapseTalents:SetShown(not not (canCombine and not showDetail))
    parent.collapseTalents:SetText(Addon:T(combined and "FOREVER.HIDE_TALENTS" or "FOREVER.SHOW_TALENTS"))
    local equipmentControl = parent.collapseTalents:IsShown() and parent.collapseTalents or parent.equipmentTab
    parent.saveNow:ClearAllPoints()
    parent.saveNow:SetPoint("RIGHT", equipmentControl, "LEFT", -6, 0)
    parent.status:ClearAllPoints()
    parent.status:SetPoint("TOPLEFT", left, -48)
    parent.status:SetPoint("RIGHT", showSaveButton and parent.saveNow or equipmentControl, "LEFT", -8, 0)
    parent.status:SetHeight(Theme.Size.standard)
    local sideDetail = showDetail and width >= 740 and #fields == 2
    local gearWidth, treeLeft = width, 0
    if combined or sideDetail then gearWidth, treeLeft = EquipmentView.SplitEquipmentPane(width) end
    local showDoll = snapshot and activeTab=="equipment" and #fields == 2 and gearWidth >= 360
    local viewportHeight = parent:GetHeight() - 96 - inset.bottom
    local dollHeight = EquipmentView.LayoutEquipmentPane(parent.doll, gearWidth, viewportHeight, parent.content, "TOPLEFT", 0)
    local detailTop = sideDetail and 0 or (showDoll and dollHeight or #rows * 30) + 8
    local detail = parent.slotDetail
    detail:SetShown(not not showDetail)
    if showDetail then
        local slot = parent.detailSlot
        local name, icon, color = ItemDisplay(detailItem)
        detail:ClearAllPoints()
        detail:SetPoint("TOPLEFT", sideDetail and treeLeft or 0, -detailTop)
        detail:SetWidth(sideDetail and width - treeLeft or width)
        detail.icon:SetTexture(icon)
        detail.slot:SetText(Addon:T(slotKeys[slot]))
        detail.item:SetText(name)
        detail.item:SetTextColor(unpack(color or Theme.Colors.text))
        detail.effect:SetText(EnchantDisplay(detailItem, Addon.Enhancements:Read(detailItem)))
        detail:SetHeight(RenderEnchantCandidates(detail, slot, detailItem, not not current))
    end
    if combined then talentSnapshot = Addon.Talents:Get(id, mode) end
    local talentMatches = showTalents and TalentMatches(talentSnapshot, parent.talentQuery) or nil
    parent.talentTree:ClearAllPoints()
    parent.talentTree:SetPoint("TOPLEFT", treeLeft, combined and -40 or 0)
    parent.talentTree:SetWidth(width - treeLeft)
    local treeBudget = viewportHeight - (combined and 40 or (parent.talentQuery and 68 or 36))
    local treeHeight, offsets, treeIssue = Addon.TalentTree:Render(parent.talentTree, talentSnapshot,
        width - treeLeft, talentMatches, combined, treeBudget)
    parent.talentTree:SetHeight(treeHeight or 1)
    parent.talentHeading:SetPoint("TOPLEFT", treeLeft, 0)
    parent.talentHeading:SetWidth(width - treeLeft)
    parent.talentHeading:SetShown(not not combined)
    local showTree = treeHeight ~= nil
    parent.talentMatchOffsets = offsets
    parent.talentSearch:SetPoint("TOPLEFT", left, -95)
    parent.talentSearch:SetShown(showTree and showTalents)
    parent.talentTreeHint:SetPoint("TOPLEFT", left + treeLeft, combined and -136 or -134)
    parent.talentTreeHint:SetShown((showTalents and treeIssue ~= nil) or (combined and not showTree))
    local hint = combined and (talentSnapshot and "FOREVER.OPEN_TALENTS" or "FOREVER.TALENT_UNKNOWN")
        or (treeIssue == "width" and "FOREVER.TALENT_TREE_WIDEN" or "FOREVER.TALENT_TREE_UNAVAILABLE")
    parent.talentTreeHint:SetText(Addon:T(hint))
    local showTalentNext = showTree and showTalents and talentMatches ~= nil and #offsets > 0
    parent.talentNext:SetShown(showTalentNext)
    local showTalentSummary=showTree and showTalents and talentMatches~=nil
    parent.talentSearchCount:SetShown(showTalentSummary)
    if showTalentSummary then
        parent.talentSearchCount:ClearAllPoints()
        parent.talentSearchCount:SetPoint("TOPLEFT",left,-128)
        parent.talentSearchCount:SetPoint("TOPRIGHT",showTalentNext and -125 or -12,-128)
        parent.talentSearchCount:SetText(Addon:T("FOREVER.TALENT_SEARCH_COUNT", #offsets))
    end
    parent.doll:SetShown(showDoll and true or false)
    parent.header:SetShown(not showDoll and not showTalents)
    local toolbarHeight=showTalentSummary and 68 or showTalents and 36 or 0
    parent.header:SetPoint("TOPLEFT",left,-96-toolbarHeight)
    parent.header:SetPoint("TOPRIGHT",-inset.right,-96-toolbarHeight)
    parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", left, ((showDoll or showTree) and -96 or -126)-toolbarHeight)
    parent.scrollWidth, parent.scrollHeight = parent.scroll:GetWidth(), parent.scroll:GetHeight()
    if parent.showDoll ~= showDoll or parent.activeTab ~= activeTab or parent.showTree ~= showTree then
        parent.scroll:SetVerticalScroll(0)
    end
    parent.showDoll,parent.showTalents,parent.showTree = showDoll,showTalents,showTree
    parent.showCombined = combined
    parent.activeTab=activeTab
    if not showDoll and parent.doll.model then parent.doll.model.snapshot = nil end
    for _,field in ipairs(fields) do total=total+(weights[field.id] or 1) end
    for _,field in ipairs(fields) do local w=width*(weights[field.id] or 1)/math.max(1,total); columns[#columns+1]={id=field.id,x=x,width=math.max(1,w-8)}; x=x+w; parent.labels[field.id]:SetText(field.title) end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    parent.renderedEquipment,parent.renderedRows,parent.columns,parent.rowWidth=equipment,rows,columns,width
    local height = math.max((treeHeight or 0) + (combined and 40 or 0), showDoll and dollHeight or #rows * 30,
        showDetail and (detailTop + detail:GetHeight()) or 0)
    parent.content:SetHeight(math.max(1,height)); parent.scroll:SetContentHeight(height)
    if parent.jumpToDetail then
        parent.jumpToDetail = nil
        if showDetail then parent.scroll:SetVerticalScroll(math.min(detailTop, parent.scroll:GetVerticalScrollRange())) end
    end
    if showTalents and parent.talentSearchJump then
        parent.talentSearchJump=nil
        parent.scroll:SetVerticalScroll(0)
        JumpToTalent(parent)
    end
    if showDoll then
        RenderDoll(parent.doll, gearWidth, dollHeight, snapshot, current and Addon.Scanner.inWorld
            and Addon.Store:ReadSnapshot(id, "equipment") or nil, parent.detailSlot)
    end
    self:PaintRows(parent)
    parent.layoutInProgress = nil
end
function Page:PaintRows(parent)
    if not parent.renderedRows or parent.context.preview then return end
    if parent.showDoll or parent.showTree then
        for _, row in ipairs(parent.rows) do row:Hide() end
        return
    end
    local first=math.floor((parent.scroll:GetVerticalScroll() or 0)/30)+1
    local capacity=math.ceil(math.max(1,parent.scroll:GetHeight())/30)+2
    local used=0
    for index=first,math.min(#parent.renderedRows,first+capacity-1) do
        used=used+1
        local item=parent.renderedRows[index]
        local row=parent.rows[used]
        if not row then
            row=CreateFrame("Button",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            for _,id in ipairs(labelIDs) do
                row.labels[id]=Theme:CreateText(row,Theme.Font.body,Theme.Colors.text)
                row.labels[id]:SetWordWrap(false)
            end
            row:SetScript("OnEnter", function(self)
                ShowItemTooltip(self,self.tooltipItem,self.labels.slot:GetText(),self.tooltipItemName,self.inspectSlot~=nil)
            end)
            row:SetScript("OnLeave",function(self) Addon.TalentTree:HideNodeTooltip(self) end)
            row:SetScript("OnClick",function(self)
                if self.inspectSlot then OpenEnhancement(parent,self.inspectSlot) end
            end)
            row:SetScript("OnHide",function(self)
                Addon.TalentTree:HideNodeTooltip(self)
            end)
            parent.rows[used]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*30); row:SetSize(parent.rowWidth,30); row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        local name, _, color = ItemDisplay(item.item)
        row.labels.slot:SetText(Addon:T(slotKeys[item.slot]))
        row.labels.item:SetText(name)
        row.labels.item:SetTextColor(unpack(color or Theme.Colors.text))
        if GameTooltip.IsOwned and GameTooltip:IsOwned(row) and not SameItem(row.tooltipItem,item.item) then
            Addon.TalentTree:HideNodeTooltip(row)
        end
        row.tooltipItem,row.tooltipItemName=item.item,name
        row.inspectSlot=parent.activeTab=="equipment" and not parent.context.preview
            and item.item.itemID>0 and item.slot or nil
        row:EnableMouse(true)
        Layout(row,row.labels,parent.columns); row:Show()
    end
    for index=used+1,#parent.rows do parent.rows[index]:Hide() end
end
function Page:Register()
    local function HasSnapshot(character)
        return Addon.Store:HasSnapshot(character.id)
    end
    local icon = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon"
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),icon=icon,fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        scope={mode="realms"},
        HasCharacterSnapshot=HasSnapshot,
        GetEligibleCharacters=function(characters)
            local result={}
            for _,character in ipairs(characters or {}) do
                if HasSnapshot(character) then result[#result+1]=character end
            end
            return result
        end,
        GetPreviewFields=function() return Core.Defaults:Copy(Addon.Store.db.settings.previewColumns) end,
        GetPreviewFieldDefinitions=function()
            local fields = {}
            for _, slot in ipairs(previewSlots) do
                fields[#fields + 1] = {id = PreviewFieldID(slot), title = Addon:T(slotKeys[slot]), defaultVisible = true}
            end
            return fields
        end,
        SetPreviewFieldVisible=function(id,visible)
            for _, slot in ipairs(previewSlots) do
                if id == PreviewFieldID(slot) then
                    Addon.Store.db.settings.previewColumns[id] = visible == true
                    Addon:NotifyChanged()
                    return true
                end
            end
            return false
        end,
        GetSurfaceMetrics=function(context)
            if context.preview then
                local inset = Theme:GetMatrixInsets(true)
                local headerHeight = inset.top + Theme.Table.headerHeight + inset.bottom
                local rowHeight = EquipmentView.EquipmentPreviewRowHeight()
                local minWidth = math.max(520, EquipmentView.GetPreviewModesWidth(PreviewModeButtons()) + inset.left + inset.right)
                return {minContentWidth=minWidth,naturalContentWidth=960,minContentHeight=headerHeight + rowHeight,
                    naturalContentHeight=headerHeight + math.max(1, #context.characters) * rowHeight}
            end
            return {minContentWidth=420,naturalContentWidth=EquipmentView.MainContentWidth,minContentHeight=260,naturalContentHeight=560}
        end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="ybb",brokerName="YiboBuilds",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon=icon,defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
