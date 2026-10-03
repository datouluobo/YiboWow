-- Run from workspace root: lua YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua
local frames = {}
local methods = {}
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:GetText() return self.text or "" end
function methods:SetValue(value) self.value = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 600 end
function methods:GetHeight() return self.height or 100 end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return 1 end
function methods:GetFrameStrata() return "DIALOG" end
function methods:SetPoint(point, ...) self.point = { point, ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    for _, child in ipairs(self.children) do child:Hide() end
end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetEnabled(value) self.enabled = value end
function methods:ClearFocus() self.focused = false end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function methods:GetStringWidth() return #(self.text or "") * 8 end
function methods:GetStringHeight() return 18 * math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth()))) end
setmetatable(methods, { __index = function(_, key)
    if key:match("^Set") or key:match("^Register") or key:match("^Enable") or key == "Raise" then return function() end end
end })
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ scripts = {}, shown = true, parent = parent, children = {} }, { __index = methods })
    frames[#frames + 1] = frame
    if parent then parent.children[#parent.children + 1] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
STANDARD_TEXT_FONT, ACCEPT, CANCEL = "font", "确定", "取消"
StaticPopupDialogs = {}
local popup
function StaticPopup_Show(name, text, _, data) popup = { name = name, text = text, data = data }; return popup end
function StaticPopup_Hide() popup = nil end
local function Accept()
    local current = popup; popup = nil
    StaticPopupDialogs[current.name].OnAccept(nil, current.data)
end
local function Cancel()
    local current = popup; popup = nil
    StaticPopupDialogs[current.name].OnCancel(nil, current.data)
end
local cached = { [1] = "同名", [2] = "同名", [3] = "其他", [4] = "内置" }
function GetItemInfo(id)
    id = tonumber(id)
    if cached[id] then return cached[id], "|Hitem:" .. id .. ":0|h[" .. cached[id] .. "]|h", nil, nil, nil, nil, nil, nil, nil, 123 end
end
local loads, cursor, clears = {}, nil, 0
C_Item = { RequestLoadItemDataByID = function(id) loads[id] = (loads[id] or 0) + 1 end }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end, GetContainerItemID = function(_, slot) return slot end }
function GetCursorInfo() return unpack(cursor or {}) end
function ClearCursor() clears = clears + 1; cursor = nil end
YiboCore = { Capabilities = { Register = function() end } }
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/UI/Input.lua")
dofile("YiboCore/Runtime/ItemResolver.lua")
local resolverFrame = frames[#frames]
dofile("YiboCore/UI/ItemConfirmation.lua")
dofile("YiboCore/UI/ItemPicker.lua")
local Core, R = YiboCore, YiboCore.ItemResolver
local candidates = assert(R:Parse("同名", { allowName = true, includeBags = true, candidates = { { itemID = 1, title = "同名" } } }))
assert(#candidates == 2, "deduplicate ID but retain distinct same-name items")
assert(R:Parse("0") == nil and R:Parse("-2") == nil and R:Parse("1.5") == nil and R:Parse("") == nil)
assert(R:Parse("|cff00ff00|Hitem:3:0|h[其他]|h|r")[1].itemID == 3)
assert(R:Parse("999999999999999999999999") == nil)
assert(R:Parse("不存在", { allowName = true }) == nil)
assert(R:Parse("其", { allowName = true, match = "contains", candidates = { 3 } })[1].itemID == 3)
local calls = 0
local abandoned = R:Request(10, function() error("cancelled callback") end)
R:Request(10, function(info) assert(info.state == "ready"); calls = calls + 1 end)
assert(loads[10] == 1, "one load per ID")
abandoned:Cancel(); cached[10] = "加载完成"
resolverFrame.scripts.OnEvent(nil, "GET_ITEM_INFO_RECEIVED", 10, true)
assert(calls == 1)
R:Request(11, function(info, err) assert(info.state == "failed" and err); calls = calls + 1 end)
resolverFrame.scripts.OnUpdate(nil, 9)
R:Request(11, function(_, err) assert(err) end)
assert(loads[11] == 1, "failure does not automatically loop")
R:Request(11, function(info) assert(info.state == "ready") end, { retry = true })
assert(loads[11] == 2); cached[11] = "重试成功"; resolverFrame.scripts.OnEvent(nil, "GET_ITEM_INFO_RECEIVED", 11, true)

local changed = 0
local input = Core.UITheme:CreateInput(UIParent, { restoreOnEscape = true, OnChanged = function() changed = changed + 1 end })
input:SetValue("1"); assert(changed == 0)
input:SetValue("2", true); assert(changed == 1)
input.scripts.OnEditFocusGained(input); input:SetValue("3"); input.scripts.OnEscapePressed(input)
assert(input:GetText() == "2" and changed == 2)
input.focused = true; input:Hide(); assert(not input.focused)

-- Exercise real Currency business callbacks and storage through the real picker.
YiboCurrency = { NAME = "YiboCurrency", Catalog = { { itemID = 4, id = "item:4", title = "内置" } },
    CoreIntegration = { initialized = true }, Print = function(_, message) assert(message) end,
    NotifyChanged = function() end }
local settings = { customItems = {}, visible = {}, monitored = {} }
function YiboCurrency:GetSettings() return settings end
dofile("YiboCurrency/Data.lua")
dofile("YiboCurrency/Settings.lua")
local host = CreateFrame("Frame", nil, UIParent)
local refresh, reflows = 0, 0
local context = { notifyPageChanged = function() end, refreshPage = function() refresh = refresh + 1 end }
context.refreshPanel = function() reflows = reflows + 1; YiboCurrency:CreateSettingsPanel(host, context) end
YiboCurrency:CreateSettingsPanel(host, context)
local picker = host.ycuSettings.itemPicker
local emptyHeight = picker:GetHeight()
assert(not picker.dropdown:IsShown() and not picker.retry:IsShown() and not picker.preview:IsShown())
picker:SetValue("同名"); picker:Resolve("add"); assert(not popup and picker.preview:GetText():find("多个"))
assert(picker.dropdown:IsShown() and not picker.retry:IsShown() and picker:GetHeight() > emptyHeight and reflows > 0)
picker.dropdown.onValueChanged(2); picker:Resolve("add"); assert(popup)
Cancel(); assert(#settings.customItems == 0 and picker.input:GetText() == "同名")
picker:Resolve("add"); picker:Resolve("add"); Accept()
assert(#settings.customItems == 1 and settings.customItems[1].itemID == 2 and picker.input:GetText() == "" and refresh == 1)
picker:SetValue("2"); picker:Resolve("add"); assert(not popup and picker.input:GetText() == "2")
assert(not picker.dropdown:IsShown() and not picker.retry:IsShown(), "single match and business failure need no extra controls")
picker:SetValue("99"); picker:Resolve("add"); resolverFrame.scripts.OnUpdate(nil, 9)
assert(picker.retry:IsShown() and not picker.dropdown:IsShown(), "only load failure offers retry")
cached[99] = "恢复加载"; picker.retry.scripts.OnClick(picker.retry)
assert(not picker.retry:IsShown() and popup); Cancel()
picker:SetValue("")
assert(not picker.retry:IsShown() and not picker.preview:IsShown() and picker:GetHeight() == emptyHeight)
settings.visible["item:2"], settings.monitored["item:2"] = true, true
settings.hoverOrderOverride = { "item:2" }
cursor = { "item", 2 }; picker:ReadCursor(); assert(popup and clears == 1)
Accept(); assert(#settings.customItems == 0 and settings.monitored["item:2"] == nil and #settings.hoverOrderOverride == 0)
cursor = { "item", 4 }; picker:ReadCursor(); assert(not popup and picker.preview:GetText():find("内置"))
cursor = { "spell", 1 }; picker:ReadCursor(); assert(clears == 2 and not popup)
cursor = { "item", 3 }; picker:ReadCursor(); assert(popup)
local stale = popup.data; picker:SetValue("1"); assert(not popup)
StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, stale); assert(#settings.customItems == 0)
picker:SetValue("20"); picker:Resolve("add"); picker:SetValue("1"); cached[20] = "迟到"
resolverFrame.scripts.OnEvent(nil, "GET_ITEM_INFO_RECEIVED", 20, true)
assert(not popup and picker.input:GetText() == "1")
picker:SetValue("21"); picker:Resolve("add"); picker:Hide(); cached[21] = "隐藏后"
resolverFrame.scripts.OnEvent(nil, "GET_ITEM_INFO_RECEIVED", 21, true); assert(not popup)
picker:Show(); picker:SetValue("1"); picker:Resolve("add"); stale = popup.data; host:Hide()
StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, stale); assert(#settings.customItems == 0)
host:Show(); picker:Show(); assert(YiboCurrency:AddCustomItem(3))
YiboCurrency:ConfirmRemoveCustomItem(3, nil, host); Accept(); assert(#settings.customItems == 0)
assert(YiboCurrency:AddCustomItem(3)); YiboCurrency:ConfirmRemoveCustomItem(3, nil, host)
stale = popup.data; host:Hide(); assert(not popup)
StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, stale); assert(#settings.customItems == 1)

picker:Show(); host:Show(); picker.config.OnLayoutChanged = nil
local wide = picker:Layout(900); local narrow = picker:Layout(220)
assert(narrow > wide)
for _, group in ipairs(picker.controls) do if group.control:IsShown() then assert(group.control:GetWidth() <= 220) end end
assert(picker.controls[#picker.controls].control == picker.remove, "delete remains the last operation")
picker:SetValue(""); picker:Layout(900)
local lastVisible
for _, group in ipairs(picker.controls) do if group.control:IsShown() then lastVisible = group.control end end
assert(math.abs(lastVisible.point[2] + lastVisible:GetWidth() - picker.layoutContentWidth) < 0.01, "wide input consumes usable row width")
assert(picker.layoutContentWidth == 900 - Core.UITheme.Space.md, "reserve scrollbar spacing")
local buttonWidth
for _, group in ipairs(picker.controls) do
    if not group.flexible and group.control:IsShown() then
        buttonWidth = buttonWidth or group.control:GetWidth()
        assert(group.control:GetWidth() == buttonWidth, "operation buttons have equal widths")
    end
end
assert(picker.input.point[3] == picker.remove.point[3], "all four default controls share a row when they fit")
local wideInput = picker.input:GetWidth()
picker:Layout(220); assert(picker.input:GetWidth() == picker.layoutContentWidth and wideInput > 220, "narrow input expands across its own row")
for _, width in ipairs({ 360, 600, 760, 1100 }) do
    picker:Layout(width)
    for _, group in ipairs(picker.controls) do
        local control = group.control
        if control:IsShown() then assert(control.point[2] + control:GetWidth() <= picker.layoutContentWidth + 0.01, "all rows preserve scrollbar spacing") end
    end
end
local many = {}; for id = 30, 48 do cached[id] = "分页"; many[#many + 1] = id end
local selectPicker = Core:CreateItemPicker(UIParent, { resolve = { allowName = true, candidates = many },
    actions = { { label = "添加当前目标", Execute = function() return true, "已添加 NPC 目标" end } } })
selectPicker:SetValue("分页"); selectPicker:Resolve("select"); assert(#selectPicker.dropdown.options == 9)
selectPicker.dropdown.onValueChanged("next"); assert(selectPicker.page == 2)
local extension = selectPicker.controls[#selectPicker.controls].control
extension.scripts.OnClick(extension); assert(selectPicker.preview:GetText() == "已添加 NPC 目标")
selectPicker:Unbind(); cached[49] = "解绑"; selectPicker:Resolve("select"); assert(not popup)

-- Old Core must stop before registering a page or touching the new controls.
Core.CheckAPIVersion = function() return false end
Core.AccountView, Core.Entry, Core.CurrencyCatalog = {}, {}, {}
Core.RegisterAddon = function() error("old Core must not register") end
dofile("YiboCurrency/CoreIntegration.lua")
local ok, err = YiboCurrency.CoreIntegration:Initialize()
assert(not ok and err:find("1.6.1") and err:find("v7"))
print("CoreItemControlsSpec: passed resolver, input, picker, Currency operations, lifecycle, layout and old-Core checks")
