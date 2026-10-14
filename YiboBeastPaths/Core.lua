local addonName, ns = ...
local T = ns.Text

local defaults = {
    selectedPet = 50812,
    visible = true,
}

local YBP = CreateFrame("Frame")
_G.YiboBeastPaths = YBP

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end

    return IsAddOnLoaded(name)
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

function YBP:GetSelectedPetInfo()
    return ns.pets[self.db.selectedPet]
end

function YBP:ToggleRoutes()
    self.db.visible = not self.db.visible
    self:RefreshWorldMapButton()
    self:RefreshMapLayer()
    if self.RefreshMinimapLayer then
        self:RefreshMinimapLayer()
    end
end

function YBP:RefreshWorldMapButton()
    local button = self.mapButton
    if not button then
        return
    end

    local enabled = self.db and self.db.visible
    local label = enabled and T("ROUTES_ON") or T("ROUTES_OFF")
    if button.SetText then
        button:SetText(label)
    end

    local text = button.label or button:GetFontString()
    if text and text.SetText then
        text:SetText(label)
        if enabled then
            text:SetTextColor(1.00, 0.84, 0.10)
        else
            text:SetTextColor(0.82, 0.82, 0.82)
        end
    end
end

function YBP:CreateWorldMapButton()
    if self.mapButton or not WorldMapFrame then
        return
    end

    local button = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
    button:SetSize(132, 28)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 20)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMLEFT", 16, 42)
    if button.Left then
        button.Left:SetAlpha(0.95)
    end
    if button.Middle then
        button.Middle:SetAlpha(0.95)
    end
    if button.Right then
        button.Right:SetAlpha(0.95)
    end
    local text = button:GetFontString()
    if text and text.SetFontObject then
        text:SetFontObject("GameFontHighlightSmall")
        text:SetShadowOffset(1, -1)
    else
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetShadowOffset(1, -1)
        button.label:SetJustifyH("CENTER")
        button.label:SetJustifyV("MIDDLE")
    end
    button:Show()
    button:SetScript("OnClick", function(btn)
        YBP:ToggleRoutes()
    end)
    button:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T("BRAND"))
        GameTooltip:AddLine(T("TOGGLE_HINT"), 1, 1, 1)
        GameTooltip:AddLine(YBP.db and YBP.db.visible and T("STATUS_ON") or T("STATUS_OFF"), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.mapButton = button
    self:RefreshWorldMapButton()

    WorldMapFrame:HookScript("OnShow", function()
        if YBP.mapButton then
            YBP.mapButton:Show()
        end
        YBP:RefreshWorldMapButton()
        YBP:RefreshMapLayer()
    end)

    WorldMapFrame:HookScript("OnUpdate", function(_, elapsed)
        -- Map scrolling is handled by the overlay's parent.  Poll only for
        -- map/frame changes that lack a dedicated event, and only rebuild when
        -- their render signature changes.
        YBP.mapLayerPollElapsed = (YBP.mapLayerPollElapsed or 0) + (elapsed or 0)
        if YBP.mapLayerPollElapsed < 0.15 then return end
        YBP.mapLayerPollElapsed = 0
        local signature = YBP:GetMapLayerRenderSignature()
        if signature ~= YBP.mapLayerRenderSignature then
            YBP:RefreshMapLayer()
        end
    end)
end

function YBP:TryInitializeWorldMapIntegration()
    self:CreateWorldMapButton()
    self:RefreshMapLayer()
end

function YBP:TryInitializeMinimapIntegration()
    if self.InitializeMinimapRenderer then
        self:InitializeMinimapRenderer()
    end

    if self.RefreshMinimapLayer then
        self:RefreshMinimapLayer()
    end
end

SLASH_YIBOBEASTPATHS1 = "/ybp"
SlashCmdList.YIBOBEASTPATHS = function(msg)
    msg = strtrim(msg or "")

    if msg == "mmdebug" then
        if YBP.RefreshMinimapLayer then
            YBP:RefreshMinimapLayer(true)
        end

        if YBP.GetMinimapDebugReport then
            for _, line in ipairs(YBP:GetMinimapDebugReport()) do
                print(line)
            end
        else
            print(T("MINIMAP_UNAVAILABLE"))
        end
        return
    end

    if msg == "debug" then
        if YBP.OpenCoreRouteMaintenance then
            YBP:OpenCoreRouteMaintenance()
        else
            print(T("CORE_REQUIRED"))
        end
        return
    end

    if msg == "" or msg == "toggle" then
        YBP:ToggleRoutes()
        return
    end

    if msg == "show" then
        YBP.db.visible = true
        YBP:RefreshWorldMapButton()
        YBP:RefreshMapLayer()
        if YBP.RefreshMinimapLayer then
            YBP:RefreshMinimapLayer()
        end
        return
    end

    if msg == "hide" then
        YBP.db.visible = false
        YBP:RefreshWorldMapButton()
        YBP:RefreshMapLayer()
        if YBP.RefreshMinimapLayer then
            YBP:RefreshMinimapLayer()
        end
        return
    end

    print(T("COMMAND_HELP"))
end

YBP:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(_G.YiboBeastPathsDB) ~= "table" then
                _G.YiboBeastPathsDB = {}
            end
            CopyDefaults(_G.YiboBeastPathsDB, defaults)
            self.db = _G.YiboBeastPathsDB

            if IsAddOnLoadedCompat("Blizzard_WorldMap") or WorldMapFrame then
                self:TryInitializeWorldMapIntegration()
            end
            self:TryInitializeMinimapIntegration()
        elseif arg1 == "Blizzard_WorldMap" and self.db then
            self:TryInitializeWorldMapIntegration()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:TryInitializeWorldMapIntegration()
        self:TryInitializeMinimapIntegration()
    end
end)

YBP:RegisterEvent("ADDON_LOADED")
YBP:RegisterEvent("PLAYER_ENTERING_WORLD")
