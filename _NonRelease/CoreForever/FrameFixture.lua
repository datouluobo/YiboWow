-- Core client simulation; common frame methods adapted from the existing workspace fixture.
-- Lua 5.1: actual workspace/models/theme, simulated WoW frames and snapshots.
local methods = {}
WOW_PROJECT_MISTS_CLASSIC = 19
function methods:SetClampedToScreen() end
function methods:GetStringHeight()
    return math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth()))) * (self.fontSize or 16)
end
local function Frame(parent)
    local frame = setmetatable({ parent = parent, children = {}, shown = true, enabled = true,
        scripts = {}, hooks = {}, points = {}, _frameLevel = parent and parent._frameLevel + 1 or 1 }, { __index = methods })
    if parent then parent.children[#parent.children + 1] = frame end
    return frame
end
for _, name in ipairs({ "SetJustifyV", "SetWordWrap", "SetVertexColor", "SetTextInsets", "SetBackdrop", "EnableMouse", "SetJustifyH",
    "SetAutoFocus", "SetMaxLetters", "SetNumeric", "SetAlpha", "SetClipsChildren", "EnableMouseWheel", "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "RegisterForClicks", "SetTexture", "SetDesaturated", "SetOwner", "SetHyperlink", "AddLine",
    "Raise", "ClearFocus", "SetColorTexture", "SetToplevel", "SetBackdropColor", "SetBackdropBorderColor", "SetTexCoord" }) do methods[name] = function() end end
function methods:SetAllPoints(target) self.allPoints = target or self.parent end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetStringWidth() return #(self.text or ""):gsub("[\128-\191]", "") * (self.fontSize or 16) * 0.75 end
function methods:GetChildren() return unpack(self.children) end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return self._frameLevel end
function methods:SetFrameLevel(v) self._frameLevel = v end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameStrata(v) self.strata = v end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {}; self.allPoints = nil end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.allPoints and self.allPoints:GetWidth() or self.width or (self.parent and self.parent:GetWidth()) or 1000 end
function methods:GetHeight() return self.allPoints and self.allPoints:GetHeight() or self.height or (self.parent and self.parent:GetHeight()) or 620 end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, hook in ipairs(self.hooks[event] or {}) do hook(self, ...) end
end
function methods:SetText(v)
    self.textWrites = (self.textWrites or 0) + 1
    self.text, self.cursor, self.composing = tostring(v or ""), #tostring(v or ""), false
    self:Fire("OnTextChanged", false)
end
function methods:InputText(v)
    self.text, self.cursor = tostring(v or ""), #tostring(v or "")
    self:Fire("OnTextChanged", true)
end
function methods:IsInIMEComposition() return self.composing == true end
function methods:GetText() return self.text or "" end
function methods:SetFocus() self.focused = true; self:Fire("OnEditFocusGained") end
function methods:ClearFocus() self.focused, self.composing = false, false end
function methods:ClearLines() self.lines = {} end
function methods:NumLines() return #(self.lines or {}) end
function methods:SetHyperlink(link) self.link = link; self.lines = { { text = "Native item: " .. link } } end
function methods:AddLine(text, red, green, blue, wrap)
    self.lines = self.lines or {}; self.lines[#self.lines + 1] = { text = text, color = { red, green, blue }, wrap = wrap }
end
function methods:AddDoubleLine(label, value)
    self.lines = self.lines or {}; self.lines[#self.lines + 1] = { label = label, value = value }
end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k, v) self.hooks[k] = self.hooks[k] or {}; table.insert(self.hooks[k], v) end
function methods:CreateFontString() return Frame(self) end
function methods:CreateTexture() return Frame(self) end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Show() local was = self.shown; self.shown = true; if not was then self:Fire("OnShow") end end
function methods:Hide() local was = self.shown; self.shown = false; if was then self:Fire("OnHide") end end
function methods:SetEnabled(v) self.enabled = v end
function methods:IsEnabled() return self.enabled end
function methods:SetScrollChild(v) self.child = v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
function methods:SetMinMaxValues(low, high) self.min, self.max = low, high end
function methods:SetValue(v) if self.value ~= v then self.value = v; self:Fire("OnValueChanged", v) end end
function methods:SetThumbTexture(v) self.thumb = v end
function methods:GetThumbTexture() return self.thumb end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index]) end
function methods:SetContentHeight(v) self.contentHeight = v end
function methods:SetVerticalScroll(v) if self.offset ~= v then self.offset = v; self:Fire("OnVerticalScroll", v) end end
function methods:SetChecked(v) self.checked = not not v end
function methods:GetChecked() return self.checked end
function methods:GetBottom() return 500 end
function CreateFrame(_, _, parent) return Frame(parent) end
UIParent, GameTooltip = Frame(), Frame()

-- Reuse the workspace frame simulation, with explicit lifecycle/window methods.
for _, name in ipairs({"SetMovable", "SetResizable", "SetResizeBounds", "SetClampRectInsets", "RegisterForDrag", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetMaskTexture", "SetHitRectInsets", "SetBlendMode", "SetDrawLayer", "SetRotation", "SetMultiLine", "SetFontObject", "HighlightText", "SetCursorPosition", "RegisterAutoHide", "UnregisterAutoHide"}) do
    methods[name] = function() end
end
function methods:GetEffectiveScale() return 1 end
function methods:GetLeft() return 16 end
function methods:GetRight() return self:GetLeft() + self:GetWidth() end
function methods:GetTop() return 900 end
function methods:GetCenter() return 500, 400 end
function methods:GetNormalTexture() return self.normalTexture end
function methods:SetOwner(owner) self.owner = owner end
function methods:GetOwner() return self.owner end
function methods:StopMovingOrSizing() end
function methods:RegisterEvent(event)
    if TEST_FOREVER and event == "PLAYERBANKSLOTS_CHANGED" then error("Removed event in simulated client") end
    self.events = self.events or {}; self.events[event] = true
end
function methods:UnregisterEvent(event) if self.events then self.events[event] = nil end end
function methods:GetName() return self.name end
function methods:GetAttribute(key) return self.attributes and self.attributes[key] end
function methods:SetAttribute(key, value) self.attributes = self.attributes or {}; self.attributes[key] = value end
function methods:SetFrameRef(key, value) self.refs = self.refs or {}; self.refs[key] = value end
local originalCreate = CreateFrame
TEST_FRAMES = {}
function CreateFrame(kind, name, parent, template)
    local f = originalCreate(kind, name, parent)
    f.kind, f.name, f.template = kind, name, template
    if name then _G[name] = f end
    TEST_FRAMES[#TEST_FRAMES + 1] = f
    return f
end
UIParent:SetSize(1600, 1000)
Minimap = CreateFrame("Frame"); Minimap:SetSize(140, 140)
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) TEST_MESSAGES[#TEST_MESSAGES + 1] = message end }
STANDARD_TEXT_FONT = "font"
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
tinsert, tremove, wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end end
strtrim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
BreakUpLargeNumbers = tostring
date, time = os.date, os.time
function GetLocale() return "zhCN" end
function GetServerTime() return 1792339474 end
function GetTime() return 100 end
function InCombatLockdown() return false end
function UnitGUID() return TEST_GUID end
function UnitName() return "ProbeCharacter" end
function UnitFullName() return "ProbeCharacter", "ProbeRealm" end
function GetRealmName() return "ProbeRealm" end
function GetNormalizedRealmName() return "ProbeRealm" end
function UnitClass() return "Druid", "DRUID", 11 end
function UnitLevel() return 5 end
function UnitRace() return "Skyborne", "Skyborne", 95 end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitSex() return 2 end
function IsInGuild() return false end
function GetZoneText() return "ProbeZone" end
function GetSubZoneText() return "ProbeSubZone" end
function GetNumSkillLines() return 0 end
C_Map = { GetBestMapForUnit = function() return 1 end }
C_AddOns = {
    GetAddOnInfo = function(name) if name == "YiboCore" then return name end end,
    GetAddOnMetadata = function(_, key) if key == "Version" then return TEST_FOREVER and "0.1.0" or "1.12.7" end end,
    GetAddOnEnableState = function() return 2 end,
}
C_Container = { GetContainerNumSlots = function() return 20 end, GetContainerItemID = function() return 6948 end }
C_Item = { GetItemInfo = function() return nil end }
C_Timer = { After = function(delay, callback) TEST_TIMERS[#TEST_TIMERS + 1] = { delay, callback } end }
SlashCmdList = {}
StaticPopupDialogs = {}
function RegisterStateDriver(frame, state, condition) frame.stateDriver = { state, condition } end
