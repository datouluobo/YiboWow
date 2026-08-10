-- YiboBrokerMinimap
-- Version: 1.0.0
-- Shared source module copied between:
--   - YiboQuestBlocker
--   - YiboAltoBoss
-- Maintenance rule:
--   Any fix or feature change in this file should be mirrored to the sibling project copy.
-- Scope:
--   Shared Broker / LibDBIcon / fallback minimap / hover entry behavior only.

local YiboBrokerMinimap = _G.YiboBrokerMinimap or {}
_G.YiboBrokerMinimap = YiboBrokerMinimap

local DEFAULT_RADIUS = 80
local DEFAULT_BUTTON_SIZE = 32
local DEFAULT_TOOLTIP = GameTooltip

local function PositionTooltip(tooltip, frame)
    if not (tooltip and frame and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom) then
        return
    end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not (left and right and top and bottom) then
        return
    end

    local parent = UIParent
    local parentScale = parent:GetEffectiveScale()
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or parentScale
    local ratio = frameScale / parentScale
    local parentWidth = parent:GetWidth() or 0
    local parentHeight = parent:GetHeight() or 0
    local tooltipWidth = tooltip:GetWidth()
    local tooltipHeight = tooltip:GetHeight()
    local margin = 10
    local gap = 12

    left = left * ratio
    right = right * ratio
    top = top * ratio
    bottom = bottom * ratio

    if not tooltipWidth or tooltipWidth <= 0 then
        tooltipWidth = math.max(220, right - left)
    end
    if not tooltipHeight or tooltipHeight <= 0 then
        tooltipHeight = math.max(40, top - bottom)
    end

    local desiredLeft = right + gap
    if desiredLeft + tooltipWidth + margin > parentWidth then
        desiredLeft = left - tooltipWidth - gap
    end
    desiredLeft = math.max(margin, math.min(desiredLeft, math.max(margin, parentWidth - tooltipWidth - margin)))

    local minTop = tooltipHeight + margin
    local maxTop = parentHeight - margin
    local desiredTop = math.max(minTop, math.min(top, maxTop))

    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", desiredLeft, desiredTop)
end

local Adapter = {}
Adapter.__index = Adapter

function Adapter:GetOption(name)
    return self.options and self.options[name]
end

function Adapter:GetMinimapConfig()
    local getter = self:GetOption("GetMinimapConfig")
    if type(getter) == "function" then
        return getter() or {}
    end
    return {}
end

function Adapter:GetBrokerText()
    local getter = self:GetOption("GetBrokerText")
    if type(getter) == "function" then
        return getter()
    end
    return self:GetOption("brokerText")
end

function Adapter:PersistConfig()
    local persist = self:GetOption("PersistConfig")
    if type(persist) == "function" then
        persist()
    end
end

function Adapter:SetMinimapPosition(angle)
    local setter = self:GetOption("SetMinimapPosition")
    if type(setter) == "function" then
        setter(angle)
        return
    end

    local minimapConfig = self:GetMinimapConfig()
    minimapConfig.minimapPos = angle
end

function Adapter:GetMinimapPosition()
    local getter = self:GetOption("GetMinimapPosition")
    if type(getter) == "function" then
        return getter() or 0
    end

    local minimapConfig = self:GetMinimapConfig()
    if minimapConfig.minimapPos == nil then
        minimapConfig.minimapPos = 0
    end
    return minimapConfig.minimapPos or 0
end

function Adapter:ResetHoverState()
    self.hoverOpenedTransient = false
    self.hoverAnchorFrame = nil
    self.hoverCloseToken = (self.hoverCloseToken or 0) + 1
end

function Adapter:CancelPendingClose()
    self.hoverCloseToken = (self.hoverCloseToken or 0) + 1
end

function Adapter:IsPrimaryWindowShown()
    local checker = self:GetOption("IsPrimaryWindowShown")
    if type(checker) == "function" then
        return not not checker()
    end
    return false
end

function Adapter:ShouldShowHover(anchorFrame, isShiftDown)
    local mode = self:GetOption("GetHoverMode")
    if type(mode) == "function" then
        local result = mode(anchorFrame, isShiftDown)
        if result == false or result == "disabled" then
            return false
        end
    end

    local shouldShow = self:GetOption("ShouldShowHover")
    if type(shouldShow) == "function" then
        return not not shouldShow(anchorFrame, isShiftDown)
    end
    return true
end

function Adapter:ShowTransientHover(anchorFrame, isShiftDown)
    local show = self:GetOption("ShowTransientHover")
    if type(show) == "function" then
        return not not show(anchorFrame, isShiftDown)
    end
    return false
end

function Adapter:HideTransientHover()
    local hide = self:GetOption("HideTransientHover")
    if type(hide) == "function" then
        hide()
    end
end

function Adapter:DispatchClick(button)
    local isShiftDown = IsShiftKeyDown and IsShiftKeyDown()
    local callback
    if button == "LeftButton" and isShiftDown and type(self:GetOption("OnShiftLeftClick")) == "function" then
        callback = self:GetOption("OnShiftLeftClick")
    elseif button == "LeftButton" then
        callback = self:GetOption("OnLeftClick")
    elseif button == "RightButton" then
        callback = self:GetOption("OnRightClick")
    end

    self:ResetHoverState()
    if type(callback) == "function" then
        callback(button, isShiftDown)
    end
end

function Adapter:HandleHoverEnter(anchorFrame, isShiftDown)
    DEFAULT_TOOLTIP:Hide()
    self.hoverAnchorFrame = anchorFrame
    self.hoverOpenedTransient = false
    self:CancelPendingClose()

    local onEnter = self:GetOption("OnEnter")
    if type(onEnter) == "function" then
        onEnter(anchorFrame, isShiftDown)
    end

    if self:IsPrimaryWindowShown() then
        return
    end
    if not self:ShouldShowHover(anchorFrame, isShiftDown) then
        return
    end

    self.hoverOpenedTransient = self:ShowTransientHover(anchorFrame, isShiftDown)
end

function Adapter:TryCloseTransientHover()
    if not self.hoverOpenedTransient or self:IsPrimaryWindowShown() then
        return
    end

    if self.hoverAnchorFrame and MouseIsOver(self.hoverAnchorFrame) then
        return
    end

    for frame in pairs(self.hoverFrames) do
        if frame and frame.IsShown and frame:IsShown() and MouseIsOver(frame) then
            return
        end
    end

    self:HideTransientHover()
    self.hoverOpenedTransient = false
    self.hoverAnchorFrame = nil
end

function Adapter:HandleHoverLeave()
    DEFAULT_TOOLTIP:Hide()

    local onLeave = self:GetOption("OnLeave")
    if type(onLeave) == "function" then
        onLeave()
    end

    if not self.hoverOpenedTransient then
        self.hoverAnchorFrame = nil
        return
    end

    self:CancelPendingClose()
    local token = self.hoverCloseToken
    local function closeLater()
        if token ~= self.hoverCloseToken then
            return
        end
        self:TryCloseTransientHover()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.03, closeLater)
    else
        closeLater()
    end
end

function Adapter:RegisterHoverFrame(frame)
    if not frame or self.hoverFrames[frame] then
        return
    end

    self.hoverFrames[frame] = true
    frame:HookScript("OnEnter", function()
        self:CancelPendingClose()
    end)
    frame:HookScript("OnLeave", function()
        self:HandleHoverLeave()
    end)
end

function Adapter:ShowTooltip(anchorFrame)
    local buildTooltip = self:GetOption("BuildTooltip")
    local onTooltipShow = self:GetOption("OnTooltipShow")
    if type(buildTooltip) ~= "function" and type(onTooltipShow) ~= "function" then
        return
    end

    local tooltip = self:GetOption("tooltipFrame") or DEFAULT_TOOLTIP
    tooltip:SetOwner(anchorFrame, "ANCHOR_NONE")
    tooltip:ClearLines()

    if type(buildTooltip) == "function" then
        buildTooltip(tooltip, anchorFrame)
        PositionTooltip(tooltip, anchorFrame)
        tooltip:Show()
        return
    end

    onTooltipShow(anchorFrame, tooltip)
    PositionTooltip(tooltip, anchorFrame)
    tooltip:Show()
end

function Adapter:HandleFallbackEnter(frame)
    local isShiftDown = IsShiftKeyDown and IsShiftKeyDown()
    self:HandleHoverEnter(frame, isShiftDown)
    self:ShowTooltip(frame)
end

function Adapter:HandleBrokerTooltipShow(tooltip)
    local anchorFrame = tooltip and tooltip.GetOwner and tooltip:GetOwner() or self.hoverAnchorFrame
    local isShiftDown = IsShiftKeyDown and IsShiftKeyDown()
    self:HandleHoverEnter(anchorFrame, isShiftDown)

    local buildTooltip = self:GetOption("BuildTooltip")
    local onTooltipShow = self:GetOption("OnTooltipShow")
    if type(buildTooltip) == "function" then
        tooltip:ClearLines()
        buildTooltip(tooltip, anchorFrame)
    elseif type(onTooltipShow) == "function" then
        onTooltipShow(anchorFrame, tooltip)
    end
    PositionTooltip(tooltip, anchorFrame)
end

function Adapter:UpdateFallbackPosition()
    if not self.fallbackButton then
        return
    end

    local angle = self:GetMinimapPosition()
    local radius = self:GetOption("fallbackRadius") or DEFAULT_RADIUS
    local x = radius * math.cos(angle)
    local y = radius * math.sin(angle)
    self.fallbackButton:ClearAllPoints()
    self.fallbackButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Adapter:CreateFallbackButton()
    if self.fallbackButton then
        self.fallbackButton:Show()
        self:UpdateFallbackPosition()
        return self.fallbackButton
    end

    local buttonName = self:GetOption("fallbackButtonName") or ((self:GetOption("addonName") or "YiboBrokerMinimap") .. "_MinimapBtn")
    local button = CreateFrame("Button", buttonName, Minimap, "BackdropTemplate")
    button:SetSize(self:GetOption("fallbackButtonSize") or DEFAULT_BUTTON_SIZE, self:GetOption("fallbackButtonSize") or DEFAULT_BUTTON_SIZE)
    button:SetFrameStrata(self:GetOption("fallbackFrameStrata") or "MEDIUM")
    button:SetFrameLevel(self:GetOption("fallbackFrameLevel") or 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    icon:SetTexture(self:GetOption("iconPath"))
    button.icon = icon

    local hlTex = button:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetColorTexture(1, 1, 1, 0.14)
    hlTex:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    hlTex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

    local customize = self:GetOption("CustomizeFallbackButton")
    if type(customize) == "function" then
        customize(button, icon)
    end

    button:SetScript("OnDragStart", function(dragButton)
        dragButton:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            if not cx then
                return
            end

            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mx = mx / scale
            my = my / scale

            local dx = mx - cx
            local dy = my - cy
            local angle = math.atan2(dy, dx)
            if angle < 0 then
                angle = angle + 2 * math.pi
            end

            self:SetMinimapPosition(angle)
            self:UpdateFallbackPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(dragButton)
        dragButton:SetScript("OnUpdate", nil)
        self:PersistConfig()
    end)

    button:SetScript("OnClick", function(_, buttonNameArg)
        self:DispatchClick(buttonNameArg)
    end)
    button:SetScript("OnEnter", function()
        self:HandleFallbackEnter(button)
    end)
    button:SetScript("OnLeave", function()
        self:HandleHoverLeave()
    end)

    self.fallbackButton = button
    self:UpdateFallbackPosition()
    return button
end

function Adapter:TryInitBrokerMinimap()
    local ok, result = pcall(function()
        if type(LibStub) ~= "table" or not LibStub.GetLibrary then
            return false
        end

        local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
        local icon = LibStub:GetLibrary("LibDBIcon-1.0", true)
        if not ldb or not icon then
            return false
        end

        if not self.brokerDataObject then
            self.brokerDataObject = ldb:NewDataObject(self:GetOption("addonName"), {
                type = "launcher",
                icon = self:GetOption("iconPath"),
                text = self:GetBrokerText(),
                OnClick = function(_, button)
                    self:DispatchClick(button)
                end,
                OnTooltipShow = function(tooltip)
                    self:HandleBrokerTooltipShow(tooltip)
                end,
                OnLeave = function()
                    self:HandleHoverLeave()
                end,
            })
        end

        self.brokerDataObject.icon = self:GetOption("iconPath")
        self.brokerDataObject.text = self:GetBrokerText()

        icon:Register(self:GetOption("addonName"), self.brokerDataObject, self:GetMinimapConfig())
        if self.fallbackButton then
            self.fallbackButton:Hide()
        end
        return true
    end)

    if not ok then
        return false
    end
    return result == true
end

function Adapter:RefreshBrokerData()
    if not self.brokerDataObject then
        return
    end

    self.brokerDataObject.icon = self:GetOption("iconPath")
    self.brokerDataObject.text = self:GetBrokerText()
end

function Adapter:Init()
    if not self:TryInitBrokerMinimap() then
        self:CreateFallbackButton()
    end
    return self
end

function YiboBrokerMinimap:Init(options)
    local adapter = setmetatable({
        options = options or {},
        hoverCloseToken = 0,
        hoverFrames = {},
    }, Adapter)
    return adapter:Init()
end
