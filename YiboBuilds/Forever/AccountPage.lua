local Addon,Core=_G.YiboBuilds,_G.YiboCore or {}
local Page,Theme={},Core.UITheme; Addon.AccountPage=Page
local slotKeys={"FOREVER.SLOT_HEAD","FOREVER.SLOT_NECK","FOREVER.SLOT_SHOULDER","FOREVER.SLOT_SHIRT","FOREVER.SLOT_CHEST","FOREVER.SLOT_WAIST","FOREVER.SLOT_LEGS","FOREVER.SLOT_FEET","FOREVER.SLOT_WRIST","FOREVER.SLOT_HANDS","FOREVER.SLOT_FINGER1","FOREVER.SLOT_FINGER2","FOREVER.SLOT_TRINKET1","FOREVER.SLOT_TRINKET2","FOREVER.SLOT_BACK","FOREVER.SLOT_MAINHAND","FOREVER.SLOT_OFFHAND","FOREVER.SLOT_RANGED","FOREVER.SLOT_TABARD"}
local leftSlots = { 1, 2, 3, 15, 5, 4, 19, 9 }
local rightSlots = { 10, 6, 7, 8, 11, 12, 13, 14 }
local weaponSlots = { 16, 17, 18 }
local rowHeight, rowStep, dollHeight = 36, 42, 384
local labelIDs = { "slot", "item", "enchant" }
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
function Page:Status()
    local _,state=Addon.Store:Get(Core.Characters:GetCurrentID())
    local keys={known="FOREVER.KNOWN",stale="FOREVER.STALE",error="FOREVER.ERROR",unknown="FOREVER.UNKNOWN"}
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
local function SavedItemLabel(item)
    local link = item.itemLink
    if not Addon.Store:Plain(link) or type(link) ~= "string" then return end
    local id, name = link:match("|Hitem:(%d+):[^|]*|h%[([^|]+)%]|h")
    if tonumber(id) ~= item.itemID then return end
    local quality = tonumber(link:match("^|cnIQ(%d+):|H"))
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and type(color.r)=="number" and type(color.g)=="number" and type(color.b)=="number" then
        return name, {color.r, color.g, color.b}
    end
    local red, green, blue = link:match("^|c%x%x(%x%x)(%x%x)(%x%x)|H")
    if red then return name, {tonumber(red,16)/255, tonumber(green,16)/255, tonumber(blue,16)/255} end
    return name
end

local function ItemDisplay(item)
    if item.itemID == 0 then return Addon:T("FOREVER.EMPTY"), nil, Theme.Colors.muted end
    local name, color = SavedItemLabel(item)
    local ok,info=pcall(Core.ItemResolver.GetInfo,Core.ItemResolver,item.itemID)
    local icon
    if ok and type(info) == "table" then
        if not name and Addon.Store:Plain(info.name) and type(info.name) == "string" and info.name ~= "" then name = info.name end
        if Addon.Store:Plain(info.icon) then icon = info.icon end
    end
    return name or Addon:T("FOREVER.UNCACHED", item.itemID), icon or "Interface\\Icons\\INV_Misc_QuestionMark", color or Theme.Colors.text
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

local function OpenEnhancement(parent, slot)
    parent.selectedTab = "enhancements"
    parent.enhancementSlot:SetValue(slot)
    GameTooltip:Hide()
    Page:Refresh(parent, parent.context)
end

local function CreateSlot(doll, parent, slot, side)
    local button = CreateFrame("Button", nil, doll, "BackdropTemplate")
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    button:SetBackdropColor(unpack(Theme.Colors.row))
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32)
    button.icon:SetPoint(side, side == "LEFT" and 2 or -2, 0)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.slotLabel = Theme:CreateText(button, Theme.Font.assist, Theme.Colors.muted)
    button.itemLabel = Theme:CreateText(button, Theme.Font.body, Theme.Colors.text)
    for index, label in ipairs({ button.slotLabel, button.itemLabel }) do
        local y = index == 1 and -2 or -17
        label:SetPoint("TOPLEFT", side == "LEFT" and 40 or 6, y)
        label:SetPoint("TOPRIGHT", side == "RIGHT" and -40 or -6, y)
        label:SetHeight(16)
        label:SetJustifyH(side)
        label:SetWordWrap(false)
    end
    button.slotLabel:SetText(Addon:T(slotKeys[slot]))
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.alternate))
        ShowItemTooltip(self, self.item, self.slotLabel:GetText(), self.itemLabel:GetText(), self.item and self.item.itemID>0)
    end)
    button:SetScript("OnClick", function(self)
        if self.item and self.item.itemID>0 then OpenEnhancement(parent,slot) end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.row))
        GameTooltip:Hide()
    end)
    button:SetScript("OnHide", function(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    doll.slots[slot] = button
end
local function CreateDoll(content, parent)
    local doll = CreateFrame("Frame", nil, content)
    doll:SetAllPoints(content)
    doll.slots = {}
    for _, slot in ipairs(leftSlots) do CreateSlot(doll, parent, slot, "LEFT") end
    for _, slot in ipairs(rightSlots) do CreateSlot(doll, parent, slot, "RIGHT") end
    for _, slot in ipairs(weaponSlots) do CreateSlot(doll, parent, slot, "LEFT") end
    local appearance = CreateFrame("Frame", nil, doll, "BackdropTemplate")
    appearance:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    appearance:SetBackdropColor(unpack(Theme.Colors.panel))
    doll.appearance = appearance
    local ok, model = pcall(CreateFrame, "DressUpModel", nil, appearance)
    if ok and type(model.SetUnit) == "function" then
        doll.model = model
        model:SetPoint("TOPLEFT", 0, -24)
        model:SetPoint("BOTTOMRIGHT")
        model:EnableMouse(false)
    elseif ok then
        model:Hide()
    end
    doll.appearanceTitle = Theme:CreateText(appearance, Theme.Font.assist, Theme.Colors.muted, "CENTER")
    doll.appearanceTitle:SetPoint("TOPLEFT", 4, -4)
    doll.appearanceTitle:SetPoint("TOPRIGHT", -4, -4)
    doll.appearanceTitle:SetHeight(18)
    doll.appearanceTitle:SetText(Addon:T("FOREVER.LIVE_APPEARANCE"))
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

local function RenderDoll(doll, width, snapshot, modelSource)
    local sideWidth = math.floor(width * 0.30)
    for _, group in ipairs({ leftSlots, rightSlots }) do
        local left = group == leftSlots
        for index, slot in ipairs(group) do
            local button = doll.slots[slot]
            button:ClearAllPoints()
            button:SetPoint(left and "TOPLEFT" or "TOPRIGHT", 0, -(index - 1) * rowStep)
            button:SetSize(sideWidth, rowHeight)
        end
    end
    local weaponWidth = math.min(sideWidth, math.floor((width - 16) / 3))
    for index, slot in ipairs(weaponSlots) do
        local button = doll.slots[slot]
        button:ClearAllPoints()
        button:SetPoint("TOP", (index - 2) * (weaponWidth + 8), -344)
        button:SetSize(weaponWidth, rowHeight)
    end
    doll.appearance:ClearAllPoints()
    doll.appearance:SetPoint("TOPLEFT", sideWidth + 10, 0)
    doll.appearance:SetPoint("TOPRIGHT", -sideWidth - 10, 0)
    doll.appearance:SetHeight(330)
    for slot, button in pairs(doll.slots) do
        local item = snapshot.slots[slot]
        if not SameItem(button.item,item) and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        button.item = item
        local name, icon, color = ItemDisplay(item)
        button.itemLabel:SetText(name)
        button.itemLabel:SetTextColor(unpack(color))
        button.icon:SetTexture(icon)
    end
    local model = doll.model
    if model and modelSource and model.snapshot ~= modelSource then
        if SameEquipment(model.snapshot, modelSource) then
            model.snapshot = modelSource
        else
            if model.ClearModel then pcall(model.ClearModel, model) end
            local ok, result = pcall(model.SetUnit, model, "player")
            model.snapshot = ok and result ~= false and modelSource or nil
        end
    end
    if model then model:SetShown(modelSource ~= nil and model.snapshot == modelSource) end
    local showingModel = model and modelSource ~= nil and model.snapshot == modelSource
    doll.appearanceFallback:SetShown(not showingModel)
end
function Page:Create(parent)
    parent.heading=Theme:CreateText(parent,Theme.Font.section,Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT",12,-10); parent.heading:SetPoint("RIGHT",-130,0); parent.heading:SetHeight(26)
    parent.refresh=Theme:CreateButton(parent,100,Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT",-12,-10)
    parent.refresh:SetScript("OnClick",function()
        if parent.showTalents then Addon.Talents:Scan() else Addon.Scanner:Scan(true) end
    end)
    parent.talentsTab=Theme:CreateButton(parent,76,Addon:T("FOREVER.TALENTS"))
    parent.talentsTab:SetPoint("TOPRIGHT",-12,-48)
    parent.enhancementsTab=Theme:CreateButton(parent,104,Addon:T("FOREVER.ENHANCEMENTS"))
    parent.enhancementsTab:SetPoint("RIGHT",parent.talentsTab,"LEFT",-6,0)
    parent.equipmentTab=Theme:CreateButton(parent,76,Addon:T("FOREVER.EQUIPMENT"))
    parent.equipmentTab:SetPoint("RIGHT",parent.enhancementsTab,"LEFT",-6,0)
    parent.tabs={equipment=parent.equipmentTab, enhancements=parent.enhancementsTab, talents=parent.talentsTab}
    for tab, button in pairs(parent.tabs) do
        button:SetScript("OnClick",function()
            parent.selectedTab=tab
            if tab=="enhancements" then parent.enhancementSlot:SetValue("all") end
            Page:Refresh(parent,parent.context)
        end)
    end
    local slots={{value="all",label=Addon:T("FOREVER.ENHANCEMENT_ALL_SLOTS")}}
    for slot, key in ipairs(slotKeys) do slots[#slots+1]={value=slot,label=Addon:T(key)} end
    parent.enhancementSlot=Theme:CreateDropdown(parent,168,slots)
    parent.enhancementSlot:SetPoint("TOPLEFT",12,-95)
    parent.enhancementSlot:SetValue("all")
    parent.enhancementSlot:SetMenuPageSize(8)
    parent.enhancementSlot:SetOnValueChanged(function()
        parent.scroll:SetVerticalScroll(0)
        Page:Refresh(parent,parent.context)
    end)
    parent.enhancementHint=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.enhancementHint:SetPoint("TOPLEFT",parent.enhancementSlot,"TOPRIGHT",10,0)
    parent.enhancementHint:SetPoint("TOPRIGHT",-12,-95)
    parent.enhancementHint:SetHeight(30)
    parent.enhancementSlot:Hide(); parent.enhancementHint:Hide()
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
    parent.labels,parent.rows={},{}
    for _,id in ipairs(labelIDs) do parent.labels[id]=Theme:CreateText(parent.header,Theme.Font.assist,Theme.Colors.muted) end
    parent.scroll:HookScript("OnVerticalScroll",function() Page:PaintRows(parent) end)
    parent.scroll:HookScript("OnSizeChanged",function(scroll)
        if parent.context and parent:IsShown() and parent.scrollWidth ~= scroll:GetWidth() then
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
local previewRowHeight = 38

local function PreviewFieldID(slot)
    return "equipment-slot-" .. slot
end

local function CreatePreviewCell(parent)
    local cell = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    cell:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 2, -2)
    cell.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(self)
        ShowItemTooltip(self, self.item, self.slotName, self.itemName)
    end)
    local function HideTooltip(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    cell:SetScript("OnLeave", HideTooltip)
    cell:SetScript("OnHide", HideTooltip)
    return cell
end

function Page:RefreshEquipmentPreview(parent, context)
    if not parent.previewHeader then
        parent.previewHeader = CreateFrame("Frame", nil, parent)
        parent.previewHeader:SetPoint("TOPLEFT", 12, -12)
        parent.previewHeader:SetHeight(26)
        parent.previewLabels, parent.previewRows = {}, {}
    end
    parent.previewHeader:Show()
    parent.heading:Hide()
    parent.status:Hide()
    parent.refresh:Hide()
    parent.header:Hide()
    parent.doll:Hide()
    parent.talentTree:Hide()
    parent.talentTreeHint:Hide()
    parent.talentSearch:Hide()
    parent.talentNext:Hide()
    parent.talentSearchCount:Hide()
    parent.enhancementSlot:Hide()
    parent.enhancementHint:Hide()
    for _, button in pairs(parent.tabs) do button:Hide() end
    for _, row in ipairs(parent.rows) do row:Hide() end
    parent.showTalents = false
    parent.activeTab = "equipment"
    parent.scroll:SetPoint("TOPLEFT", 12, -40)

    local width = math.max(1, (context.surfaceAvailableWidth or parent.scrollWidth) - 28)
    local nameWidth = math.min(170, math.floor(width * 0.23))
    local visibleSlots = {}
    local preferences = Addon.Store.db.settings.previewColumns
    for _, slot in ipairs(previewSlots) do
        if preferences[PreviewFieldID(slot)] ~= false then visibleSlots[#visibleSlots + 1] = slot end
    end
    local slotWidth = math.min(40, math.floor((width - nameWidth) / math.max(1, #visibleSlots)))
    local columns = {{id = "character", x = 0, width = nameWidth}}
    local titles = {character = Core:Text("CORE.CHARACTER")}
    for index, slot in ipairs(visibleSlots) do
        columns[#columns + 1] = {id = slot, x = nameWidth + (index - 1) * slotWidth, width = slotWidth}
        titles[slot] = Addon:T(slotKeys[slot])
    end
    for _, column in ipairs(columns) do
        local label = parent.previewLabels[column.id] or Theme:CreateText(parent.previewHeader,
            Theme.Font.assist, Theme.Colors.muted, column.id == "character" and "LEFT" or "CENTER")
        parent.previewLabels[column.id] = label
        label:SetWordWrap(false)
        label:SetText(titles[column.id])
    end
    Layout(parent.previewHeader, parent.previewLabels, columns)

    local count = 0
    for _, character in ipairs(context.characters or {}) do
        local snapshot = Addon.Store:GetCachedEquipment(character.id)
        if snapshot then
            count = count + 1
            local row = parent.previewRows[count]
            if not row then
                row = CreateFrame("Frame", nil, parent.content)
                row.name = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text)
                row.name:SetPoint("LEFT", 2, 0)
                row.name:SetWordWrap(false)
                row.cells = {}
                parent.previewRows[count] = row
            end
            row:SetPoint("TOPLEFT", 0, -(count - 1) * previewRowHeight)
            row:SetSize(width, previewRowHeight)
            row.name:SetWidth(math.max(1, nameWidth - 4))
            row.name:SetText(Core.Characters:FormatName(character, {realmMode = "full"}))
            for slot, cell in pairs(row.cells) do
                if preferences[PreviewFieldID(slot)] == false then cell:Hide() end
            end
            for index, slot in ipairs(visibleSlots) do
                local cell = row.cells[slot] or CreatePreviewCell(row)
                row.cells[slot] = cell
                local item = snapshot.slots[slot]
                if GameTooltip.IsOwned and GameTooltip:IsOwned(cell) and not SameItem(cell.item, item) then GameTooltip:Hide() end
                local name, icon, color = ItemDisplay(item)
                cell.item, cell.slotName, cell.itemName = item, titles[slot], name
                cell:SetPoint("LEFT", row, "LEFT", nameWidth + (index - 1) * slotWidth, 0)
                local size = math.max(1, math.min(32, slotWidth - 3))
                cell:SetSize(size, size)
                cell.icon:SetTexture(icon or "Interface\\Buttons\\UI-EmptySlot")
                cell:SetBackdropBorderColor(unpack(item.itemID == 0 and Theme.Colors.line or color))
                cell:Show()
            end
            row:Show()
        end
    end
    for index = count + 1, #parent.previewRows do parent.previewRows[index]:Hide() end
    if count == 0 then
        parent.previewHeader:Hide()
        parent.status:SetText(Addon:T("FOREVER.UNKNOWN"))
        parent.status:Show()
    end
    parent.content:SetSize(width, math.max(1, count * previewRowHeight))
    parent.scroll:SetContentHeight(count * previewRowHeight)
end

function Page:Refresh(parent,context)
    local previousContext = parent.context
    parent.context, parent.scrollWidth = context, parent.scroll:GetWidth()
    if previousContext and previousContext.preview ~= context.preview then parent.scroll:SetVerticalScroll(0) end
    if context.preview then
        self:RefreshEquipmentPreview(parent, context)
        return
    end
    if parent.previewHeader then
        parent.previewHeader:Hide()
        for _, row in ipairs(parent.previewRows) do row:Hide() end
    end
    parent.heading:Show()
    parent.status:Show()
    local id=Core.Characters:GetCurrentID()
    local character=context.characters and context.characters[1]; if character and character.id~=id then character=nil end
    local activeTab=not context.preview and parent.selectedTab or "equipment"
    local showTalents,showEnhancements=activeTab=="talents",activeTab=="enhancements"
    local snapshot
    if character and not showTalents then snapshot=Addon.Store:Get(id) end
    local equipment={}
    for slot=1,19 do if snapshot then equipment[#equipment+1]={slot=slot,item=snapshot.slots[slot]} end end
    parent.heading:SetText(character and Core.Characters:FormatName(character,{realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    for tab, button in pairs(parent.tabs) do
        button:SetShown(not context.preview)
        button:SetState(activeTab==tab and "selected" or "default")
    end
    parent.status:SetPoint("RIGHT",context.preview and -12 or -286,0)
    local rows,status,talentSnapshot=equipment,self:Status()
    local enhancementHint
    if showTalents then
        local state
        if character then talentSnapshot,state=Addon.Talents:Get(id) end
        local keys={known="FOREVER.TALENT_KNOWN",stale="FOREVER.TALENT_STALE",unknown="FOREVER.TALENT_UNKNOWN"}
        status=Addon:T(keys[state or "unknown"])
        rows={}
    elseif showEnhancements then
        rows={}
        local selected=parent.enhancementSlot.value
        for _, entry in ipairs(equipment) do
            if entry.item.itemID > 0 and (selected=="all" or selected==entry.slot) then
                entry.enchant=Addon.Enhancements:Read(entry.item)
                entry.enchantText=EnchantDisplay(entry.item,entry.enchant)
                rows[#rows+1]=entry
            end
        end
        if snapshot and #rows==0 then
            local key=selected=="all" and "FOREVER.NO_EQUIPPED_ITEMS" or "FOREVER.ENHANCEMENT_EMPTY_SLOT"
            enhancementHint=Addon:T(key)
        end
    end
    parent.enhancementSlot:SetShown(showEnhancements)
    parent.enhancementHint:SetText(enhancementHint or "")
    parent.enhancementHint:SetShown(enhancementHint~=nil)
    parent.status:SetText(status); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and "default" or "disabled")
    local width,columns,x,total=math.max(320,parent.scrollWidth-20),{},0,0
    local fields,weights=context.fields or self:Fields(),{slot=1,item=3}
    if showEnhancements then
        fields=self:Fields()
        fields[3]={id="enchant",title=Addon:T("FOREVER.ENCHANT")}
        weights={slot=2,item=4,enchant=4}
    end
    local showDoll = snapshot and activeTab=="equipment" and not context.preview and #fields == 2 and width >= 560
    local talentMatches = TalentMatches(talentSnapshot, parent.talentQuery)
    local treeHeight, offsets, treeIssue = Addon.TalentTree:Render(parent.talentTree, talentSnapshot, width, talentMatches)
    local showTree = treeHeight ~= nil
    parent.talentMatchOffsets = offsets
    parent.talentSearch:SetShown(showTree)
    parent.talentTreeHint:SetShown(showTalents and treeIssue ~= nil)
    if treeIssue then
        parent.talentTreeHint:SetText(Addon:T(treeIssue == "width" and "FOREVER.TALENT_TREE_WIDEN" or "FOREVER.TALENT_TREE_UNAVAILABLE"))
    end
    local showTalentNext = showTree and talentMatches ~= nil and #offsets > 0
    parent.talentNext:SetShown(showTalentNext)
    local showTalentSummary=showTree and talentMatches~=nil
    parent.talentSearchCount:SetShown(showTalentSummary)
    if showTalentSummary then
        parent.talentSearchCount:ClearAllPoints()
        parent.talentSearchCount:SetPoint("TOPLEFT",12,-128)
        parent.talentSearchCount:SetPoint("TOPRIGHT",showTalentNext and -125 or -12,-128)
        parent.talentSearchCount:SetText(Addon:T("FOREVER.TALENT_SEARCH_COUNT", #offsets))
    end
    parent.doll:SetShown(showDoll and true or false)
    parent.header:SetShown(not showDoll and not showTalents)
    local toolbarHeight=showTalentSummary and 68 or (showTalents or showEnhancements) and 36 or 0
    parent.header:SetPoint("TOPLEFT",12,-96-toolbarHeight)
    parent.header:SetPoint("TOPRIGHT",-12,-96-toolbarHeight)
    parent.scroll:SetPoint("TOPLEFT", 12, ((showDoll or showTree) and -96 or -126)-toolbarHeight)
    if parent.showDoll ~= showDoll or parent.activeTab ~= activeTab or parent.showTree ~= showTree then
        parent.scroll:SetVerticalScroll(0)
    end
    parent.showDoll,parent.showTalents,parent.showTree = showDoll,showTalents,showTree
    parent.activeTab=activeTab
    if not showDoll and parent.doll.model then parent.doll.model.snapshot = nil end
    for _,field in ipairs(fields) do total=total+(weights[field.id] or 1) end
    for _,field in ipairs(fields) do local w=width*(weights[field.id] or 1)/math.max(1,total); columns[#columns+1]={id=field.id,x=x,width=math.max(1,w-8)}; x=x+w; parent.labels[field.id]:SetText(field.title) end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    parent.renderedEquipment,parent.renderedRows,parent.columns,parent.rowWidth=equipment,rows,columns,width
    local height = treeHeight or (showDoll and dollHeight or #rows * 30)
    parent.content:SetHeight(math.max(1,height)); parent.scroll:SetContentHeight(height)
    if showTalents and parent.talentSearchJump then
        parent.talentSearchJump=nil
        parent.scroll:SetVerticalScroll(0)
        JumpToTalent(parent)
    end
    if showDoll then
        RenderDoll(parent.doll, width, snapshot, Addon.Scanner.inWorld and Addon.Store.db.characters[id] or nil)
    end
    self:PaintRows(parent)
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
        row.labels.item:SetTextColor(unpack(color))
        if GameTooltip.IsOwned and GameTooltip:IsOwned(row) and not SameItem(row.tooltipItem,item.item) then
            Addon.TalentTree:HideNodeTooltip(row)
        end
        row.tooltipItem,row.tooltipItemName=item.item,name
        row.inspectSlot=parent.activeTab=="equipment" and not parent.context.preview
            and item.item.itemID>0 and item.slot or nil
        row:EnableMouse(true)
        if parent.activeTab=="enhancements" then
            row.labels.enchant:SetText(item.enchantText)
        end
        Layout(row,row.labels,parent.columns); row:Show()
    end
    for index=used+1,#parent.rows do parent.rows[index]:Hide() end
end
function Page:Register()
    local function Eligible(character, includeTalents)
        local db = Addon.Store.db
        return character.id==Core.Characters:GetCurrentID()
            and (db.characters[character.id]~=nil or (includeTalents and db.talents and db.talents[character.id]~=nil))
    end
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        scope={mode="realms", previewOnly=true},
        HasCharacterSnapshot=function(character) return Addon.Store.db.characters[character.id] ~= nil end,
        GetEligibleCharacters=function(characters, context)
            local result={}
            for _,character in ipairs(characters or {}) do
                if context.preview and Addon.Store.db.characters[character.id]
                    or not context.preview and Eligible(character, true) then result[#result+1]=character end
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
                return {minContentWidth=520,naturalContentWidth=960,minContentHeight=88,
                    naturalContentHeight=50 + math.max(1, #context.characters) * previewRowHeight}
            end
            return {minContentWidth=420,naturalContentWidth=760,minContentHeight=260,naturalContentHeight=510}
        end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="ybb",brokerName="YiboBuilds",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
