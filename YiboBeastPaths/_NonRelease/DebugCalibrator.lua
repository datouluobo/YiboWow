local addonName, ns = ...
local YBP = _G.YiboBeastPaths

--- 默认调试数据库结构
local debugDefaults = {
    enabled = false,
    selectedPetIDByMap = {},
    transforms = {},
    referenceDisplayTransforms = {},
    minimapTransforms = {},
    nodeTransforms = {},
    ui = {
        stepMove = 0.005,
        stepScale = 0.01,
        footprintListOffset = 0,
        activeTab = "calibrate",
        exportView = "current",
        panelWidth = 760,
        panelHeight = 720,
        collapsedSections = {
            routeNav = false,
            mapAdjust = false,
            nodeAdjust = false,
            minimapAdjust = false,
            fusion = false,
            footprintList = false,
            export = false,
        },
    },
}

--- 步进级别定义
local stepPresets = {
    fine = {
        label = "细",
        move = 0.002,
        scale = 0.005,
    },
    medium = {
        label = "中",
        move = 0.005,
        scale = 0.01,
    },
    coarse = {
        label = "粗",
        move = 0.01,
        scale = 0.02,
    },
}

--- 步进顺序列表（用于循环切换）
local stepOrder = { "fine", "medium", "coarse" }
local GetDebugUIState
local IsSectionCollapsed
local ApplySectionVisibility
local ApplyDynamicLayout

local tabLabels = {
    calibrate = "路线校准",
    fusion = "融合工作台",
    footprints = "脚印管理",
    export = "导出",
}

local sectionTabs = {
    mapAdjust = "calibrate",
    nodeAdjust = "calibrate",
    minimapAdjust = "calibrate",
    fusion = "fusion",
    footprintList = "footprints",
    export = "export",
}

----------------------------------------------------------------
-- 工具函数
----------------------------------------------------------------

local function GetButtonLabel(field, delta)
    if field == "offsetX" then
        return delta < 0 and "左移" or "右移"
    elseif field == "offsetY" then
        return delta < 0 and "上移" or "下移"
    elseif field == "scale" then
        return delta < 0 and "缩小" or "放大"
    elseif field == "scaleX" then
        return delta < 0 and "横缩" or "横放"
    elseif field == "scaleY" then
        return delta < 0 and "竖缩" or "竖放"
    elseif field == "__mmScaleX" then
        return delta < 0 and "小图横缩" or "小图横放"
    elseif field == "__mmScaleY" then
        return delta < 0 and "小图竖缩" or "小图竖放"
    elseif field == "__nodeX" then
        return delta < 0 and "节点左" or "节点右"
    elseif field == "__nodeY" then
        return delta < 0 and "节点上" or "节点下"
    elseif field == "__nodeScale" then
        return delta < 0 and "节点小" or "节点大"
    end

    return delta < 0 and "减少" or "增加"
end

local function DeepCopyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                CopyDefaults(target[key], value)
            else
                target[key] = value
            end
        end
    end
end

local function EnsureTableDefaults(target, defaults)
    if type(target) ~= "table" then
        return
    end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = DeepCopyTable(value)
            else
                target[key] = value
            end
        end
    end
end

local function FormatFloat(val)
    -- 格式化为 4 位小数，保留正负号
    return string.format("%.4f", val)
end

local function GetPetDebugVisual(petID)
    local tooltipData = ns.routeNodeTooltips and ns.routeNodeTooltips[petID] or nil
    return {
        iconTexture = (tooltipData and tooltipData.imageTexture) or (tooltipData and tooltipData.iconTexture) or "Interface\\Icons\\Ability_Tracking",
        footTexture = "Interface\\Icons\\Ability_Tracking",
        displayLabel = (tooltipData and tooltipData.displayLabel) or (tooltipData and tooltipData.colorName) or "外观- 未知",
    }
end

----------------------------------------------------------------
-- 调试状态管理
----------------------------------------------------------------

function YBP:InitDebugDB()
    if type(_G.YiboBeastPathsDebugDB) ~= "table" then
        _G.YiboBeastPathsDebugDB = {}
    end
    CopyDefaults(_G.YiboBeastPathsDebugDB, debugDefaults)
end

function YBP:IsDebugEnabled()
    local db = _G.YiboBeastPathsDebugDB
    return db and db.enabled or false
end

function YBP:SetDebugEnabled(enabled)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end
    db.enabled = enabled
    if not enabled then
        self:HideDebugPanel()
    else
        self:ShowDebugPanel()
    end
    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:GetDebugPetIDsForCurrentMap()
    local mapID = self:GetCurrentWorldMapID()
    if not mapID then
        return {}
    end
    return self:GetVisiblePetIDsForMap(mapID)
end

function YBP:GetSelectedDebugPetID()
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return nil
    end
    local mapID = self:GetCurrentWorldMapID()
    if not mapID then
        return nil
    end
    -- 从每地图记录中取
    if db.selectedPetIDByMap[mapID] then
        return db.selectedPetIDByMap[mapID]
    end
    -- 默认取该地图第一条
    local petIDs = self:GetVisiblePetIDsForMap(mapID)
    if #petIDs > 0 then
        return petIDs[1]
    end
    return nil
end

function YBP:SetSelectedDebugPetID(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end
    local mapID = self:GetCurrentWorldMapID()
    if not mapID then
        return
    end
    db.selectedPetIDByMap[mapID] = petID
    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:ToggleDebugSection(sectionKey)
    self:RefreshDebugPanel()
end

function YBP:SetFootprintListOffset(offset)
    local ui = GetDebugUIState()
    if not ui then
        return
    end

    ui.footprintListOffset = math.max(0, math.floor(offset or 0))
    self:RefreshDebugPanel()
end

function YBP:GetActiveDebugTab()
    local ui = GetDebugUIState()
    local activeTab = ui and ui.activeTab or nil
    if not activeTab or not tabLabels[activeTab] then
        activeTab = "calibrate"
        if ui then
            ui.activeTab = activeTab
        end
    end
    return activeTab
end

function YBP:SetActiveDebugTab(tabKey)
    if not tabLabels[tabKey] then
        return
    end

    local ui = GetDebugUIState()
    if not ui then
        return
    end

    ui.activeTab = tabKey
    ui.collapsedSections = ui.collapsedSections or {}
    if tabKey == "calibrate" then
        ui.collapsedSections.routeNav = false
        ui.collapsedSections.mapAdjust = false
        ui.collapsedSections.nodeAdjust = false
        ui.collapsedSections.minimapAdjust = false
    elseif tabKey == "fusion" then
        ui.collapsedSections.fusion = false
    elseif tabKey == "footprints" then
        ui.collapsedSections.footprintList = false
    elseif tabKey == "export" then
        ui.collapsedSections.export = false
    end
    self:RefreshDebugPanel()
end

function YBP:GetDebugExportView()
    local ui = GetDebugUIState()
    local exportView = ui and ui.exportView or nil
    if exportView ~= "current" and exportView ~= "footprints" and exportView ~= "resolved"
        and exportView ~= "map" and exportView ~= "mapFusion" then
        exportView = "current"
        if ui then
            ui.exportView = exportView
        end
    end
    return exportView
end

function YBP:SetDebugExportView(exportView)
    local ui = GetDebugUIState()
    if not ui then
        return
    end

    ui.exportView = exportView
end

function YBP:GetDebugExportText(exportView)
    if exportView == "footprints" then
        return self:ExportCurrentFootprintAnchorsSnippet()
    elseif exportView == "resolved" then
        return self:ExportCurrentResolvedRouteSnippet()
    elseif exportView == "map" then
        return self:ExportCurrentMapDebugTransforms()
    elseif exportView == "mapFusion" then
        return self:ExportCurrentMapRouteFusionSnapshot()
    end

    return self:ExportCurrentDebugTransform()
end

function YBP:GetDebugTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.transforms then
        return nil
    end
    return db.transforms[petID]
end

function YBP:GetDebugRouteNode(petID, nodeID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.nodeTransforms or not db.nodeTransforms[petID] then
        return nil
    end
    return db.nodeTransforms[petID][nodeID]
end

function YBP:GetDebugMinimapTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.minimapTransforms then
        return nil
    end
    return db.minimapTransforms[petID]
end

function YBP:GetDebugReferenceDisplayTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.referenceDisplayTransforms then
        return nil
    end
    return db.referenceDisplayTransforms[petID]
end

local function GetFormalReferenceDisplayTransform(petID)
    local route = ns.referenceRoutes and ns.referenceRoutes[petID] or nil
    local transform = route and route.referenceDisplayTransform or nil
    if not transform then
        return {
            offsetX = 0,
            offsetY = 0,
            scaleX = 1,
            scaleY = 1,
        }
    end

    return {
        offsetX = transform.offsetX or 0,
        offsetY = transform.offsetY or 0,
        scaleX = transform.scaleX or 1,
        scaleY = transform.scaleY or 1,
    }
end

function YBP:EnsureDebugReferenceDisplayTransform(petID, seedTransform)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return nil
    end

    db.referenceDisplayTransforms = db.referenceDisplayTransforms or {}
    if not db.referenceDisplayTransforms[petID] then
        local base = seedTransform or GetFormalReferenceDisplayTransform(petID)
        db.referenceDisplayTransforms[petID] = {
            offsetX = base.offsetX or 0,
            offsetY = base.offsetY or 0,
            scaleX = base.scaleX or 1,
            scaleY = base.scaleY or 1,
        }
    end

    return db.referenceDisplayTransforms[petID]
end

local function Round4(value)
    return math.floor((value or 0) * 10000 + 0.5) / 10000
end

local function BuildReferenceDisplayTransformSnapshot(self, petID)
    local formalTransform = self.GetFormalRouteTransform and self:GetFormalRouteTransform(petID) or {
        offsetX = 0,
        offsetY = 0,
        scale = 1,
        scaleX = 1,
        scaleY = 1,
    }
    local currentTransform = self.GetResolvedTransform and self:GetResolvedTransform(petID) or formalTransform
    local currentReference = self:GetDebugReferenceDisplayTransform(petID) or GetFormalReferenceDisplayTransform(petID)

    local formalScaleX = (formalTransform.scale or 1) * (formalTransform.scaleX or 1)
    local formalScaleY = (formalTransform.scale or 1) * (formalTransform.scaleY or 1)
    local currentScaleX = (currentTransform.scale or 1) * (currentTransform.scaleX or 1)
    local currentScaleY = (currentTransform.scale or 1) * (currentTransform.scaleY or 1)
    if math.abs(formalScaleX) < 0.0001 then
        formalScaleX = 1
    end
    if math.abs(formalScaleY) < 0.0001 then
        formalScaleY = 1
    end

    local referenceScaleX = currentReference.scaleX or 1
    local referenceScaleY = currentReference.scaleY or 1
    local savedScaleX = (currentScaleX * referenceScaleX) / formalScaleX
    local savedScaleY = (currentScaleY * referenceScaleY) / formalScaleY

    return {
        offsetX = Round4(((currentTransform.offsetX or 0) * referenceScaleX) + (currentReference.offsetX or 0) - ((formalTransform.offsetX or 0) * savedScaleX)),
        offsetY = Round4(((currentTransform.offsetY or 0) * referenceScaleY) + (currentReference.offsetY or 0) - ((formalTransform.offsetY or 0) * savedScaleY)),
        scaleX = Round4(savedScaleX),
        scaleY = Round4(savedScaleY),
    }
end

function YBP:SaveCurrentReferenceDisplayTransform(petID)
    if not petID then
        return false, "未选中宠物"
    end

    local route = (ns.referenceRoutes and ns.referenceRoutes[petID]) or (ns.curatedRoutes and ns.curatedRoutes[petID]) or nil
    if not route then
        return false, "当前宠物没有参考层可保存"
    end

    local snapshot = BuildReferenceDisplayTransformSnapshot(self, petID)
    self:EnsureDebugReferenceDisplayTransform(petID, snapshot)

    local db = _G.YiboBeastPathsDebugDB
    if db and db.referenceDisplayTransforms then
        db.referenceDisplayTransforms[petID] = snapshot
    end

    -- 参考层参数已经单独保存后，回退通用调试变换，避免再次叠加。
    if db and db.transforms then
        db.transforms[petID] = nil
    end

    -- 保存后立刻按新的参考层参数重算一次融合层，避免视觉上先跳回旧结果。
    if self.ResolveRouteForPet then
        self:ResolveRouteForPet(petID)
    else
        self:RefreshMapLayer()
        self:RefreshDebugPanel()
    end

    return true, snapshot
end

--- 确保当前选中宠物有调试参数（从正式参数复制初始值）
function YBP:EnsureDebugTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end
    if not db.transforms[petID] then
        -- 从正式配置复制作为初始值
        local formal = ns.routeTransforms and ns.routeTransforms[petID] or {}
        db.transforms[petID] = {
            offsetX = formal.offsetX or 0,
            offsetY = formal.offsetY or 0,
            scale = formal.scale or 1,
            scaleX = formal.scaleX or 1,
            scaleY = formal.scaleY or 1,
            thickness = formal.thickness or 1,
            opacity = formal.opacity or 1,
        }
    end
end

function YBP:EnsureDebugRouteNode(petID, nodeID)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    local formalNodes = ns.routeNodes and ns.routeNodes[petID]
    if not formalNodes then
        return
    end

    local formalNode
    for _, node in ipairs(formalNodes) do
        if node.id == nodeID then
            formalNode = node
            break
        end
    end
    if not formalNode then
        return
    end

    db.nodeTransforms[petID] = db.nodeTransforms[petID] or {}
    if not db.nodeTransforms[petID][nodeID] then
        db.nodeTransforms[petID][nodeID] = {
            normalizedX = formalNode.normalizedX or 0.5,
            normalizedY = formalNode.normalizedY or 0.5,
            nodeScale = formalNode.nodeScale or 1.0,
            isPlaceholder = false,
        }
    end
end

function YBP:EnsureDebugMinimapTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    db.minimapTransforms = db.minimapTransforms or {}
    if not db.minimapTransforms[petID] then
        local formal = ns.minimapTransforms and ns.minimapTransforms[petID] or {}
        db.minimapTransforms[petID] = {
            offsetX = formal.offsetX or 0,
            offsetY = formal.offsetY or 0,
            scale = formal.scale or 1,
            scaleX = formal.scaleX or 1,
            scaleY = formal.scaleY or 1,
            lineThickness = formal.lineThickness or 1,
        }
    else
        EnsureTableDefaults(db.minimapTransforms[petID], {
            offsetX = 0,
            offsetY = 0,
            scale = 1,
            scaleX = 1,
            scaleY = 1,
            lineThickness = 1,
        })
    end
end

function YBP:GetResolvedMinimapTransform(petID)
    local base = self.GetResolvedTransform and self:GetResolvedTransform(petID) or {
        offsetX = 0,
        offsetY = 0,
        scale = 1,
        scaleX = 1,
        scaleY = 1,
    }
    local formalMinimap = ns.minimapTransforms and ns.minimapTransforms[petID] or nil
    local minimap = self:GetDebugMinimapTransform(petID) or formalMinimap

    return {
        offsetX = base.offsetX or 0,
        offsetY = base.offsetY or 0,
        scale = base.scale or 1,
        scaleX = base.scaleX or 1,
        scaleY = base.scaleY or 1,
        minimapOffsetX = minimap and minimap.offsetX or 0,
        minimapOffsetY = minimap and minimap.offsetY or 0,
        minimapScale = minimap and minimap.scale or 1,
        minimapScaleX = minimap and minimap.scaleX or 1,
        minimapScaleY = minimap and minimap.scaleY or 1,
        minimapLineThickness = minimap and minimap.lineThickness or 1,
    }
end

function YBP:AdjustDebugValue(petID, field, delta)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end
    self:EnsureDebugTransform(petID)
    if db.transforms[petID] and db.transforms[petID][field] ~= nil then
        db.transforms[petID][field] = db.transforms[petID][field] + delta
        if field == "opacity" then
            if db.transforms[petID][field] < 0.10 then
                db.transforms[petID][field] = 0.10
            elseif db.transforms[petID][field] > 1.00 then
                db.transforms[petID][field] = 1.00
            end
        end
    end
    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:AdjustDebugRouteNodeValue(petID, nodeID, field, delta)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    self:EnsureDebugRouteNode(petID, nodeID)
    local node = db.nodeTransforms[petID] and db.nodeTransforms[petID][nodeID]
    if not node or node[field] == nil then
        return
    end

    node[field] = node[field] + delta
    if field == "nodeScale" then
        if node[field] < 0.50 then
            node[field] = 0.50
        elseif node[field] > 3.00 then
            node[field] = 3.00
        end
        node[field] = math.floor(node[field] * 100 + 0.5) / 100
    end

    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:AdjustDebugMinimapValue(petID, field, delta)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    self:EnsureDebugMinimapTransform(petID)
    if db.minimapTransforms and db.minimapTransforms[petID] and db.minimapTransforms[petID][field] ~= nil then
        db.minimapTransforms[petID][field] = db.minimapTransforms[petID][field] + delta
        if field == "scale" then
            if db.minimapTransforms[petID][field] < 0.10 then
                db.minimapTransforms[petID][field] = 0.10
            elseif db.minimapTransforms[petID][field] > 2.00 then
                db.minimapTransforms[petID][field] = 2.00
            end
        elseif field == "scaleX" or field == "scaleY" then
            if db.minimapTransforms[petID][field] < 0.10 then
                db.minimapTransforms[petID][field] = 0.10
            elseif db.minimapTransforms[petID][field] > 2.00 then
                db.minimapTransforms[petID][field] = 2.00
            end
        elseif field == "lineThickness" then
            if db.minimapTransforms[petID][field] < 0.40 then
                db.minimapTransforms[petID][field] = 0.40
            elseif db.minimapTransforms[petID][field] > 4.00 then
                db.minimapTransforms[petID][field] = 4.00
            end
            db.minimapTransforms[petID][field] = math.floor(db.minimapTransforms[petID][field] * 100 + 0.5) / 100
        end
    end

    if self.InvalidateMinimapRouteCache then
        self:InvalidateMinimapRouteCache()
    end
    if self.RefreshMapLayer then
        self:RefreshMapLayer()
    end
    if self.RefreshMinimapLayer then
        self:RefreshMinimapLayer(true)
    end
    self:RefreshDebugPanel()
end

function YBP:GetDebugRouteThickness()
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return 1.0
    end
    local transform = self:GetResolvedTransform(petID)
    return transform and transform.thickness or 1.0
end

function YBP:AdjustDebugRouteThickness(delta)
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return
    end
    self:EnsureDebugTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.transforms or not db.transforms[petID] then
        return
    end
    local value = (db.transforms[petID].thickness or 1.0) + delta
    if value < 0.4 then
        value = 0.4
    elseif value > 4.0 then
        value = 4.0
    end

    db.transforms[petID].thickness = math.floor(value * 100 + 0.5) / 100
    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:ResetDebugTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end
    if db.transforms then
        db.transforms[petID] = nil
    end
    if db.referenceDisplayTransforms then
        db.referenceDisplayTransforms[petID] = nil
    end
    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:ResetDebugMinimapTransform(petID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.minimapTransforms then
        return
    end

    db.minimapTransforms[petID] = nil
    if self.InvalidateMinimapRouteCache then
        self:InvalidateMinimapRouteCache()
    end
    if self.RefreshMinimapLayer then
        self:RefreshMinimapLayer(true)
    end
    self:RefreshDebugPanel()
end

function YBP:ResetDebugRouteNode(petID, nodeID)
    local db = _G.YiboBeastPathsDebugDB
    if not db or not db.nodeTransforms or not db.nodeTransforms[petID] then
        return
    end

    db.nodeTransforms[petID][nodeID] = nil
    if not next(db.nodeTransforms[petID]) then
        db.nodeTransforms[petID] = nil
    end

    self:RefreshMapLayer()
    self:RefreshDebugPanel()
end

function YBP:GetCurrentPlayerMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil
    end

    local mapID = C_Map.GetBestMapForUnit("player") or self:GetCurrentWorldMapID()
    if not mapID then
        return nil
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end

    return mapID, position.x, position.y
end

function YBP:CaptureCurrentFootprintForSelectedPet()
    local petID = self:GetSelectedDebugPetID()
    if not petID or not self.AddFootprintAnchor then
        return false, "未选中宠物"
    end

    local mapID, x, y = self:GetCurrentPlayerMapPosition()
    if not mapID or not x or not y then
        return false, "无法获取当前角色坐标"
    end

    self:AddFootprintAnchor(petID, mapID, x, y, "Captured in debug panel", false)
    return true, string.format("已记录脚印 %.4f, %.4f", x, y)
end

----------------------------------------------------------------
-- 导出功能
----------------------------------------------------------------

local function FormatTransformEntry(petID, transform)
    return string.format(
        "[%d] = { offsetX = %s, offsetY = %s, scale = %s, scaleX = %s, scaleY = %s, thickness = %s, opacity = %s },",
        petID,
        FormatFloat(transform.offsetX),
        FormatFloat(transform.offsetY),
        FormatFloat(transform.scale),
        FormatFloat(transform.scaleX),
        FormatFloat(transform.scaleY),
        FormatFloat(transform.thickness or 1.0),
        FormatFloat(transform.opacity or 1.0)
    )
end

local function FormatRouteNodeEntry(petID, node)
    return string.format(
        "[%d] = { { id = \"%s\", role = \"%s\", normalizedX = %s, normalizedY = %s, nodeScale = %s, isPlaceholder = false }, },",
        petID,
        node.id or "start",
        node.role or "start",
        FormatFloat(node.normalizedX or 0.5),
        FormatFloat(node.normalizedY or 0.5),
        FormatFloat(node.nodeScale or 1.0)
    )
end

local function FormatMinimapTransformEntry(petID, transform)
    return string.format(
        "[%d] = { offsetX = %s, offsetY = %s, scale = %s, scaleX = %s, scaleY = %s, lineThickness = %s },",
        petID,
        FormatFloat(transform.offsetX or 0),
        FormatFloat(transform.offsetY or 0),
        FormatFloat(transform.scale or 1),
        FormatFloat(transform.scaleX or 1),
        FormatFloat(transform.scaleY or 1),
        FormatFloat(transform.lineThickness or 1)
    )
end

local function FormatReferenceDisplayTransformEntry(petID, transform)
    return string.format(
        "[%d] = { referenceDisplayTransform = { offsetX = %s, offsetY = %s, scaleX = %s, scaleY = %s } },",
        petID,
        FormatFloat(transform.offsetX or 0),
        FormatFloat(transform.offsetY or 0),
        FormatFloat(transform.scaleX or 1),
        FormatFloat(transform.scaleY or 1)
    )
end

local function SerializeLua(value, indent)
    indent = indent or 0
    local padding = string.rep("    ", indent)
    local childPadding = string.rep("    ", indent + 1)

    if type(value) == "number" then
        return FormatFloat(value)
    end
    if type(value) == "boolean" then
        return value and "true" or "false"
    end
    if type(value) == "string" then
        return string.format("%q", value)
    end
    if type(value) ~= "table" then
        return "nil"
    end

    local isArray = true
    local maxIndex = 0
    for key in pairs(value) do
        if type(key) ~= "number" then
            isArray = false
            break
        end
        if key > maxIndex then
            maxIndex = key
        end
    end

    local parts = { "{\n" }
    if isArray then
        for index = 1, maxIndex do
            parts[#parts + 1] = childPadding .. SerializeLua(value[index], indent + 1) .. ",\n"
        end
    else
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = string.format("%s%s = %s,\n", childPadding, tostring(key), SerializeLua(value[key], indent + 1))
        end
    end
    parts[#parts + 1] = padding .. "}"
    return table.concat(parts)
end

function YBP:ExportCurrentDebugTransform()
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return ""
    end

    -- 优先导出调试参数，若没有则导出正式参数
    local debugT = self:GetDebugTransform(petID)
    local transform = debugT or (ns.routeTransforms and ns.routeTransforms[petID])
    if not transform then
        return ""
    end

    local lines = {
        "-- RouteTransforms.lua",
        FormatTransformEntry(petID, transform),
    }

    local minimapTransform = self:GetDebugMinimapTransform(petID) or (ns.minimapTransforms and ns.minimapTransforms[petID])
    if minimapTransform then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- DebugMinimapOffsets"
        lines[#lines + 1] = FormatMinimapTransformEntry(petID, minimapTransform)
    end

    local referenceDisplayTransform = self:GetDebugReferenceDisplayTransform(petID)
        or ((ns.referenceRoutes and ns.referenceRoutes[petID]) and ns.referenceRoutes[petID].referenceDisplayTransform)
    if referenceDisplayTransform then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- ReferenceRoutes.lua"
        lines[#lines + 1] = FormatReferenceDisplayTransformEntry(petID, referenceDisplayTransform)
    end

    local nodes = self.GetResolvedRouteNodes and self:GetResolvedRouteNodes(petID) or nil
    if nodes and nodes[1] then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- RouteNodes.lua"
        lines[#lines + 1] = FormatRouteNodeEntry(petID, nodes[1])
    end

    return table.concat(lines, "\n")
end

function YBP:ExportCurrentMapDebugTransforms()
    local mapID = self:GetCurrentWorldMapID()
    if not mapID then
        return ""
    end

    local petIDs = self:GetVisiblePetIDsForMap(mapID)
    if #petIDs == 0 then
        return ""
    end

    local transformLines = {}
    local minimapLines = {}
    local referenceLines = {}
    local nodeLines = {}
    table.sort(petIDs)
    for _, petID in ipairs(petIDs) do
        local debugT = self:GetDebugTransform(petID)
        local transform = debugT or (ns.routeTransforms and ns.routeTransforms[petID])
        if transform then
            transformLines[#transformLines + 1] = FormatTransformEntry(petID, transform)
        end

        local minimapTransform = self:GetDebugMinimapTransform(petID) or (ns.minimapTransforms and ns.minimapTransforms[petID])
        if minimapTransform then
            minimapLines[#minimapLines + 1] = FormatMinimapTransformEntry(petID, minimapTransform)
        end

        local referenceDisplayTransform = self:GetDebugReferenceDisplayTransform(petID)
            or ((ns.referenceRoutes and ns.referenceRoutes[petID]) and ns.referenceRoutes[petID].referenceDisplayTransform)
        if referenceDisplayTransform then
            referenceLines[#referenceLines + 1] = FormatReferenceDisplayTransformEntry(petID, referenceDisplayTransform)
        end

        local nodes = self.GetResolvedRouteNodes and self:GetResolvedRouteNodes(petID) or nil
        if nodes and nodes[1] then
            nodeLines[#nodeLines + 1] = FormatRouteNodeEntry(petID, nodes[1])
        end
    end

    local lines = {}
    if #transformLines > 0 then
        lines[#lines + 1] = "-- RouteTransforms.lua"
        for _, line in ipairs(transformLines) do
            lines[#lines + 1] = line
        end
    end

    if #nodeLines > 0 then
        if #lines > 0 then
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "-- RouteNodes.lua"
        for _, line in ipairs(nodeLines) do
            lines[#lines + 1] = line
        end
    end

    if #minimapLines > 0 then
        if #lines > 0 then
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "-- DebugMinimapOffsets"
        for _, line in ipairs(minimapLines) do
            lines[#lines + 1] = line
        end
    end

    if #referenceLines > 0 then
        if #lines > 0 then
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "-- ReferenceRoutes.lua"
        for _, line in ipairs(referenceLines) do
            lines[#lines + 1] = line
        end
    end

    return table.concat(lines, "\n")
end

function YBP:ExportCurrentRouteFusionSnapshot()
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return ""
    end

    local footprintStore = self.GetFootprintStore and self:GetFootprintStore(petID) or nil
    local resolvedRoute = self.GetResolvedRoute and self:GetResolvedRoute(petID) or nil
    local lines = {}

    if footprintStore then
        lines[#lines + 1] = "-- FootprintAnchors.lua"
        lines[#lines + 1] = string.format("[%d] = %s", petID, SerializeLua(footprintStore, 0))
    end

    if resolvedRoute then
        if #lines > 0 then
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "-- ResolvedRoutes.lua"
        lines[#lines + 1] = string.format("[%d] = %s", petID, SerializeLua(resolvedRoute, 0))
    end

    return table.concat(lines, "\n")
end

function YBP:ExportCurrentFootprintAnchorsSnippet()
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return ""
    end

    local footprintStore = self.GetFootprintStore and self:GetFootprintStore(petID) or nil
    if not footprintStore then
        return ""
    end

    return table.concat({
        "-- Target: FootprintAnchors.lua",
        string.format("[%d] = %s", petID, SerializeLua(footprintStore, 0)),
    }, "\n")
end

function YBP:ExportCurrentResolvedRouteSnippet()
    local petID = self:GetSelectedDebugPetID()
    if not petID then
        return ""
    end

    local resolvedRoute = self.GetResolvedRoute and self:GetResolvedRoute(petID) or nil
    if not resolvedRoute then
        return ""
    end

    return table.concat({
        "-- Target: ResolvedRoutes.lua",
        string.format("[%d] = %s", petID, SerializeLua(resolvedRoute, 0)),
    }, "\n")
end

function YBP:ExportCurrentMapRouteFusionSnapshot()
    local mapID = self:GetCurrentWorldMapID()
    if not mapID then
        return ""
    end

    local petIDs = self:GetVisiblePetIDsForMap(mapID)
    if #petIDs == 0 then
        return ""
    end

    table.sort(petIDs)

    local footprintLines = {}
    local resolvedLines = {}
    for _, petID in ipairs(petIDs) do
        local footprintStore = self.GetFootprintStore and self:GetFootprintStore(petID) or nil
        if footprintStore and footprintStore.points and #footprintStore.points > 0 then
            footprintLines[#footprintLines + 1] = string.format("[%d] = %s", petID, SerializeLua(footprintStore, 0))
        end

        local resolvedRoute = self.GetResolvedRoute and self:GetResolvedRoute(petID) or nil
        if resolvedRoute then
            resolvedLines[#resolvedLines + 1] = string.format("[%d] = %s", petID, SerializeLua(resolvedRoute, 0))
        end
    end

    local lines = {
        string.format("-- Map snapshot: %d", mapID),
    }
    if #footprintLines > 0 then
        lines[#lines + 1] = "-- Target: FootprintAnchors.lua"
        for _, line in ipairs(footprintLines) do
            lines[#lines + 1] = line
        end
    end
    if #resolvedLines > 0 then
        if #lines > 1 then
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "-- Target: ResolvedRoutes.lua"
        for _, line in ipairs(resolvedLines) do
            lines[#lines + 1] = line
        end
    end

    return table.concat(lines, "\n")
end

----------------------------------------------------------------
-- 面板构建
----------------------------------------------------------------

local panel = nil
local panelElements = {}
local FOOTPRINT_LIST_PAGE_SIZE = 6

GetDebugUIState = function()
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return nil
    end

    db.ui = db.ui or {}
    EnsureTableDefaults(db.ui, debugDefaults.ui)
    EnsureTableDefaults(db.ui.collapsedSections, debugDefaults.ui.collapsedSections)
    return db.ui
end

IsSectionCollapsed = function(sectionKey)
    local ui = GetDebugUIState()
    return ui and ui.collapsedSections and ui.collapsedSections[sectionKey] or false
end

function YBP:ShouldShowRouteNodesOnMap(petID)
    if not (self.IsDebugEnabled and self:IsDebugEnabled()) then
        return false
    end

    local ui = GetDebugUIState()
    if not ui or ui.activeTab ~= "calibrate" then
        return false
    end

    if ui.collapsedSections and ui.collapsedSections.nodeAdjust then
        return false
    end

    local selectedPetID = self.GetSelectedDebugPetID and self:GetSelectedDebugPetID() or nil
    if selectedPetID and petID and selectedPetID ~= petID then
        return false
    end

    return true
end

local function ApplySavedPanelPosition(frame)
    local db = _G.YiboBeastPathsDebugDB
    local ui = db and db.ui or nil
    frame:ClearAllPoints()
    if ui and ui.panelPoint and ui.panelRelativePoint and ui.panelX and ui.panelY then
        frame:SetPoint(ui.panelPoint, UIParent, ui.panelRelativePoint, ui.panelX, ui.panelY)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
    end
end

local function SavePanelPosition(frame)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    db.ui = db.ui or {}
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    db.ui.panelPoint = point or "RIGHT"
    db.ui.panelRelativePoint = relativePoint or "RIGHT"
    db.ui.panelX = x or -20
    db.ui.panelY = y or 0
end

local function ApplySavedPanelSize(frame)
    local db = _G.YiboBeastPathsDebugDB
    local ui = db and db.ui or nil
    local width = ui and ui.panelWidth or debugDefaults.ui.panelWidth or 760
    local height = ui and ui.panelHeight or debugDefaults.ui.panelHeight or 720
    frame:SetSize(math.max(620, width), math.max(520, height))
end

local function SavePanelSize(frame)
    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    db.ui = db.ui or {}
    db.ui.panelWidth = math.floor(frame:GetWidth() + 0.5)
    db.ui.panelHeight = math.floor(frame:GetHeight() + 0.5)
end

local function SetElementShown(element, shown)
    if not element then
        return
    end

    if element.SetShown then
        element:SetShown(shown)
    elseif shown then
        element:Show()
    else
        element:Hide()
    end
end

local function SetElementsShown(elements, shown)
    for _, element in ipairs(elements or {}) do
        SetElementShown(element, shown)
    end
end

local function UpdateSectionToggleButton(button, title, collapsed)
    if button and button.SetText then
        button:SetText(string.format("%s %s", collapsed and "[+]" or "[-]", title))
    end
end

local function IsSectionOnActiveTab(sectionKey)
    local tabKey = sectionTabs[sectionKey]
    if not tabKey then
        return true
    end
    return tabKey == YBP:GetActiveDebugTab()
end

local function ShouldSectionBeVisible(sectionKey)
    return IsSectionOnActiveTab(sectionKey)
end

local function CaptureAnchorPoints(element)
    if not element or element.__ybpAnchorPoints then
        return
    end

    local points = {}
    for index = 1, 4 do
        local point, relativeTo, relativePoint, x, y = element:GetPoint(index)
        if not point then
            break
        end
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    element.__ybpAnchorPoints = points
end

local function ApplyAnchorOffset(element, deltaY)
    if not element or not element.__ybpAnchorPoints then
        return
    end

    element:ClearAllPoints()
    for _, anchor in ipairs(element.__ybpAnchorPoints) do
        element:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, (anchor.y or 0) + (deltaY or 0))
    end
end

local function CollectVisibleElementBottom(element, currentBottom)
    if not element or not element.IsShown or not element:IsShown() or not element.GetBottom then
        return currentBottom
    end

    local bottom = element:GetBottom()
    if not bottom then
        return currentBottom
    end

    if not currentBottom or bottom < currentBottom then
        return bottom
    end
    return currentBottom
end

local function GetElementPrimaryY(element)
    if not element or not element.GetPoint then
        return nil
    end

    local _, _, _, _, y = element:GetPoint(1)
    return y
end

local function AlignSectionTop(sectionKey, desiredY, baseShift, layout)
    local meta = layout and layout[sectionKey] or nil
    local anchorElement = meta and meta.movableElements and meta.movableElements[1] or nil
    local currentY = GetElementPrimaryY(anchorElement)
    if not meta or not currentY or not desiredY then
        return
    end

    local delta = desiredY - currentY
    if delta == 0 then
        return
    end

    for _, element in ipairs(meta.movableElements or {}) do
        ApplyAnchorOffset(element, (baseShift or 0) + delta)
    end
end

local function ApplyExportTabLayout()
    if not panel or not panelElements.exportSection or not panelElements.exportFrame then
        return
    end

    panelElements.exportSection:ClearAllPoints()
    panelElements.exportSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -286)

    panelElements.exportFrame:ClearAllPoints()
    panelElements.exportFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -312)
    panelElements.exportFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 54)
end

ApplyDynamicLayout = function()
    if not panel then
        return
    end

    local layout = panelElements.sectionLayout or {}
    local totalCollapsed = 0
    local activeTab = YBP:GetActiveDebugTab()
    local sectionBaseShift = {}

    for _, section in ipairs(layout.order or {}) do
        local meta = layout[section]
        if meta then
            local shift = totalCollapsed
            sectionBaseShift[section] = shift
            for _, element in ipairs(meta.movableElements or {}) do
                ApplyAnchorOffset(element, shift)
            end

            if not ShouldSectionBeVisible(section) then
                totalCollapsed = totalCollapsed + (meta.collapseHeight or 0)
            end
        end
    end

    if activeTab == "calibrate" then
        AlignSectionTop("routeNav", -212, sectionBaseShift.routeNav, layout)
        AlignSectionTop("mapAdjust", -288, sectionBaseShift.mapAdjust, layout)
        AlignSectionTop("nodeAdjust", -396, sectionBaseShift.nodeAdjust, layout)
        AlignSectionTop("minimapAdjust", -466, sectionBaseShift.minimapAdjust, layout)
    else
        local desiredTopBySection = {
            fusion = -288,
            footprintList = -288,
            export = -288,
        }
        local primarySectionByTab = {
            fusion = "fusion",
            footprints = "footprintList",
            export = "export",
        }
        local primarySection = primarySectionByTab[activeTab]
        if primarySection then
            AlignSectionTop(primarySection, desiredTopBySection[primarySection], sectionBaseShift[primarySection], layout)
        end
    end

    if activeTab == "export" then
        ApplyExportTabLayout()
    end

    local fallbackHeight = layout.basePanelHeight and (layout.basePanelHeight - totalCollapsed) or nil
    local panelTop = panel:GetTop()
    local lowestBottom = nil

    for _, element in ipairs(panelElements.autoHeightElements or {}) do
        lowestBottom = CollectVisibleElementBottom(element, lowestBottom)
    end

    if panelTop and lowestBottom then
        local contentHeight = math.ceil((panelTop - lowestBottom) + 20)
        local minHeight = layout.minPanelHeight or 320
        local ui = GetDebugUIState()
        local preferredHeight = ui and ui.panelHeight or minHeight
        panel:SetHeight(math.max(minHeight, preferredHeight, contentHeight))
    elseif fallbackHeight then
        local ui = GetDebugUIState()
        local preferredHeight = ui and ui.panelHeight or fallbackHeight
        panel:SetHeight(math.max(fallbackHeight, preferredHeight))
    end
end

ApplySectionVisibility = function()
    for sectionKey, elements in pairs(panelElements.sectionContents or {}) do
        SetElementsShown(elements, ShouldSectionBeVisible(sectionKey))
    end

    for _, toggleButton in ipairs({
        panelElements.routeToggleBtn,
        panelElements.mapAdjustToggleBtn,
        panelElements.nodeToggleBtn,
        panelElements.minimapToggleBtn,
        panelElements.fusionToggleBtn,
        panelElements.footprintListToggleBtn,
        panelElements.exportToggleBtn,
    }) do
        if toggleButton then
            toggleButton:Hide()
        end
    end

    ApplyDynamicLayout()

    local activeTab = YBP:GetActiveDebugTab()
    for tabKey, button in pairs(panelElements.tabButtons or {}) do
        if button and button.SetText then
            button:SetText(string.format("%s %s", activeTab == tabKey and "[当前]" or "[切换]", tabLabels[tabKey] or tabKey))
        end
    end
end

local function GetOrCreatePanel()
    if panel then
        return panel
    end

    -- 根面板
    panel = CreateFrame("Frame", "TTRDebugPanel", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    ApplySavedPanelPosition(panel)
    ApplySavedPanelSize(panel)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.12, 0.92)
    panel:SetBackdropBorderColor(0.40, 0.55, 0.90, 0.85)
    panel:SetMovable(true)
    if panel.SetResizable then
        panel:SetResizable(true)
    end
    if panel.SetResizeBounds then
        panel:SetResizeBounds(620, 520)
    elseif panel.SetMinResize then
        panel:SetMinResize(620, 520)
    end
    if panel.SetClampedToScreen then
        panel:SetClampedToScreen(true)
    end
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePanelPosition(self)
        SavePanelSize(self)
    end)
    panel:SetScript("OnSizeChanged", function(self)
        SavePanelSize(self)
        ApplyDynamicLayout()
    end)
    panel:Hide()

    panelElements.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panelElements.title:SetPoint("TOP", panel, "TOP", 0, -6)
    panelElements.title:SetText("调试校准工作台")
    panelElements.title:SetTextColor(0.70, 0.85, 1.0)

    -- 关闭按钮
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        YBP:SetDebugEnabled(false)
    end)
    panelElements.closeBtn = closeBtn

    local resizeHandle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resizeHandle:SetSize(20, 20)
    resizeHandle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    resizeHandle:SetText("↘")
    resizeHandle:SetScript("OnMouseDown", function()
        if panel.StartSizing then
            panel:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        SavePanelSize(panel)
        ApplyDynamicLayout()
    end)
    panelElements.resizeHandle = resizeHandle

    local yOff = -30

    -- === 区块 1：当前状态区 ===
    local stateY = yOff

    panelElements.petIconBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panelElements.petIconBg:SetSize(42, 42)
    panelElements.petIconBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 2)
    panelElements.petIconBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panelElements.petIconBg:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    panelElements.petIconBg:SetBackdropBorderColor(0.75, 0.55, 0.18, 0.78)

    panelElements.petIcon = panelElements.petIconBg:CreateTexture(nil, "ARTWORK")
    panelElements.petIcon:SetPoint("TOPLEFT", panelElements.petIconBg, "TOPLEFT", 4, -4)
    panelElements.petIcon:SetPoint("BOTTOMRIGHT", panelElements.petIconBg, "BOTTOMRIGHT", -4, 4)
    panelElements.petIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panelElements.petIcon:SetTexture("Interface\\Icons\\Ability_Tracking")

    panelElements.petFootprint = panel:CreateTexture(nil, "OVERLAY")
    panelElements.petFootprint:SetSize(18, 18)
    panelElements.petFootprint:SetPoint("BOTTOMLEFT", panelElements.petIconBg, "BOTTOMLEFT", 26, -4)
    panelElements.petFootprint:SetTexture("Interface\\Icons\\Ability_Tracking")
    panelElements.petFootprint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panelElements.petFootprint:SetVertexColor(1.00, 0.82, 0.18, 1.00)

    panelElements.mapText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.mapText:SetPoint("TOPLEFT", panel, "TOPLEFT", 60, stateY)
    panelElements.mapText:SetText("地图: -")

    panelElements.petText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.petText:SetPoint("TOPLEFT", panel, "TOPLEFT", 60, stateY - 18)
    panelElements.petText:SetText("宠物: -")

    panelElements.paramText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.paramText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 52)
    panelElements.paramText:SetWidth(592)
    panelElements.paramText:SetJustifyH("LEFT")
    panelElements.paramText:SetText("位置: X —  Y —  缩放 —")

    panelElements.thicknessText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.thicknessText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 68)
    panelElements.thicknessText:SetText("线宽: —")

    panelElements.opacityText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.opacityText:SetPoint("TOPLEFT", panel, "TOPLEFT", 110, stateY - 68)
    panelElements.opacityText:SetText("透明: —")

    panelElements.advParamText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.advParamText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 84)
    panelElements.advParamText:SetWidth(592)
    panelElements.advParamText:SetJustifyH("LEFT")
    panelElements.advParamText:SetText("横向缩放: —  纵向缩放: —")

    panelElements.nodeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.nodeText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 104)
    panelElements.nodeText:SetWidth(592)
    panelElements.nodeText:SetJustifyH("LEFT")
    panelElements.nodeText:SetText("节点: X —  Y —  大小 —")

    panelElements.minimapText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.minimapText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 120)
    panelElements.minimapText:SetWidth(592)
    panelElements.minimapText:SetJustifyH("LEFT")
    panelElements.minimapText:SetText("小图偏移: X —  Y —  缩放 —  横缩 —  竖缩 —  线宽 —")

    panelElements.fusionText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.fusionText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stateY - 136)
    panelElements.fusionText:SetWidth(592)
    panelElements.fusionText:SetJustifyH("LEFT")
    panelElements.fusionText:SetText("融合: 脚印 —  自动重算 —  显示层 —")

    local divider1 = panel:CreateTexture(nil, "OVERLAY")
    divider1:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider1:SetVertexColor(0.4, 0.55, 0.9, 0.3)
    divider1:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, stateY - 158)
    divider1:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, stateY - 158)
    divider1:SetHeight(1)

    -- === 区块 2：路径切换区 ===
    local navY = stateY - 186

    panelElements.routeSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.routeSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, navY + 4)
    panelElements.routeSection:SetText("当前路线")
    panelElements.routeSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.routeToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.routeToggleBtn:SetSize(88, 20)
    panelElements.routeToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, navY + 8)
    panelElements.routeToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("routeNav")
    end)

    local prevBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    prevBtn:SetSize(120, 22)
    prevBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 126, navY)
    prevBtn:SetText("上一条")
    prevBtn:SetScript("OnClick", function()
        local petIDs = YBP:GetDebugPetIDsForCurrentMap()
        local selected = YBP:GetSelectedDebugPetID()
        if #petIDs == 0 then
            return
        end
        local idx = 1
        for i, id in ipairs(petIDs) do
            if id == selected then
                idx = i
                break
            end
        end
        idx = idx - 1
        if idx < 1 then
            idx = #petIDs
        end
        YBP:SetSelectedDebugPetID(petIDs[idx])
    end)
    panelElements.prevBtn = prevBtn

    local nextBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    nextBtn:SetSize(120, 22)
    nextBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -126, navY)
    nextBtn:SetText("下一条")
    nextBtn:SetScript("OnClick", function()
        local petIDs = YBP:GetDebugPetIDsForCurrentMap()
        local selected = YBP:GetSelectedDebugPetID()
        if #petIDs == 0 then
            return
        end
        local idx = 1
        for i, id in ipairs(petIDs) do
            if id == selected then
                idx = i
                break
            end
        end
        idx = idx + 1
        if idx > #petIDs then
            idx = 1
        end
        YBP:SetSelectedDebugPetID(petIDs[idx])
    end)
    panelElements.nextBtn = nextBtn

    local divider2 = panel:CreateTexture(nil, "OVERLAY")
    divider2:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider2:SetVertexColor(0.4, 0.55, 0.9, 0.3)
    divider2:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, navY - 22)
    divider2:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, navY - 22)
    divider2:SetHeight(1)

    local tabsY = navY - 34

    panelElements.tabsSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.tabsSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, tabsY + 10)
    panelElements.tabsSection:SetText("工作区")
    panelElements.tabsSection:SetTextColor(0.72, 0.86, 1.00)

    panelElements.tabButtons = {}
    local tabOrder = { "calibrate", "fusion", "footprints", "export" }
    local tabLeft = 104
    for _, tabKey in ipairs(tabOrder) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(110, 22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", tabLeft, tabsY)
        btn:SetScript("OnClick", function()
            YBP:SetActiveDebugTab(tabKey)
        end)
        panelElements.tabButtons[tabKey] = btn
        tabLeft = tabLeft + 118
    end

    local dividerTabs = panel:CreateTexture(nil, "OVERLAY")
    dividerTabs:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    dividerTabs:SetVertexColor(0.4, 0.55, 0.9, 0.3)
    dividerTabs:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, tabsY - 26)
    dividerTabs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, tabsY - 26)
    dividerTabs:SetHeight(1)
    panelElements.dividerTabs = dividerTabs

    -- === 区块 3：参数调节区 ===
    local adjY = tabsY - 52

    panelElements.routeAdjustSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.routeAdjustSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, adjY + 14)
    panelElements.routeAdjustSection:SetText("大地图路线调整")
    panelElements.routeAdjustSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.mapAdjustToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.mapAdjustToggleBtn:SetSize(88, 20)
    panelElements.mapAdjustToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, adjY + 18)
    panelElements.mapAdjustToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("mapAdjust")
    end)

    -- 行 1: X-, X+, Y-, Y+, Scale-, Scale+
    local function MakeAdjustButton(parent, text, left, top, width, petID, field, delta)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(width or 42, 22)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
        btn:SetText(text)
        btn:SetScript("OnClick", function()
            local pid = YBP:GetSelectedDebugPetID()
            if pid then
                local db = _G.YiboBeastPathsDebugDB
                local step = db.ui.stepMove
                if field == "__nodeX" then
                    YBP:AdjustDebugRouteNodeValue(pid, "start", "normalizedX", delta * step)
                elseif field == "__nodeY" then
                    YBP:AdjustDebugRouteNodeValue(pid, "start", "normalizedY", delta * step)
                elseif field == "__nodeScale" then
                    YBP:AdjustDebugRouteNodeValue(pid, "start", "nodeScale", delta * db.ui.stepScale)
                elseif field == "__mmOffsetX" then
                    YBP:AdjustDebugMinimapValue(pid, "offsetX", delta * step)
                elseif field == "__mmOffsetY" then
                    YBP:AdjustDebugMinimapValue(pid, "offsetY", delta * step)
                elseif field == "__mmScale" then
                    YBP:AdjustDebugMinimapValue(pid, "scale", delta * db.ui.stepScale)
                elseif field == "__mmScaleX" then
                    YBP:AdjustDebugMinimapValue(pid, "scaleX", delta * db.ui.stepScale)
                elseif field == "__mmScaleY" then
                    YBP:AdjustDebugMinimapValue(pid, "scaleY", delta * db.ui.stepScale)
                elseif field == "__mmLineThickness" then
                    YBP:AdjustDebugMinimapValue(pid, "lineThickness", delta * db.ui.stepScale)
                else
                    YBP:EnsureDebugTransform(pid)
                    step = (field:find("scale") or field:find("Scale"))
                        and db.ui.stepScale or db.ui.stepMove
                    YBP:AdjustDebugValue(pid, field, delta * step)
                end
            end
        end)
        return btn
    end

    local function MakeStepButton(parent, text, left, top, width, stepKey)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(width or 42, 22)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
        btn:SetText(text)
        btn:SetScript("OnClick", function()
            local db = _G.YiboBeastPathsDebugDB
            if not db then
                return
            end
            local preset = stepPresets[stepKey]
            if preset then
                db.ui.stepMove = preset.move
                db.ui.stepScale = preset.scale
            end
            YBP:RefreshDebugPanel()
        end)
        return btn
    end

    -- 常用调节行
    panelElements.btnXMinus = MakeAdjustButton(panel, GetButtonLabel("offsetX", -1), 14, adjY - 8, 86, nil, "offsetX", -1)
    panelElements.btnXPlus = MakeAdjustButton(panel, GetButtonLabel("offsetX", 1), 110, adjY - 8, 86, nil, "offsetX", 1)
    panelElements.btnYMinus = MakeAdjustButton(panel, GetButtonLabel("offsetY", -1), 206, adjY - 8, 86, nil, "offsetY", -1)
    panelElements.btnYPlus = MakeAdjustButton(panel, GetButtonLabel("offsetY", 1), 302, adjY - 8, 86, nil, "offsetY", 1)
    panelElements.btnSMinus = MakeAdjustButton(panel, GetButtonLabel("scale", -1), 398, adjY - 8, 86, nil, "scale", -1)
    panelElements.btnSPlus = MakeAdjustButton(panel, GetButtonLabel("scale", 1), 494, adjY - 8, 86, nil, "scale", 1)

    local thickY = adjY - 34
    panelElements.btnTMinus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnTMinus:SetSize(136, 22)
    panelElements.btnTMinus:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, thickY)
    panelElements.btnTMinus:SetText("线条变细")
    panelElements.btnTMinus:SetScript("OnClick", function()
        YBP:AdjustDebugRouteThickness(-0.10)
    end)

    panelElements.btnTPlus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnTPlus:SetSize(136, 22)
    panelElements.btnTPlus:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, thickY)
    panelElements.btnTPlus:SetText("线条变粗")
    panelElements.btnTPlus:SetScript("OnClick", function()
        YBP:AdjustDebugRouteThickness(0.10)
    end)

    panelElements.btnOMinus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnOMinus:SetSize(136, 22)
    panelElements.btnOMinus:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, thickY)
    panelElements.btnOMinus:SetText("更透明")
    panelElements.btnOMinus:SetScript("OnClick", function()
        local pid = YBP:GetSelectedDebugPetID()
        if pid then
            YBP:AdjustDebugValue(pid, "opacity", -0.05)
        end
    end)

    panelElements.btnOPlus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnOPlus:SetSize(136, 22)
    panelElements.btnOPlus:SetPoint("TOPLEFT", panel, "TOPLEFT", 466, thickY)
    panelElements.btnOPlus:SetText("更明显")
    panelElements.btnOPlus:SetScript("OnClick", function()
        local pid = YBP:GetSelectedDebugPetID()
        if pid then
            YBP:AdjustDebugValue(pid, "opacity", 0.05)
        end
    end)

    -- 高级调节行（默认隐藏）
    local advY = thickY - 34
    panelElements.btnSXMinus = MakeAdjustButton(panel, GetButtonLabel("scaleX", -1), 84, advY, 136, nil, "scaleX", -1)
    panelElements.btnSXPlus = MakeAdjustButton(panel, GetButtonLabel("scaleX", 1), 230, advY, 136, nil, "scaleX", 1)
    panelElements.btnSYMinus = MakeAdjustButton(panel, GetButtonLabel("scaleY", -1), 376, advY, 136, nil, "scaleY", -1)
    panelElements.btnSYPlus = MakeAdjustButton(panel, GetButtonLabel("scaleY", 1), 522, advY, 84, nil, "scaleY", 1)

    local nodeY = advY - 36

    panelElements.nodeSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.nodeSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, nodeY + 10)
    panelElements.nodeSection:SetText("起点节点调整")
    panelElements.nodeSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.nodeToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.nodeToggleBtn:SetSize(88, 20)
    panelElements.nodeToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, nodeY + 14)
    panelElements.nodeToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("nodeAdjust")
    end)

    panelElements.btnNXMinus = MakeAdjustButton(panel, GetButtonLabel("__nodeX", -1), 14, nodeY - 8, 90, nil, "__nodeX", -1)
    panelElements.btnNXPlus = MakeAdjustButton(panel, GetButtonLabel("__nodeX", 1), 114, nodeY - 8, 90, nil, "__nodeX", 1)
    panelElements.btnNYMinus = MakeAdjustButton(panel, GetButtonLabel("__nodeY", -1), 214, nodeY - 8, 90, nil, "__nodeY", -1)
    panelElements.btnNYPlus = MakeAdjustButton(panel, GetButtonLabel("__nodeY", 1), 314, nodeY - 8, 90, nil, "__nodeY", 1)
    panelElements.btnNSMinus = MakeAdjustButton(panel, GetButtonLabel("__nodeScale", -1), 414, nodeY - 8, 90, nil, "__nodeScale", -1)
    panelElements.btnNSPlus = MakeAdjustButton(panel, GetButtonLabel("__nodeScale", 1), 514, nodeY - 8, 90, nil, "__nodeScale", 1)

    -- 步进行
    local stepY = nodeY - 36
    panelElements.stepLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.stepLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, stepY - 3)
    panelElements.stepLabel:SetText("共用步进:")

    panelElements.btnStepFine = MakeStepButton(panel, "细调", 86, stepY, 78, "fine")
    panelElements.btnStepMed = MakeStepButton(panel, "中调", 176, stepY, 78, "medium")
    panelElements.btnStepCoarse = MakeStepButton(panel, "粗调", 266, stepY, 78, "coarse")

    panelElements.minimapSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local miniMapAdjY = stepY - 34
    panelElements.minimapSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, miniMapAdjY + 10)
    panelElements.minimapSection:SetText("小地图调整")
    panelElements.minimapSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.minimapToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.minimapToggleBtn:SetSize(88, 20)
    panelElements.minimapToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, miniMapAdjY + 14)
    panelElements.minimapToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("minimapAdjust")
    end)

    panelElements.btnMMXMinus = MakeAdjustButton(panel, "小图左", 14, miniMapAdjY - 8, 86, nil, "__mmOffsetX", -1)
    panelElements.btnMMXPlus = MakeAdjustButton(panel, "小图右", 110, miniMapAdjY - 8, 86, nil, "__mmOffsetX", 1)
    panelElements.btnMMYMinus = MakeAdjustButton(panel, "小图上", 206, miniMapAdjY - 8, 86, nil, "__mmOffsetY", -1)
    panelElements.btnMMYPlus = MakeAdjustButton(panel, "小图下", 302, miniMapAdjY - 8, 86, nil, "__mmOffsetY", 1)
    panelElements.btnMMScaleMinus = MakeAdjustButton(panel, "小图缩小", 398, miniMapAdjY - 8, 98, nil, "__mmScale", -1)
    panelElements.btnMMScalePlus = MakeAdjustButton(panel, "小图放大", 506, miniMapAdjY - 8, 98, nil, "__mmScale", 1)

    local miniMapScaleAxisY = miniMapAdjY - 34
    panelElements.btnMMScaleXMinus = MakeAdjustButton(panel, GetButtonLabel("__mmScaleX", -1), 14, miniMapScaleAxisY - 8, 136, nil, "__mmScaleX", -1)
    panelElements.btnMMScaleXPlus = MakeAdjustButton(panel, GetButtonLabel("__mmScaleX", 1), 160, miniMapScaleAxisY - 8, 136, nil, "__mmScaleX", 1)
    panelElements.btnMMScaleYMinus = MakeAdjustButton(panel, GetButtonLabel("__mmScaleY", -1), 306, miniMapScaleAxisY - 8, 136, nil, "__mmScaleY", -1)
    panelElements.btnMMScaleYPlus = MakeAdjustButton(panel, GetButtonLabel("__mmScaleY", 1), 452, miniMapScaleAxisY - 8, 136, nil, "__mmScaleY", 1)

    local miniMapLineY = miniMapScaleAxisY - 34
    panelElements.btnMMThin = MakeAdjustButton(panel, "小图线细", 110, miniMapLineY - 8, 116, nil, "__mmLineThickness", -1)
    panelElements.btnMMThick = MakeAdjustButton(panel, "小图线粗", 236, miniMapLineY - 8, 116, nil, "__mmLineThickness", 1)

    panelElements.btnMMReset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnMMReset:SetSize(96, 22)
    panelElements.btnMMReset:SetPoint("TOPLEFT", panel, "TOPLEFT", 362, miniMapLineY - 8)
    panelElements.btnMMReset:SetText("清零")
    panelElements.btnMMReset:SetScript("OnClick", function()
        local pid = YBP:GetSelectedDebugPetID()
        if pid then
            YBP:ResetDebugMinimapTransform(pid)
        end
    end)

    -- 辅助按钮行
    local ctrlY = miniMapLineY - 44

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 154, ctrlY)
    resetBtn:SetText("重置当前")
    resetBtn:SetScript("OnClick", function()
        local petID = YBP:GetSelectedDebugPetID()
        if petID then
            YBP:ResetDebugTransform(petID)
            YBP:ResetDebugMinimapTransform(petID)
            YBP:ResetDebugRouteNode(petID, "start")
        end
    end)
    panelElements.resetBtn = resetBtn

    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(110, 22)
    saveBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 356, ctrlY)
    saveBtn:SetText("保存当前")
    saveBtn:SetScript("OnClick", function()
        local petID = YBP:GetSelectedDebugPetID()
        if petID then
            YBP:EnsureDebugTransform(petID)
            YBP:EnsureDebugRouteNode(petID, "start")
            local savedReference = YBP:SaveCurrentReferenceDisplayTransform(petID)
            if savedReference then
                print(string.format("|cff4fd8ff[YBP调试]|r 已保存宠物 [%d] 的参考层参数，并回退主路线临时变换。", petID))
            else
                print(string.format("|cff4fd8ff[YBP调试]|r 已保存宠物 [%d] 的路线与起点调试参数。", petID))
            end
        end
    end)
    panelElements.saveBtn = saveBtn

    local fusionControlY = ctrlY - 34

    panelElements.fusionSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.fusionSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, fusionControlY + 12)
    panelElements.fusionSection:SetText("融合工作台: 录点 / 重算 / 层显示 / 导出")
    panelElements.fusionSection:SetTextColor(0.25, 0.95, 1.00)

    panelElements.fusionToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.fusionToggleBtn:SetSize(88, 20)
    panelElements.fusionToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, fusionControlY + 16)
    panelElements.fusionToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("fusion")
    end)

    panelElements.btnCaptureFootprint = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnCaptureFootprint:SetSize(110, 22)
    panelElements.btnCaptureFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, fusionControlY - 4)
    panelElements.btnCaptureFootprint:SetText("记录脚印")
    panelElements.btnCaptureFootprint:SetScript("OnClick", function()
        local ok, message = YBP:CaptureCurrentFootprintForSelectedPet()
        if message then
            print(string.format("|cff4fd8ff[YBP调试]|r %s", message))
        end
        if ok then
            YBP:RefreshDebugPanel()
        end
    end)

    panelElements.btnUndoFootprint = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnUndoFootprint:SetSize(110, 22)
    panelElements.btnUndoFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 134, fusionControlY - 4)
    panelElements.btnUndoFootprint:SetText("删最后点")
    panelElements.btnUndoFootprint:SetScript("OnClick", function()
        local petID = YBP:GetSelectedDebugPetID()
        if petID and YBP.RemoveLastFootprintAnchor and YBP:RemoveLastFootprintAnchor(petID) then
            YBP:RefreshDebugPanel()
        end
    end)

    panelElements.btnClearFootprint = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnClearFootprint:SetSize(110, 22)
    panelElements.btnClearFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 254, fusionControlY - 4)
    panelElements.btnClearFootprint:SetText("清空脚印")
    panelElements.btnClearFootprint:SetScript("OnClick", function()
        local petID = YBP:GetSelectedDebugPetID()
        if petID and YBP.ClearFootprintAnchors then
            YBP:ClearFootprintAnchors(petID)
            YBP:RefreshDebugPanel()
        end
    end)

    panelElements.btnResolvePet = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnResolvePet:SetSize(110, 22)
    panelElements.btnResolvePet:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, fusionControlY - 4)
    panelElements.btnResolvePet:SetText("重算当前")
    panelElements.btnResolvePet:SetScript("OnClick", function()
        local petID = YBP:GetSelectedDebugPetID()
        if petID and YBP.ResolveRouteForPet then
            YBP:ResolveRouteForPet(petID)
        end
    end)

    panelElements.btnResolveMap = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnResolveMap:SetSize(110, 22)
    panelElements.btnResolveMap:SetPoint("TOPLEFT", panel, "TOPLEFT", 134, fusionControlY - 4)
    panelElements.btnResolveMap:SetText("重算本图")
    panelElements.btnResolveMap:SetScript("OnClick", function()
        local mapID = YBP:GetCurrentWorldMapID()
        if mapID and YBP.ResolveRoutesForMap then
            YBP:ResolveRoutesForMap(mapID)
        end
    end)

    local fusionToggleY = fusionControlY - 34

    local function MakeToggleButton(key, label, left)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(110, 22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", left, fusionToggleY)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            local settings = YBP.GetRouteDisplaySettings and YBP:GetRouteDisplaySettings() or nil
            if settings and YBP.SetRouteDisplaySetting then
                YBP:SetRouteDisplaySetting(key, not settings[key])
            end
        end)
        return btn
    end

    panelElements.btnToggleResolved = MakeToggleButton("showResolved", "最终层", 14)
    panelElements.btnToggleLegacyOverlay = MakeToggleButton("showLegacyOverlay", "底稿层", 134)
    panelElements.btnToggleReference = MakeToggleButton("showReference", "参考层", 254)
    panelElements.btnToggleFootprints = MakeToggleButton("showFootprints", "脚印层", 374)

    panelElements.btnToggleAutoResolve = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnToggleAutoResolve:SetSize(110, 22)
    panelElements.btnToggleAutoResolve:SetPoint("TOPLEFT", panel, "TOPLEFT", 494, fusionToggleY)
    panelElements.btnToggleAutoResolve:SetText("自动重算")
    panelElements.btnToggleAutoResolve:SetScript("OnClick", function()
        if YBP.SetRouteAutoResolveEnabled then
            YBP:SetRouteAutoResolveEnabled(not YBP:IsRouteAutoResolveEnabled())
        end
    end)

    local fusionPresetY = fusionToggleY - 30

    local function MakeFusionActionButton(text, left, onClick)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(110, 22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", left, fusionPresetY)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    panelElements.btnPresetAll = MakeFusionActionButton("全开", 14, function()
        if YBP.ApplyRouteDisplayPreset then
            YBP:ApplyRouteDisplayPreset("all")
        end
    end)
    panelElements.btnPresetResolved = MakeFusionActionButton("仅最终层", 134, function()
        if YBP.ApplyRouteDisplayPreset then
            YBP:ApplyRouteDisplayPreset("resolvedOnly")
        end
    end)
    panelElements.btnPresetDefault = MakeFusionActionButton("重置显示", 254, function()
        if YBP.ApplyRouteDisplayPreset then
            YBP:ApplyRouteDisplayPreset("default")
        end
        if YBP.ResetRouteVisualSettings then
            YBP:ResetRouteVisualSettings()
        end
    end)

    panelElements.btnExportFusion = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.btnExportFusion:SetSize(110, 22)
    panelElements.btnExportFusion:SetPoint("TOPLEFT", panel, "TOPLEFT", 374, fusionPresetY)
    panelElements.btnExportFusion:SetText("导出融合")
    panelElements.btnExportFusion:SetScript("OnClick", function()
        panelElements.exportBox:SetText(YBP:ExportCurrentRouteFusionSnapshot())
    end)

    panelElements.btnVisualReset = MakeFusionActionButton("重置细节", 494, function()
        if YBP.ResetRouteVisualSettings then
            YBP:ResetRouteVisualSettings()
        end
    end)

    local fusionVisualY = fusionPresetY - 30

    local function NudgeRouteVisual(key, delta, minValue, maxValue, decimals)
        local visualSettings = YBP.GetRouteVisualSettings and YBP:GetRouteVisualSettings() or nil
        local current = visualSettings and visualSettings[key] or nil
        local defaults = ns.routeDisplayMeta and ns.routeDisplayMeta.defaults or {}
        local fallback = defaults[key]
        local nextValue = (current or fallback or 0) + delta
        if minValue and nextValue < minValue then
            nextValue = minValue
        end
        if maxValue and nextValue > maxValue then
            nextValue = maxValue
        end
        if decimals and decimals > 0 then
            local scale = 10 ^ decimals
            nextValue = math.floor((nextValue * scale) + 0.5) / scale
        end
        if YBP.SetRouteVisualSetting then
            YBP:SetRouteVisualSetting(key, nextValue)
        end
    end

    panelElements.btnResolvedThin = MakeFusionActionButton("主线细", 14, function()
        NudgeRouteVisual("resolvedThickness", -0.5, 1.0, 8.0, 1)
    end)
    panelElements.btnResolvedThick = MakeFusionActionButton("主线粗", 134, function()
        NudgeRouteVisual("resolvedThickness", 0.5, 1.0, 8.0, 1)
    end)
    panelElements.btnFootSmall = MakeFusionActionButton("脚印小", 254, function()
        NudgeRouteVisual("footprintSize", -1, 4, 24, 0)
    end)
    panelElements.btnFootBig = MakeFusionActionButton("脚印大", 374, function()
        NudgeRouteVisual("footprintSize", 1, 4, 24, 0)
    end)
    panelElements.btnFootFaint = MakeFusionActionButton("脚印淡", 494, function()
        NudgeRouteVisual("footprintAlpha", -0.05, 0.15, 1.0, 2)
    end)

    local fusionVisualY2 = fusionVisualY - 30
    for _, button in ipairs({
        panelElements.btnResolvedThin,
        panelElements.btnResolvedThick,
        panelElements.btnFootSmall,
        panelElements.btnFootBig,
        panelElements.btnFootFaint,
    }) do
        local point, relativeTo, relativePoint, x = button:GetPoint(1)
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, fusionVisualY)
    end

    panelElements.btnFootBold = MakeFusionActionButton("脚印亮", 14, function()
        NudgeRouteVisual("footprintAlpha", 0.05, 0.15, 1.0, 2)
    end)
    panelElements.btnRefThin = MakeFusionActionButton("参考细", 134, function()
        NudgeRouteVisual("referenceThickness", -0.5, 1.0, 8.0, 1)
    end)
    panelElements.btnRefThick = MakeFusionActionButton("参考粗", 254, function()
        NudgeRouteVisual("referenceThickness", 0.5, 1.0, 8.0, 1)
    end)
    panelElements.btnRouteDensityLess = MakeFusionActionButton("点位疏", 374, function()
        NudgeRouteVisual("routeDensity", -1, 1, 8, 0)
    end)
    panelElements.btnRouteDensityMore = MakeFusionActionButton("点位密", 494, function()
        NudgeRouteVisual("routeDensity", 1, 1, 8, 0)
    end)
    for _, button in ipairs({
        panelElements.btnFootBold,
        panelElements.btnRefThin,
        panelElements.btnRefThick,
        panelElements.btnRouteDensityLess,
        panelElements.btnRouteDensityMore,
    }) do
        local point, relativeTo, relativePoint, x = button:GetPoint(1)
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, fusionVisualY2)
    end

    local fusionVisualY3 = fusionVisualY2 - 30
    panelElements.btnMiniPointsLess = MakeFusionActionButton("小图点少", 14, function()
        NudgeRouteVisual("minimapNearbyPointLimit", -1, 0, 20, 0)
    end)
    panelElements.btnMiniPointsMore = MakeFusionActionButton("小图点多", 134, function()
        NudgeRouteVisual("minimapNearbyPointLimit", 1, 0, 20, 0)
    end)
    for _, button in ipairs({
        panelElements.btnMiniPointsLess,
        panelElements.btnMiniPointsMore,
    }) do
        local point, relativeTo, relativePoint, x = button:GetPoint(1)
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, fusionVisualY3)
    end

    panelElements.fusionDetailText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.fusionDetailText:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, fusionVisualY3 - 28)
    panelElements.fusionDetailText:SetWidth(588)
    panelElements.fusionDetailText:SetJustifyH("LEFT")
    panelElements.fusionDetailText:SetText("显示细节: —")

    local divider3 = panel:CreateTexture(nil, "OVERLAY")
    divider3:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider3:SetVertexColor(0.4, 0.55, 0.9, 0.3)
    divider3:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, fusionVisualY3 - 46)
    divider3:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, fusionVisualY3 - 46)
    divider3:SetHeight(1)

    -- === 区块 4：脚印列表区 ===
    local footprintListY = fusionVisualY3 - 78

    panelElements.footprintListSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.footprintListSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, footprintListY + 16)
    panelElements.footprintListSection:SetText("脚印列表")
    panelElements.footprintListSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.footprintListToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.footprintListToggleBtn:SetSize(88, 20)
    panelElements.footprintListToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, footprintListY + 20)
    panelElements.footprintListToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("footprintList")
    end)

    panelElements.btnCaptureFootprint:ClearAllPoints()
    panelElements.btnCaptureFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, footprintListY - 4)

    panelElements.btnUndoFootprint:ClearAllPoints()
    panelElements.btnUndoFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 134, footprintListY - 4)

    panelElements.btnClearFootprint:ClearAllPoints()
    panelElements.btnClearFootprint:SetPoint("TOPLEFT", panel, "TOPLEFT", 254, footprintListY - 4)

    panelElements.btnFootArcLess = MakeFusionActionButton("影响短", 374, function()
        NudgeRouteVisual("footprintInfluenceArc", -0.1, 0.5, 2.5, 1)
    end)
    panelElements.btnFootArcMore = MakeFusionActionButton("影响长", 494, function()
        NudgeRouteVisual("footprintInfluenceArc", 0.1, 0.5, 2.5, 1)
    end)
    for _, button in ipairs({
        panelElements.btnFootArcLess,
        panelElements.btnFootArcMore,
    }) do
        local point, relativeTo, relativePoint, x = button:GetPoint(1)
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, footprintListY - 4)
    end

    panelElements.footprintInfluenceText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.footprintInfluenceText:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, footprintListY - 32)
    panelElements.footprintInfluenceText:SetWidth(588)
    panelElements.footprintInfluenceText:SetJustifyH("LEFT")
    panelElements.footprintInfluenceText:SetText("脚印影响弧长: —")

    local footprintFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    footprintFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, footprintListY - 58)
    footprintFrame:SetSize(592, 160)
    footprintFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    footprintFrame:SetBackdropColor(0.02, 0.02, 0.08, 0.90)
    footprintFrame:SetBackdropBorderColor(0.40, 0.55, 0.90, 0.55)
    panelElements.footprintListFrame = footprintFrame

    panelElements.footprintListHint = footprintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.footprintListHint:SetPoint("TOPLEFT", footprintFrame, "TOPLEFT", 10, -10)
    panelElements.footprintListHint:SetWidth(560)
    panelElements.footprintListHint:SetJustifyH("LEFT")
    panelElements.footprintListHint:SetText("暂无脚印点")

    panelElements.footprintRows = {}
    for index = 1, FOOTPRINT_LIST_PAGE_SIZE do
        local rowY = -12 - (index * 22)
        local label = footprintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", footprintFrame, "TOPLEFT", 10, rowY)
        label:SetWidth(390)
        label:SetJustifyH("LEFT")
        label:SetText("")

        local toggleBtn = CreateFrame("Button", nil, footprintFrame, "UIPanelButtonTemplate")
        toggleBtn:SetSize(78, 20)
        toggleBtn:SetPoint("TOPLEFT", footprintFrame, "TOPLEFT", 410, rowY + 4)

        local deleteBtn = CreateFrame("Button", nil, footprintFrame, "UIPanelButtonTemplate")
        deleteBtn:SetSize(78, 20)
        deleteBtn:SetPoint("TOPLEFT", footprintFrame, "TOPLEFT", 494, rowY + 4)
        deleteBtn:SetText("删除")

        panelElements.footprintRows[index] = {
            label = label,
            toggleBtn = toggleBtn,
            deleteBtn = deleteBtn,
        }
    end

    panelElements.footprintPrevBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.footprintPrevBtn:SetSize(110, 22)
    panelElements.footprintPrevBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 122, footprintListY - 228)
    panelElements.footprintPrevBtn:SetText("上一页")
    panelElements.footprintPrevBtn:SetScript("OnClick", function()
        local ui = GetDebugUIState()
        YBP:SetFootprintListOffset((ui and ui.footprintListOffset or 0) - FOOTPRINT_LIST_PAGE_SIZE)
    end)

    panelElements.footprintNextBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.footprintNextBtn:SetSize(110, 22)
    panelElements.footprintNextBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 248, footprintListY - 228)
    panelElements.footprintNextBtn:SetText("下一页")
    panelElements.footprintNextBtn:SetScript("OnClick", function()
        local ui = GetDebugUIState()
        YBP:SetFootprintListOffset((ui and ui.footprintListOffset or 0) + FOOTPRINT_LIST_PAGE_SIZE)
    end)

    panelElements.footprintPageText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelElements.footprintPageText:SetPoint("TOPLEFT", panel, "TOPLEFT", 376, footprintListY - 224)
    panelElements.footprintPageText:SetWidth(220)
    panelElements.footprintPageText:SetJustifyH("LEFT")
    panelElements.footprintPageText:SetText("脚印页: 0/0")

    local divider4 = panel:CreateTexture(nil, "OVERLAY")
    divider4:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider4:SetVertexColor(0.4, 0.55, 0.9, 0.3)
    divider4:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, footprintListY - 256)
    divider4:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, footprintListY - 256)
    divider4:SetHeight(1)

    -- === 区块 5：参数导出区 ===
    local exportY = footprintListY - 296

    panelElements.exportSection = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelElements.exportSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, exportY + 16)
    panelElements.exportSection:SetText("参数导出")
    panelElements.exportSection:SetTextColor(0.95, 0.82, 0.28)

    panelElements.exportToggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panelElements.exportToggleBtn:SetSize(88, 20)
    panelElements.exportToggleBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, exportY + 20)
    panelElements.exportToggleBtn:SetScript("OnClick", function()
        YBP:ToggleDebugSection("export")
    end)

    -- 导出文本框
    local exportFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    exportFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, exportY - 10)
    exportFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 82)
    exportFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    exportFrame:SetBackdropColor(0.02, 0.02, 0.08, 0.90)
    exportFrame:SetBackdropBorderColor(0.30, 0.40, 0.70, 0.70)
    panelElements.exportFrame = exportFrame

    local exportControlsFrame = CreateFrame("Frame", nil, exportFrame)
    exportControlsFrame:SetPoint("BOTTOMLEFT", exportFrame, "BOTTOMLEFT", 8, 8)
    exportControlsFrame:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -8, 8)
    exportControlsFrame:SetHeight(52)
    panelElements.exportControlsFrame = exportControlsFrame

    local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
    exportScroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 4, -4)
    exportScroll:SetPoint("BOTTOMRIGHT", exportControlsFrame, "TOPRIGHT", -20, 8)
    panelElements.exportScroll = exportScroll

    local editBox = CreateFrame("EditBox", nil, exportScroll)
    editBox:SetWidth(432)
    editBox:SetHeight(700)
    editBox:SetMultiLine(true)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetTextInsets(4, 4, 2, 2)
    editBox:SetPoint("TOPLEFT", exportScroll, "TOPLEFT", 0, 0)
    editBox:SetScript("OnTextChanged", function(self)
        self:GetParent():UpdateScrollChildRect()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    exportScroll:SetScrollChild(editBox)
    panelElements.exportBox = editBox

    local exportCurBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    exportCurBtn:SetSize(96, 22)
    exportCurBtn:SetPoint("TOPLEFT", exportControlsFrame, "TOPLEFT", 16, 0)
    exportCurBtn:SetText("参数当前")
    exportCurBtn:SetScript("OnClick", function()
        YBP:SetDebugExportView("current")
        panelElements.exportBox:SetText(YBP:GetDebugExportText("current"))
    end)
    panelElements.exportCurBtn = exportCurBtn

    local exportFootBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    exportFootBtn:SetSize(96, 22)
    exportFootBtn:SetPoint("TOPLEFT", exportControlsFrame, "TOPLEFT", 126, 0)
    exportFootBtn:SetText("脚印片段")
    exportFootBtn:SetScript("OnClick", function()
        YBP:SetDebugExportView("footprints")
        panelElements.exportBox:SetText(YBP:GetDebugExportText("footprints"))
    end)
    panelElements.exportFootBtn = exportFootBtn

    local exportResolvedBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    exportResolvedBtn:SetSize(96, 22)
    exportResolvedBtn:SetPoint("TOPLEFT", exportControlsFrame, "TOPLEFT", 236, 0)
    exportResolvedBtn:SetText("融合片段")
    exportResolvedBtn:SetScript("OnClick", function()
        YBP:SetDebugExportView("resolved")
        panelElements.exportBox:SetText(YBP:GetDebugExportText("resolved"))
    end)
    panelElements.exportResolvedBtn = exportResolvedBtn

    local exportMapBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    exportMapBtn:SetSize(96, 22)
    exportMapBtn:SetPoint("TOPLEFT", exportControlsFrame, "TOPLEFT", 346, 0)
    exportMapBtn:SetText("参数本图")
    exportMapBtn:SetScript("OnClick", function()
        YBP:SetDebugExportView("map")
        panelElements.exportBox:SetText(YBP:GetDebugExportText("map"))
    end)
    panelElements.exportMapBtn = exportMapBtn

    local exportMapFusionBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    exportMapFusionBtn:SetSize(96, 22)
    exportMapFusionBtn:SetPoint("TOPLEFT", exportControlsFrame, "TOPLEFT", 456, 0)
    exportMapFusionBtn:SetText("本图改动")
    exportMapFusionBtn:SetScript("OnClick", function()
        YBP:SetDebugExportView("mapFusion")
        panelElements.exportBox:SetText(YBP:GetDebugExportText("mapFusion"))
    end)
    panelElements.exportMapFusionBtn = exportMapFusionBtn

    local selectAllBtn = CreateFrame("Button", nil, exportControlsFrame, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(96, 22)
    selectAllBtn:SetPoint("TOP", exportControlsFrame, "TOP", 0, -26)
    selectAllBtn:SetText("全选")
    selectAllBtn:SetScript("OnClick", function()
        panelElements.exportBox:HighlightText()
    end)
    panelElements.selectAllBtn = selectAllBtn

    panelElements.divider2 = divider2
    panelElements.divider3 = divider3
    panelElements.divider4 = divider4

    panelElements.sectionContents = {
        routeNav = {
            panelElements.routeSection, panelElements.divider2,
            panelElements.prevBtn,
            panelElements.nextBtn,
        },
        mapAdjust = {
            panelElements.routeAdjustSection,
            panelElements.btnXMinus, panelElements.btnXPlus, panelElements.btnYMinus, panelElements.btnYPlus, panelElements.btnSMinus, panelElements.btnSPlus,
            panelElements.btnTMinus, panelElements.btnTPlus, panelElements.btnOMinus, panelElements.btnOPlus,
            panelElements.btnSXMinus, panelElements.btnSXPlus, panelElements.btnSYMinus, panelElements.btnSYPlus,
        },
        nodeAdjust = {
            panelElements.nodeSection,
            panelElements.btnNXMinus, panelElements.btnNXPlus, panelElements.btnNYMinus, panelElements.btnNYPlus, panelElements.btnNSMinus, panelElements.btnNSPlus,
            panelElements.stepLabel, panelElements.btnStepFine, panelElements.btnStepMed, panelElements.btnStepCoarse,
        },
        minimapAdjust = {
            panelElements.minimapSection,
            panelElements.btnMMXMinus, panelElements.btnMMXPlus, panelElements.btnMMYMinus, panelElements.btnMMYPlus,
            panelElements.btnMMScaleMinus, panelElements.btnMMScalePlus, panelElements.btnMMScaleXMinus, panelElements.btnMMScaleXPlus,
            panelElements.btnMMScaleYMinus, panelElements.btnMMScaleYPlus, panelElements.btnMMThin, panelElements.btnMMThick,
            panelElements.btnMMReset, panelElements.resetBtn, panelElements.saveBtn,
        },
        fusion = {
            panelElements.fusionSection, panelElements.divider3,
            panelElements.btnResolvePet, panelElements.btnResolveMap, panelElements.btnToggleResolved,
            panelElements.btnToggleLegacyOverlay, panelElements.btnToggleReference, panelElements.btnToggleFootprints, panelElements.btnToggleAutoResolve,
            panelElements.btnPresetAll, panelElements.btnPresetResolved, panelElements.btnPresetDefault,
            panelElements.btnExportFusion, panelElements.btnVisualReset,
            panelElements.btnResolvedThin, panelElements.btnResolvedThick, panelElements.btnFootSmall,
            panelElements.btnFootBig, panelElements.btnFootFaint, panelElements.btnFootBold,
            panelElements.btnRefThin, panelElements.btnRefThick, panelElements.btnRouteDensityLess,
            panelElements.btnRouteDensityMore, panelElements.btnMiniPointsLess,
            panelElements.btnMiniPointsMore, panelElements.fusionDetailText,
        },
        footprintList = {
            panelElements.footprintListSection, panelElements.divider4,
            panelElements.btnCaptureFootprint, panelElements.btnUndoFootprint, panelElements.btnClearFootprint,
            panelElements.btnFootArcLess, panelElements.btnFootArcMore, panelElements.footprintInfluenceText,
            panelElements.footprintListFrame, panelElements.footprintPrevBtn, panelElements.footprintNextBtn, panelElements.footprintPageText,
        },
        export = {
            panelElements.exportSection,
            panelElements.exportFrame, panelElements.exportControlsFrame, panelElements.exportScroll,
            panelElements.exportCurBtn, panelElements.exportFootBtn, panelElements.exportResolvedBtn,
            panelElements.exportMapBtn, panelElements.exportMapFusionBtn, panelElements.selectAllBtn,
        },
    }

    panelElements.sectionLayout = {
        basePanelHeight = 1160,
        minPanelHeight = 360,
        order = { "routeNav", "mapAdjust", "nodeAdjust", "minimapAdjust", "fusion", "footprintList", "export" },
        routeNav = {
            collapseHeight = 14,
            movableElements = {
                panelElements.routeSection, panelElements.prevBtn, panelElements.nextBtn, panelElements.divider2,
            },
        },
        mapAdjust = {
            collapseHeight = 84,
            movableElements = {
                panelElements.routeAdjustSection,
                panelElements.btnXMinus, panelElements.btnXPlus, panelElements.btnYMinus, panelElements.btnYPlus, panelElements.btnSMinus, panelElements.btnSPlus,
                panelElements.btnTMinus, panelElements.btnTPlus, panelElements.btnOMinus, panelElements.btnOPlus,
                panelElements.btnSXMinus, panelElements.btnSXPlus, panelElements.btnSYMinus, panelElements.btnSYPlus,
            },
        },
        nodeAdjust = {
            collapseHeight = 46,
            movableElements = {
                panelElements.nodeSection,
                panelElements.btnNXMinus, panelElements.btnNXPlus, panelElements.btnNYMinus, panelElements.btnNYPlus, panelElements.btnNSMinus, panelElements.btnNSPlus,
                panelElements.stepLabel, panelElements.btnStepFine, panelElements.btnStepMed, panelElements.btnStepCoarse,
            },
        },
        minimapAdjust = {
            collapseHeight = 120,
            movableElements = {
                panelElements.minimapSection,
                panelElements.btnMMXMinus, panelElements.btnMMXPlus, panelElements.btnMMYMinus, panelElements.btnMMYPlus,
                panelElements.btnMMScaleMinus, panelElements.btnMMScalePlus, panelElements.btnMMScaleXMinus, panelElements.btnMMScaleXPlus,
                panelElements.btnMMScaleYMinus, panelElements.btnMMScaleYPlus, panelElements.btnMMThin, panelElements.btnMMThick,
                panelElements.btnMMReset, panelElements.resetBtn, panelElements.saveBtn,
            },
        },
        fusion = {
            collapseHeight = 146,
            movableElements = {
                panelElements.fusionSection,
                panelElements.btnResolvePet, panelElements.btnResolveMap,
                panelElements.btnToggleResolved, panelElements.btnToggleLegacyOverlay, panelElements.btnToggleReference, panelElements.btnToggleFootprints,
                panelElements.btnToggleAutoResolve, panelElements.btnPresetAll, panelElements.btnPresetResolved,
                panelElements.btnPresetDefault, panelElements.btnExportFusion, panelElements.btnVisualReset,
                panelElements.btnResolvedThin, panelElements.btnResolvedThick, panelElements.btnFootSmall,
                panelElements.btnFootBig, panelElements.btnFootFaint, panelElements.btnFootBold,
                panelElements.btnRefThin, panelElements.btnRefThick, panelElements.btnRouteDensityLess,
                panelElements.btnRouteDensityMore, panelElements.btnMiniPointsLess,
                panelElements.btnMiniPointsMore, panelElements.fusionDetailText, panelElements.divider3,
            },
        },
        footprintList = {
            collapseHeight = 272,
            movableElements = {
                panelElements.footprintListSection, panelElements.footprintListFrame,
                panelElements.btnCaptureFootprint, panelElements.btnUndoFootprint, panelElements.btnClearFootprint,
                panelElements.btnFootArcLess, panelElements.btnFootArcMore, panelElements.footprintInfluenceText,
                panelElements.footprintPrevBtn, panelElements.footprintNextBtn, panelElements.footprintPageText, panelElements.divider4,
            },
        },
        export = {
            collapseHeight = 280,
            movableElements = {
                panelElements.exportSection, panelElements.exportFrame,
            },
        },
    }

    for _, section in ipairs(panelElements.sectionLayout.order) do
        local meta = panelElements.sectionLayout[section]
        for _, element in ipairs(meta.movableElements or {}) do
            CaptureAnchorPoints(element)
        end
    end

    for _, toggleButton in ipairs({
        panelElements.routeToggleBtn,
        panelElements.mapAdjustToggleBtn,
        panelElements.nodeToggleBtn,
        panelElements.minimapToggleBtn,
        panelElements.fusionToggleBtn,
        panelElements.footprintListToggleBtn,
        panelElements.exportToggleBtn,
    }) do
        if toggleButton then
            toggleButton:Hide()
        end
    end

    panelElements.autoHeightElements = {
        panelElements.petIconBg,
        panelElements.petFootprint,
        panelElements.mapText,
        panelElements.petText,
        panelElements.paramText,
        panelElements.thicknessText,
        panelElements.opacityText,
        panelElements.advParamText,
        panelElements.nodeText,
        panelElements.minimapText,
        panelElements.fusionText,
        panelElements.divider1,
        panelElements.routeSection,
        panelElements.prevBtn,
        panelElements.nextBtn,
        panelElements.divider2,
        panelElements.tabsSection,
        panelElements.dividerTabs,
        panelElements.routeAdjustSection,
        panelElements.nodeSection,
        panelElements.minimapSection,
        panelElements.fusionSection,
        panelElements.divider3,
        panelElements.footprintListSection,
        panelElements.btnCaptureFootprint,
        panelElements.btnUndoFootprint,
        panelElements.btnClearFootprint,
        panelElements.btnFootArcLess,
        panelElements.btnFootArcMore,
        panelElements.footprintInfluenceText,
        panelElements.footprintListFrame,
        panelElements.footprintPrevBtn,
        panelElements.footprintNextBtn,
        panelElements.footprintPageText,
        panelElements.divider4,
        panelElements.exportSection,
        panelElements.exportFrame,
    }

    for _, button in pairs(panelElements.tabButtons or {}) do
        panelElements.autoHeightElements[#panelElements.autoHeightElements + 1] = button
    end

    return panel
end

function YBP:ShowDebugPanel()
    local p = GetOrCreatePanel()
    if p then
        p:Show()
        self:RefreshDebugPanel()
    end
end

function YBP:HideDebugPanel()
    if panel then
        panel:Hide()
    end
end

function YBP:RefreshDebugPanel()
    if not panel or not panel:IsShown() then
        return
    end

    local db = _G.YiboBeastPathsDebugDB
    if not db then
        return
    end

    local ui = GetDebugUIState()
    local petIDs = self:GetDebugPetIDsForCurrentMap()
    local selectedPetID = self:GetSelectedDebugPetID()
    local displaySettings = self.GetRouteDisplaySettings and self:GetRouteDisplaySettings() or {}

    ApplySectionVisibility()

    if panelElements.btnToggleResolved then
        panelElements.btnToggleResolved:SetText((displaySettings.showResolved and "[开] " or "[关] ") .. "最终层")
    end
    if panelElements.btnToggleReference then
        panelElements.btnToggleReference:SetText((displaySettings.showReference and "[开] " or "[关] ") .. "参考层")
    end
    if panelElements.btnToggleFootprints then
        panelElements.btnToggleFootprints:SetText((displaySettings.showFootprints and "[开] " or "[关] ") .. "脚印层")
    end
    if panelElements.btnToggleLegacyOverlay then
        panelElements.btnToggleLegacyOverlay:SetText((displaySettings.showLegacyOverlay and "[开] " or "[关] ") .. "底稿层")
    end
    if panelElements.btnToggleAutoResolve and self.IsRouteAutoResolveEnabled then
        panelElements.btnToggleAutoResolve:SetText((self:IsRouteAutoResolveEnabled() and "[开] " or "[关] ") .. "自动重算")
    end

    -- 更新宠物信息
    if selectedPetID then
        local petInfo = ns.pets and ns.pets[selectedPetID]
        local visual = GetPetDebugVisual(selectedPetID)
        local footprintPoints = self.GetFootprintsForPet and self:GetFootprintsForPet(selectedPetID, false) or {}
        local footprintStore = self.GetFootprintStore and self:GetFootprintStore(selectedPetID) or nil
        local totalFootprints = footprintStore and footprintStore.points and #footprintStore.points or 0
        local resolvedRoute = self.GetResolvedRoute and self:GetResolvedRoute(selectedPetID) or nil
        local petName = petInfo and (petInfo.name or petInfo.nameEN) or "未知"
        panelElements.petIcon:SetTexture(visual.iconTexture)
        panelElements.petFootprint:SetTexture(visual.footTexture)
        local mapInfo = self.GetCurrentWorldMapID and self:GetCurrentWorldMapID() or nil
        local mapLabel = petInfo and petInfo.zone or "未知地图"
        if mapInfo then
            mapLabel = string.format("地图: %s [%d]", mapLabel, mapInfo)
        else
            mapLabel = string.format("地图: %s", mapLabel)
        end
        panelElements.mapText:SetText(mapLabel)
        panelElements.petText:SetText(string.format("宠物: %s [%d] (%d/%d)",
            petName, selectedPetID,
            self:GetPetIndexInCurrentMap(selectedPetID),
            #petIDs))
        panelElements.petText:SetText(string.format(
            "宠物: %s [%d] (%d/%d)  脚印: %d/%d  融合段: %d",
            petName,
            selectedPetID,
            self:GetPetIndexInCurrentMap(selectedPetID),
            #petIDs,
            #footprintPoints,
            totalFootprints,
            resolvedRoute and #(resolvedRoute.segments or {}) or 0
        ))

        -- 参数摘要
        local transform = self:GetResolvedTransform(selectedPetID)
        if transform then
            -- 步进标签更新
            local stepLabel = "?"
            for _, key in ipairs(stepOrder) do
                local preset = stepPresets[key]
                if preset and preset.move == db.ui.stepMove then
                    stepLabel = preset.label
                    break
                end
            end
            panelElements.paramText:SetText(string.format(
                "位置: X %s  Y %s  缩放 %s  [%s]",
                FormatFloat(transform.offsetX),
                FormatFloat(transform.offsetY),
                FormatFloat(transform.scale),
                stepLabel
            ))

            panelElements.thicknessText:SetText(string.format(
                "线宽: %.2f",
                self:GetDebugRouteThickness()
            ))
            panelElements.opacityText:SetText(string.format(
                "透明: %.2f",
                transform.opacity or 1.0
            ))

            -- 高级参数
            panelElements.advParamText:SetText(string.format(
                "横向缩放: %s  纵向缩放: %s",
                FormatFloat(transform.scaleX),
                FormatFloat(transform.scaleY)
            ))

            local nodeX, nodeY, nodeScale = "—", "—", "—"
            local nodes = self.GetResolvedRouteNodes and self:GetResolvedRouteNodes(selectedPetID) or nil
            if nodes and nodes[1] then
                nodeX = FormatFloat(nodes[1].normalizedX or 0.5)
                nodeY = FormatFloat(nodes[1].normalizedY or 0.5)
                nodeScale = FormatFloat(nodes[1].nodeScale or 1.0)
            end
            panelElements.nodeText:SetText(string.format(
                "节点: X %s  Y %s  大小 %s",
                nodeX,
                nodeY,
                nodeScale
            ))

            local minimapTransform = self:GetDebugMinimapTransform(selectedPetID)
                or (ns.minimapTransforms and ns.minimapTransforms[selectedPetID])
            panelElements.minimapText:SetText(string.format(
                "小图偏移: X %s  Y %s  缩放 %s  横缩 %s  竖缩 %s  线宽 %s",
                FormatFloat(minimapTransform and minimapTransform.offsetX or 0),
                FormatFloat(minimapTransform and minimapTransform.offsetY or 0),
                FormatFloat(minimapTransform and minimapTransform.scale or 1),
                FormatFloat(minimapTransform and minimapTransform.scaleX or 1),
                FormatFloat(minimapTransform and minimapTransform.scaleY or 1),
                FormatFloat(minimapTransform and minimapTransform.lineThickness or 1)
            ))

            panelElements.fusionText:SetText(string.format(
                "融合: 自动重算 %s  显示[最终:%s 参考:%s 脚印:%s 底稿:%s]  状态: %s",
                self.IsRouteAutoResolveEnabled and self:IsRouteAutoResolveEnabled() and "开" or "关",
                displaySettings.showResolved and "开" or "关",
                displaySettings.showReference and "开" or "关",
                displaySettings.showFootprints and "开" or "关",
                displaySettings.showLegacyOverlay and "开" or "关",
                resolvedRoute and (resolvedRoute.resolvedAt or "已生成") or "未生成"
            ))

            local visualSettings = self.GetRouteVisualSettings and self:GetRouteVisualSettings() or {}
            local sectionSummary = self.GetResolvedSectionStateSummary and self:GetResolvedSectionStateSummary(selectedPetID) or {}
            if panelElements.fusionDetailText then
                panelElements.fusionDetailText:SetText(string.format(
                    "显示细节: 主线宽 %s  参考宽 %s  点位密度 %s  脚印大小 %s  脚印透明 %s  脚印弧长 %s  小图近点 %s  区段[参考:%d 过渡:%d 实测:%d]",
                    FormatFloat((visualSettings.resolvedThickness or (ns.routeDisplayMeta and ns.routeDisplayMeta.defaults and ns.routeDisplayMeta.defaults.resolvedThickness) or 3)),
                    FormatFloat((visualSettings.referenceThickness or (ns.routeDisplayMeta and ns.routeDisplayMeta.defaults and ns.routeDisplayMeta.defaults.referenceThickness) or 2)),
                    tostring(self.GetRouteDisplayDensity and self:GetRouteDisplayDensity() or 2),
                    tostring(math.floor((visualSettings.footprintSize or (ns.routeDisplayMeta and ns.routeDisplayMeta.defaults and ns.routeDisplayMeta.defaults.footprintSize) or 12) + 0.5)),
                    FormatFloat((visualSettings.footprintAlpha or (ns.routeDisplayMeta and ns.routeDisplayMeta.defaults and ns.routeDisplayMeta.defaults.footprintAlpha) or 0.95)),
                    FormatFloat((self.GetFootprintInfluenceArc and self:GetFootprintInfluenceArc() or 1.0)),
                    tostring(self.GetMinimapNearbyPointLimit and self:GetMinimapNearbyPointLimit() or 6),
                    sectionSummary.reference or 0,
                    sectionSummary.mixed or 0,
                    sectionSummary.footprintLed or 0
                ))
            end

            if panelElements.footprintInfluenceText then
                panelElements.footprintInfluenceText:SetText(string.format(
                    "脚印影响弧长: %s 倍",
                    FormatFloat((self.GetFootprintInfluenceArc and self:GetFootprintInfluenceArc() or 1.0))
                ))
            end

        end

        local listPoints = footprintStore and footprintStore.points or {}
        local maxOffset = math.max(0, #listPoints - FOOTPRINT_LIST_PAGE_SIZE)
        local listOffset = math.min(ui and ui.footprintListOffset or 0, maxOffset)
        if ui then
            ui.footprintListOffset = listOffset
        end

        if panelElements.footprintListHint then
            if #listPoints == 0 then
                panelElements.footprintListHint:SetText("暂无脚印点，使用“记录脚印”开始采集。")
            else
                panelElements.footprintListHint:SetText(string.format("共 %d 个脚印点，可逐条禁用或删除。", #listPoints))
            end
        end

        local currentPage = (#listPoints == 0) and 0 or (math.floor(listOffset / FOOTPRINT_LIST_PAGE_SIZE) + 1)
        local totalPages = (#listPoints == 0) and 0 or math.ceil(#listPoints / FOOTPRINT_LIST_PAGE_SIZE)
        if panelElements.footprintPageText then
            panelElements.footprintPageText:SetText(string.format("脚印页: %d/%d", currentPage, totalPages))
        end
        if panelElements.footprintPrevBtn then
            panelElements.footprintPrevBtn:SetEnabled(listOffset > 0)
        end
        if panelElements.footprintNextBtn then
            panelElements.footprintNextBtn:SetEnabled(listOffset < maxOffset)
        end

        for rowIndex = 1, FOOTPRINT_LIST_PAGE_SIZE do
            local row = panelElements.footprintRows and panelElements.footprintRows[rowIndex] or nil
            local pointIndex = listOffset + rowIndex
            local point = listPoints[pointIndex]
            if row and point then
                row.label:SetText(string.format(
                    "#%d [%s] X %s  Y %s%s",
                    pointIndex,
                    point.enabled == false and "关" or "开",
                    FormatFloat(point.x or 0),
                    FormatFloat(point.y or 0),
                    point.note and point.note ~= "" and ("  " .. point.note) or ""
                ))
                row.toggleBtn:SetText(point.enabled == false and "启用" or "禁用")
                row.toggleBtn:SetScript("OnClick", function()
                    YBP:SetFootprintAnchorEnabled(selectedPetID, pointIndex, point.enabled == false)
                end)
                row.deleteBtn:SetScript("OnClick", function()
                    YBP:RemoveFootprintAnchor(selectedPetID, pointIndex)
                end)
                row.label:Show()
                row.toggleBtn:Show()
                row.deleteBtn:Show()
            elseif row then
                row.label:SetText("")
                row.label:Hide()
                row.toggleBtn:Hide()
                row.deleteBtn:Hide()
            end
        end
    else
        panelElements.petIcon:SetTexture("Interface\\Icons\\Ability_Tracking")
        panelElements.petFootprint:SetTexture("Interface\\Icons\\Ability_Tracking")
        panelElements.mapText:SetText("地图: -")
        panelElements.petText:SetText("宠物: (无)")
        panelElements.paramText:SetText("位置: X —  Y —  缩放 —")
        panelElements.thicknessText:SetText("线宽: —")
        panelElements.opacityText:SetText("透明: —")
        panelElements.advParamText:SetText("横向缩放: —  纵向缩放: —")
        panelElements.nodeText:SetText("节点: X —  Y —  大小 —")
        panelElements.minimapText:SetText("小图偏移: X —  Y —  缩放 —  横缩 —  竖缩 —  线宽 —")
        panelElements.fusionText:SetText("融合: 脚印 —  自动重算 —  显示层 —")
        if panelElements.fusionDetailText then
            panelElements.fusionDetailText:SetText("显示细节: —")
        end
        if panelElements.footprintListHint then
            panelElements.footprintListHint:SetText("暂无可显示的脚印列表")
        end
        if panelElements.footprintInfluenceText then
            panelElements.footprintInfluenceText:SetText("脚印影响弧长: —")
        end
        if panelElements.footprintPageText then
            panelElements.footprintPageText:SetText("脚印页: 0/0")
        end
        if panelElements.footprintPrevBtn then
            panelElements.footprintPrevBtn:SetEnabled(false)
        end
        if panelElements.footprintNextBtn then
            panelElements.footprintNextBtn:SetEnabled(false)
        end
        for rowIndex = 1, FOOTPRINT_LIST_PAGE_SIZE do
            local row = panelElements.footprintRows and panelElements.footprintRows[rowIndex] or nil
            if row then
                row.label:SetText("")
                row.label:Hide()
                row.toggleBtn:Hide()
                row.deleteBtn:Hide()
            end
        end
    end

    if panelElements.exportBox then
        local exportText = self:GetDebugExportText(self:GetDebugExportView())
        panelElements.exportBox:SetText(exportText or "")
    end
end

--- 辅助：获取当前地图中某宠物的序号
function YBP:GetPetIndexInCurrentMap(petID)
    local petIDs = self:GetDebugPetIDsForCurrentMap()
    for i, id in ipairs(petIDs) do
        if id == petID then
            return i
        end
    end
    return 0
end

----------------------------------------------------------------
-- 命令处理
----------------------------------------------------------------

SLASH_YBPDEBUG1 = "/ybpdebug"
SlashCmdList.YBPDEBUG = function(msg)
    YBP:SetDebugEnabled(true)
    print("|cff4fd8ff[YBP调试]|r 调试面板已显示。")
end

----------------------------------------------------------------
-- 集成：ADDON_LOADED 事件初始化调试模块
----------------------------------------------------------------

-- 在 Core.lua 的 ADDON_LOADED 之后初始化调试 DB
-- 使用 ADDON_LOADED 事件确保在正式配置之后加载
local debugInitFrame = CreateFrame("Frame")
debugInitFrame:RegisterEvent("ADDON_LOADED")
debugInitFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        YBP:InitDebugDB()
    end
end)

-- 世界地图事件：地图切换时刷新面板
-- 延迟到 Blizzard_WorldMap 加载后 Hook
local mapHookFrame = CreateFrame("Frame")
mapHookFrame:RegisterEvent("ADDON_LOADED")
mapHookFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "Blizzard_WorldMap" and WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            YBP:RefreshDebugPanel()
        end)
        WorldMapFrame:HookScript("OnUpdate", function()
            YBP:RefreshDebugPanel()
        end)
    end
end)
