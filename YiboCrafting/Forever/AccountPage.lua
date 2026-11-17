local Addon,Core=_G.YiboCrafting,_G.YiboCore or {}
local Page,Theme={},Core.UITheme; Addon.AccountPage=Page
function Page:Fields()
    return {{id="profession",title=Addon:T("FOREVER.PROFESSION"),defaultVisible=true},{id="recipe",title=Addon:T("FOREVER.RECIPE"),defaultVisible=true},
        {id="learned",title=Addon:T("FOREVER.LEARNING"),defaultVisible=true},{id="state",title=Addon:T("FOREVER.DATA_STATE"),defaultVisible=true}}
end
function Page:Status()
    local keys={partial="FOREVER.PARTIAL",pending="FOREVER.PENDING",external="FOREVER.EXTERNAL",profile="FOREVER.PROFILE_PENDING",
        error="FOREVER.ERROR",unavailable="FOREVER.UNAVAILABLE",closed="FOREVER.CLOSED"}
    return Addon:T(keys[Addon.Scanner.state] or "FOREVER.UNKNOWN")
end
local function FilterChanged(parent)
    parent.scroll:SetVerticalScroll(0)
    Addon:NotifyChanged()
end
function Page:Create(parent)
    parent.heading=Theme:CreateText(parent,Theme.Font.section,Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT",12,-10); parent.heading:SetPoint("RIGHT",-130,0); parent.heading:SetHeight(26)
    parent.refresh=Theme:CreateButton(parent,100,Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT",-12,-10)
    parent.refresh:SetScript("OnClick",function() Addon.Scanner:Scan() end)
    parent.professions=Theme:CreateText(parent,Theme.Font.body,Theme.Colors.text)
    parent.professions:SetPoint("TOPLEFT",12,-48); parent.professions:SetPoint("RIGHT",-12,0); parent.professions:SetHeight(60)
    parent.status=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT",12,-112); parent.status:SetPoint("RIGHT",-12,0); parent.status:SetHeight(42)
    local toolbar=CreateFrame("Frame",nil,parent)
    parent.toolbar=toolbar
    toolbar:SetPoint("TOPLEFT",12,-159); toolbar:SetPoint("TOPRIGHT",-12,-159); toolbar:SetHeight(30)
    parent.search=Theme:CreateInput(toolbar,{
        width=190,height=28,maxLetters=80,placeholder=Addon:T("FOREVER.SEARCH"),
        OnChanged=function() FilterChanged(parent) end,
    })
    parent.search:SetPoint("LEFT")
    Theme:AttachClearButton(parent.search)
    parent.professionFilter=Theme:CreateDropdown(toolbar,146)
    parent.professionFilter:SetPoint("LEFT",parent.search,"RIGHT",8,0)
    parent.professionFilter:SetOnValueChanged(function() FilterChanged(parent) end)
    parent.learningFilter=Theme:CreateDropdown(toolbar,126)
    parent.learningFilter:SetPoint("LEFT",parent.professionFilter,"RIGHT",8,0)
    parent.learningFilter:SetOptions({
        {value="all",label=Addon:T("UI.ALL_STATES")},
        {value="learned",label=Addon:T("UI.LEARNED")},
        {value="unlearned",label=Addon:T("FOREVER.NOT_LEARNED")},
    })
    parent.learningFilter:SetValue("all")
    parent.learningFilter:SetOnValueChanged(function() FilterChanged(parent) end)
    parent.matchCount=Theme:CreateText(toolbar,Theme.Font.assist,Theme.Colors.muted)
    parent.matchCount:SetPoint("LEFT",parent.learningFilter,"RIGHT",12,0)
    parent.matchCount:SetPoint("RIGHT")
    parent.header=CreateFrame("Frame",nil,parent); parent.header:SetPoint("TOPLEFT",12,-160); parent.header:SetPoint("TOPRIGHT",-12,-160); parent.header:SetHeight(26)
    parent.scroll=Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT",12,-190); parent.scroll:SetPoint("BOTTOMRIGHT",-12,10)
    parent.content=CreateFrame("Frame",nil,parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels,parent.rows={},{}
    for _,field in ipairs(self:Fields()) do parent.labels[field.id]=Theme:CreateText(parent.header,Theme.Font.assist,Theme.Colors.muted) end
    parent.scroll:HookScript("OnVerticalScroll",function() Page:PaintRows(parent) end)
    parent.scroll:HookScript("OnSizeChanged",function() Page:PaintRows(parent) end)
end
local function Layout(container,labels,columns)
    for _,label in pairs(labels) do label:Hide() end
    for _,column in ipairs(columns) do local label=labels[column.id]; label:ClearAllPoints(); label:SetPoint("TOPLEFT",container,"TOPLEFT",column.x,0); label:SetSize(column.width,30); label:Show() end
end
local previewLimit = 6
local matrixRowHeight = 30

local function CreateMatrix(parent)
    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", 12, -8)
    toolbar:SetPoint("TOPRIGHT", -12, -8)
    toolbar:SetHeight(30)
    local changed = function() FilterChanged(parent) end
    local search = Theme:CreateInput(toolbar, {width=174, height=28, clearable=true, maxLetters=80,
        placeholder=Addon:T("FOREVER.SEARCH"), OnChanged=changed})
    search:SetPoint("LEFT")
    local character = Theme:CreateDropdown(toolbar, 124)
    character:SetPoint("LEFT", search, "RIGHT", 6, 0)
    character:SetOnValueChanged(changed)
    local profession = Theme:CreateDropdown(toolbar, 128)
    profession:SetPoint("LEFT", character, "RIGHT", 6, 0)
    profession:SetOnValueChanged(changed)
    local learning = Theme:CreateDropdown(toolbar, 112, {
        {value="all", label=Addon:T("UI.ALL_STATES")},
        {value="learned", label=Addon:T("UI.LEARNED")},
        {value="unknown", label=Addon:T("FOREVER.MATRIX_UNKNOWN")},
    })
    learning:SetPoint("LEFT", profession, "RIGHT", 6, 0)
    learning:SetValue("all")
    learning:SetOnValueChanged(changed)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 12, -46)
    header:SetHeight(30)
    local footer = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    footer:SetPoint("BOTTOMLEFT", 12, 8)
    footer:SetPoint("BOTTOMRIGHT", -12, 8)
    footer:SetHeight(22)
    return {toolbar=toolbar, search=search, character=character, profession=profession, learning=learning,
        header=header, footer=footer, rows={}, labels={}}
end

local function RefreshOptions(dropdown, options, admitted)
    local selected = dropdown.value
    dropdown:SetOptions(options)
    dropdown:SetValue(admitted[selected] and selected or "all")
    return dropdown.value
end

local function BuildRecipeIndex(characters)
    local groups = {}
    for _, character in ipairs(characters) do
        local snapshot = Addon.Store.db.characters[character.id]
        local profile = Core.DataDomains:Get(character.id, "professions")
        local names = {}
        for _, profession in ipairs(profile and profile.data and profile.data.professions or {}) do
            names[profession.id] = profession.name
        end
        for id, profession in pairs(snapshot and snapshot.professions or {}) do
            local group = groups[id]
            if not group then
                group = {id=id, name=names[id], recipes={}}
                groups[id] = group
            elseif not group.name then
                group.name = names[id]
            end
            for recipeID, recipe in pairs(profession.recipes) do
                local entry = group.recipes[recipeID]
                if not entry then
                    entry = {id=recipeID, name=recipe.name, byCharacter={}}
                    group.recipes[recipeID] = entry
                end
                entry.byCharacter[character.id] = recipe
            end
        end
    end
    local sorted = {}
    for _, group in pairs(groups) do
        group.name = group.name or Addon:T("FOREVER.MATRIX_PROFESSION_ID", group.id)
        sorted[#sorted+1] = group
    end
    table.sort(sorted, function(a,b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return sorted
end

local function MatchRecipes(groups, characters, profession, learning, query)
    local displayed, count, total = {}, 0, 0
    for _, group in ipairs(groups) do
        if profession == "all" or profession == group.id then
            local matches = {}
            for _, recipe in pairs(group.recipes) do
                total = total + 1
                local matchesText = query == "" or recipe.name:lower():find(query, 1, true) or tostring(recipe.id) == query
                local matchesState = learning == "all"
                if matchesText and not matchesState then
                    for _, character in ipairs(characters) do
                        local observation = recipe.byCharacter[character.id]
                        local learned = observation ~= nil and observation.learned
                        if learned == (learning == "learned") then matchesState = true; break end
                    end
                end
                if matchesText and matchesState then matches[#matches+1] = recipe end
            end
            table.sort(matches, function(a,b) return a.name == b.name and a.id < b.id or a.name < b.name end)
            local remaining = previewLimit - count
            if #matches > 0 and remaining > 0 then
                displayed[#displayed+1] = {name=group.name}
                for index = 1, math.min(remaining, #matches) do
                    displayed[#displayed+1] = {recipe=matches[index], name=matches[index].name}
                end
                count = count + math.min(remaining, #matches)
            end
        end
    end
    return displayed, count, total
end

local function MatrixLabel(labels, parent, id, header)
    local label = labels[id]
    if not label then
        label = Theme:CreateText(parent, header and Theme.Font.assist or Theme.Font.body, Theme.Colors.text,
            id == "recipe" and "LEFT" or "CENTER")
        label:SetWordWrap(false)
        labels[id] = label
    end
    return label
end

function Page:RefreshMatrix(parent, context)
    local ui = parent.matrix or CreateMatrix(parent)
    parent.matrix = ui
    for _, control in ipairs({parent.heading,parent.refresh,parent.professions,parent.status,parent.toolbar,parent.header}) do control:Hide() end
    for _, row in ipairs(parent.rows) do row:Hide() end
    ui.toolbar:Show(); ui.header:Show(); ui.footer:Show()
    parent.scroll:SetPoint("TOPLEFT",12,-76)
    parent.scroll:SetPoint("BOTTOMRIGHT",-12,34)
    local options, admitted = {{value="all",label=Addon:T("UI.ALL_CHARACTERS")}}, {}
    for _, character in ipairs(context.characters or {}) do
        admitted[character.id] = true
        options[#options+1] = {value=character.id, label=Core.Characters:FormatName(character,{realmMode="full"})}
    end
    local selected = RefreshOptions(ui.character, options, admitted)
    local characters = {}
    for _, character in ipairs(context.characters or {}) do
        if selected == "all" or selected == character.id then characters[#characters+1] = character end
    end
    local groups = BuildRecipeIndex(characters)
    options, admitted = {{value="all",label=Addon:T("UI.ALL_PROFESSIONS")}}, {}
    for _, group in ipairs(groups) do
        admitted[group.id] = true
        options[#options+1] = {value=group.id,label=group.name}
    end
    local profession = RefreshOptions(ui.profession, options, admitted)
    local query = ui.search:GetText():match("^%s*(.-)%s*$"):lower()
    local displayed, count, total = MatchRecipes(groups, characters, profession, ui.learning.value, query)
    local recipeWidth, characterWidth = 206, 104
    local width = math.max(1, (context.surfaceAvailableWidth or parent.scroll:GetWidth()) - 36)
    local visible, info = Core.AccountView:GetColumnPage(Addon.PAGE_ID, "recipe-matrix", characters, width, recipeWidth, characterWidth)
    Core.AccountView:UpdateColumnPager(parent, Addon.PAGE_ID, "recipe-matrix", info, nil, Core:Text("CORE.CHARACTER"))
    local columns = {{id="recipe",x=0,width=recipeWidth}}
    MatrixLabel(ui.labels,ui.header,"recipe",true):SetText(Addon:T("FOREVER.RECIPE"))
    for index, character in ipairs(visible) do
        local id = character.id
        columns[#columns+1] = {id=id,x=recipeWidth + (index-1)*characterWidth,width=characterWidth}
        MatrixLabel(ui.labels,ui.header,id,true):SetText(Core.Characters:FormatName(character,{realmMode="full"}))
    end
    Layout(ui.header,ui.labels,columns)
    for index, entry in ipairs(displayed) do
        local row = ui.rows[index]
        if not row then
            row = CreateFrame("Frame",nil,parent.content,"BackdropTemplate")
            row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
            row.labels = {}
            ui.rows[index] = row
        end
        local heading = MatrixLabel(row.labels,row,"recipe")
        heading:SetText(entry.name)
        heading:SetTextColor(unpack(entry.recipe and Theme.Colors.text or Theme.Colors.muted))
        for _, character in ipairs(visible) do
            local cell = MatrixLabel(row.labels,row,character.id)
            local observation = entry.recipe and entry.recipe.byCharacter[character.id]
            local learned = observation and observation.learned
            cell:SetText(entry.recipe and (learned and Addon:T("UI.LEARNED") or "?") or "")
            cell:SetTextColor(unpack(learned and Theme.Colors.accent or Theme.Colors.warning))
        end
        Layout(row,row.labels,columns)
        row:SetPoint("TOPLEFT",0,-(index-1)*matrixRowHeight)
        row:SetSize(recipeWidth+#visible*characterWidth,matrixRowHeight)
        row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        row:Show()
    end
    for index = #displayed+1, #ui.rows do ui.rows[index]:Hide() end
    ui.footer:SetText(count > 0 and Addon:T("UI.PREVIEW_REMAINDER", count, total)
        or (total == 0 and Addon:T("FOREVER.UNKNOWN") or Addon:T("FOREVER.NO_MATCH")))
    ui.recipeCount = count
    parent.content:SetSize(width, math.max(1,#displayed*matrixRowHeight))
    parent.scroll:SetContentHeight(#displayed*matrixRowHeight)
end

function Page:Refresh(parent,context)
    if parent.wasPreview ~= context.preview then parent.scroll:SetVerticalScroll(0) end
    parent.wasPreview = context.preview
    if context.preview then self:RefreshMatrix(parent,context); return end
    if parent.matrix then
        local ui = parent.matrix
        ui.toolbar:Hide(); ui.header:Hide(); ui.footer:Hide()
        for _, row in ipairs(ui.rows) do row:Hide() end
    end
    parent.heading:Show(); parent.professions:Show(); parent.status:Show(); parent.header:Show()
    parent.scroll:SetPoint("BOTTOMRIGHT",-12,10)
    local id=Core.Characters:GetCurrentID()
    local character=context.characters and context.characters[1]; if character and character.id~=id then character=nil end
    local profile=character and Addon:GetProfessionProfile()
    local names,summary,recipes={},{},{}
    local options={{value="all",label=Addon:T("UI.ALL_PROFESSIONS")}}
    local selected=parent.professionFilter.value
    local learning=context.preview and "all" or parent.learningFilter.value
    local query=context.preview and "" or parent.search:GetText():match("^%s*(.-)%s*$"):lower()
    local totalRecipes=0
    local profileKnown=profile and profile.state=="known"
    if profileKnown then
        for _,profession in ipairs(profile.data.professions or {}) do
            names[profession.id]=profession.name
            summary[#summary+1]=Addon:T("FOREVER.PROFILE_LINE",profession.name,profession.skillLevel,profession.maxSkillLevel)
            options[#options+1]={value=profession.id,label=profession.name}
        end
        local professionID=not context.preview and names[selected] and selected
        local snapshot=Addon.Store:Get(id)
        for pid,profession in pairs(snapshot and snapshot.professions or {}) do
            if names[pid] then
                local fresh=Addon.Scanner.inWorld and Addon.Scanner.open and Addon.Scanner.state=="partial" and Addon.Store.freshID==id and Addon.Store.freshProfessionID==pid
                for _,recipe in pairs(profession.recipes) do
                    totalRecipes=totalRecipes+1
                    if (not professionID or professionID==pid)
                        and (learning=="all" or recipe.learned==(learning=="learned"))
                        and (query=="" or recipe.name:lower():find(query,1,true) or tostring(recipe.recipeID):find(query,1,true)) then
                        recipes[#recipes+1]={professionID=pid,profession=names[pid],recipe=recipe,
                            fresh=fresh and Addon.Store.freshRecipes and Addon.Store.freshRecipes[recipe.recipeID]~=nil}
                    end
                end
            end
        end
    end
    parent.toolbar:SetShown(not context.preview)
    if not context.preview then
        if profileKnown or selected==nil then
            parent.professionFilter:SetOptions(options)
            parent.professionFilter:SetValue(names[selected] and selected or "all")
        end
        parent.matchCount:SetText(totalRecipes==0 and "" or (#recipes==0 and Addon:T("FOREVER.NO_MATCH")
            or Addon:T("FOREVER.MATCH_COUNT",#recipes,totalRecipes)))
    end
    local headerY=context.preview and -160 or -197
    parent.header:SetPoint("TOPLEFT",12,headerY); parent.header:SetPoint("TOPRIGHT",-12,headerY)
    parent.scroll:SetPoint("TOPLEFT",12,headerY-30)
    table.sort(recipes,function(a,b) return a.professionID==b.professionID and a.recipe.recipeID<b.recipe.recipeID or a.professionID<b.professionID end)
    parent.heading:SetText(character and Core.Characters:FormatName(character,{realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    parent.professions:SetText(#summary>0 and table.concat(summary," · ") or Addon:T("FOREVER.PROFILE_PENDING"))
    parent.status:SetText(self:Status()); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and Addon.Scanner.open and "default" or "disabled")
    local width,columns,x,total=math.max(320,parent.scroll:GetWidth()-20),{},0,0
    local fields,weights=context.fields or self:Fields(),{profession=2,recipe=3.5,learned=1,state=1.6}
    for _,field in ipairs(fields) do total=total+(weights[field.id] or 1) end
    for _,field in ipairs(fields) do local w=width*(weights[field.id] or 1)/math.max(1,total); columns[#columns+1]={id=field.id,x=x,width=math.max(1,w-8)}; x=x+w; parent.labels[field.id]:SetText(field.title) end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    parent.renderedRecipes,parent.columns,parent.rowWidth=recipes,columns,width
    parent.content:SetHeight(math.max(1,#recipes*30)); parent.scroll:SetContentHeight(#recipes*30)
    self:PaintRows(parent)
end
function Page:PaintRows(parent)
    if not parent.renderedRecipes or parent.wasPreview then return end
    local first=math.floor((parent.scroll:GetVerticalScroll() or 0)/30)+1
    local capacity=math.ceil(math.max(1,parent.scroll:GetHeight())/30)+2
    local used=0
    for index=first,math.min(#parent.renderedRecipes,first+capacity-1) do
        used=used+1
        local item=parent.renderedRecipes[index]
        local row=parent.rows[used]
        if not row then
            row=CreateFrame("Frame",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            for _,field in ipairs(self:Fields()) do row.labels[field.id]=Theme:CreateText(row,Theme.Font.body,Theme.Colors.text) end
            parent.rows[used]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*30); row:SetSize(parent.rowWidth,30); row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        row.labels.profession:SetText(item.profession); row.labels.recipe:SetText(item.recipe.name)
        row.labels.learned:SetText(Addon:T(item.recipe.learned and "UI.LEARNED" or "FOREVER.NOT_LEARNED"))
        row.labels.state:SetText(Addon:T(item.fresh and "FOREVER.OBSERVED" or "FOREVER.OLD"))
        Layout(row,row.labels,parent.columns); row:Show()
    end
    for index=used+1,#parent.rows do parent.rows[index]:Hide() end
end
function Page:Register()
    local function Eligible(character)
        local profile=Addon:GetProfessionProfile()
        return character.id==Core.Characters:GetCurrentID() and profile and profile.state=="known" and #(profile.data.professions or {})>0
    end
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        scope={mode="realms", previewOnly=true},
        HasCharacterSnapshot=function(character) return Addon.Store.db.characters[character.id] ~= nil end,
        GetEligibleCharacters=function(characters,context)
            local result={}
            for _,character in ipairs(characters or {}) do
                if (context.preview and Addon.Store.db.characters[character.id]) or (not context.preview and Eligible(character)) then
                    result[#result+1]=character
                end
            end
            return result
        end,
        GetSurfaceMetrics=function(context)
            if context.preview then
                return {minContentWidth=600,naturalContentWidth=math.max(650,242+#context.characters*104),
                    minContentHeight=174,naturalContentHeight=328}
            end
            return {minContentWidth=700,naturalContentWidth=1000,minContentHeight=337,naturalContentHeight=537}
        end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="ycr",brokerName="YiboCrafting",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboCrafting\\Media\\YiboCraftingIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
