-- Real target manifests; synthetic native functions and frames, no player WTF or client installation.
local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
for _, forever in ipairs({ false, true }) do
    local cached, requested, bags, clearCount = {}, {}, {}, 0
    local e, c, fire, flush, load = Boot(forever, nil, nil, function(env)
        env.GetItemInfo = function(id)
            if cached[id] then return cached[id], "item:" .. id, nil, nil, nil, nil, nil, nil, nil, 123 end
        end
        env.C_Item.RequestLoadItemDataByID = function(id) requested[id] = (requested[id] or 0) + 1 end
        env.C_Container.GetContainerNumSlots = function(bag) bags[#bags + 1] = bag; return 1 end
        env.C_Container.GetContainerItemID = function(bag) return bag + 1 end
        env.Enum = { BagIndex = { ReagentBag = 5 } }
        env.GetCursorPosition = function() return 50, 60 end
        env.GetCursorInfo = function() return "item", 1 end
        env.ClearCursor = function() clearCount = clearCount + 1 end
        env.GetMouseFoci = function() return {} end
    end)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    Check(c:IsInitialized(), "target initializes")
    local client, resolver = c.Client, c.ItemResolver
    local surface = client.surface
    load("YiboCore/" .. (forever and "Forever" or "Mists") .. "/Surface.lua")
    Check(client.surface == surface, "binding idempotent")
    Check(not pcall(client.ConfigureSurface, client, "Retail", {}), "wrong target binding rejected")
    cached[1], cached[2] = "Same", "Same"
    Check(resolver:GetInfo(1).icon == 123 and resolver:GetInfo(1).state == "ready", "typed native cache snapshot")
    local info = resolver:GetInfo(1); info.name = "mutated"
    Check(resolver:GetInfo(1).name == "Same", "public snapshot detached")
    Check(resolver:Parse("0") == nil and resolver:Parse("-1") == nil and resolver:Parse("1.2") == nil, "ID validation")
    Check(resolver:Parse("|Hitem:1:0|h[Same]|h")[1].itemID == 1, "link parser retained")
    local candidates = resolver:Parse("same", { allowName = true, includeBags = true, candidates = { 1, 2 } })
    Check(#candidates == 2, "same name distinct IDs, deduplicated sources")
    Check(#bags == (forever and 6 or 5) and bags[#bags] == (forever and 5 or 4), "target declares actual candidate bag range")
    e.Enum.BagIndex.ReagentBag = nil; bags = {}
    Check(client:ReadBagItemIDs() and #bags == 5, "reagent slot omitted without target declaration")
    e.C_Container.GetContainerNumSlots = function() error("not available") end
    Check(client:ReadBagItemIDs() == nil, "bag failure never partial empty success")
    Check(resolver:Parse("Same", { allowName = true, includeBags = true, candidates = { 1 } }) == nil, "failed requested scope not advertised complete")
    e.C_Container = nil
    e.GetContainerNumSlots = function() return 1 end
    e.GetContainerItemID = function() return 1 end
    Check(#client:ReadBagItemIDs() == 5, "legacy container binding")
    e.GetContainerNumSlots = function() return -1 end
    Check(client:ReadBagItemIDs() == nil, "invalid slot count rejected")
    local calls, cancelled = 0, 0
    resolver:Request(10, function(value, message) calls = calls + 1; Check(value.state == "ready" and not message, "event completion") end)
    local waiter = resolver:Request(10, function() cancelled = cancelled + 1 end)
    waiter:Cancel()
    Check(requested[10] == 1, "requests coalesced")
    cached[10] = "Loaded"; fire("GET_ITEM_INFO_RECEIVED", 10, true)
    Check(calls == 1 and cancelled == 0 and resolver.pending[10] == nil, "cancellation and single completion")
    fire("GET_ITEM_INFO_RECEIVED", 10, true)
    Check(calls == 1, "duplicate event ignored")
    resolver:Request(10, function() calls = calls + 1 end)
    Check(calls == 2 and requested[10] == 1, "cached request immediate")
    local failed = 0
    resolver:Request(11, function(value, message) failed = failed + 1; Check(value.state == "failed" and message, "failed result explicit") end)
    fire("GET_ITEM_INFO_RECEIVED", 11, false)
    resolver:Request(11, function(_, message) Check(message ~= nil, "no automatic retry") end)
    Check(failed == 1 and requested[11] == 1, "failed request remains bounded")
    resolver:Request(11, function(value) Check(value.state == "ready", "explicit retry completion") end, { retry = true })
    cached[11] = "Retry"; fire("GET_ITEM_INFO_RECEIVED", 11, true)
    Check(requested[11] == 2, "retry explicitly requests again")
    local afterError = 0
    resolver:Request(15, function() error("consumer callback failed") end)
    resolver:Request(15, function() afterError = afterError + 1 end)
    cached[15] = "Isolated"; fire("GET_ITEM_INFO_RECEIVED", 15, true)
    Check(afterError == 1 and not resolver.pending[15], "one callback exception cannot strand another consumer")
    local invalidTimeout = resolver:Request(16, function() end, { timeout = math.huge })
    Check(resolver.pending[16].remaining == 8, "nonfinite timeout restored to bounded default")
    invalidTimeout:Cancel(); fire("GET_ITEM_INFO_RECEIVED", 16, false)
    local timed = 0
    resolver:Request(12, function(_, message) timed = timed + 1; Check(message ~= nil, "timeout explicit") end, { timeout = .2 })
    for _, frame in ipairs(e.TEST_FRAMES) do
        if frame.events and frame.events.GET_ITEM_INFO_RECEIVED then frame.scripts.OnUpdate(frame, .3) end
    end
    Check(timed == 1 and resolver.pending[12] == nil, "polling timeout cleans up")
    e.C_Item.RequestLoadItemDataByID = function() error("request failed") end
    resolver:Request(13, function(_, message) Check(message ~= nil, "native request error controlled") end)
    Check(resolver.failed[13] and not resolver.pending[13], "native failure does not strand waiter")
    local getter = e.GetItemInfo
    e.GetItemInfo = function() error("cache failed") end
    Check(resolver:GetInfo(1).name == nil and resolver:GetInfo(1).availability == "error", "cache exception not ready")
    e.GetItemInfo = getter
    e.issecretvalue = function(value) return value == "Same" end
    Check(resolver:GetInfo(1).availability == "unavailable", "secret value rejected before string processing")
    e.issecretvalue = nil
    Check(client:ReadCursorItem() == 1 and client:ClearItemCursor(1) and clearCount == 1, "validated item cursor")
    e.GetCursorInfo = function() return "item", 2 end
    Check(not client:ClearItemCursor(1) and clearCount == 1, "changed cursor preserved")
    e.GetCursorInfo = function() error("cursor") end
    Check(client:ReadCursorItem() == nil and clearCount == 1, "failed cursor has no clear side effect")
    local oldFocus = e.CreateFrame("Frame")
    e.GetMouseFocus = function() return oldFocus end
    Check(client:ReadMouseFocus() == nil, "empty modern focus never stale legacy fallback")
    e.GetMouseFoci = function() return { oldFocus } end
    Check(client:ReadMouseFocus() == oldFocus, "modern focus")
    e.GetMouseFoci = function() error("focus") end
    local focus, state = client:ReadMouseFocus()
    Check(focus == nil and state == "error", "modern focus exception controlled")
    e.GetMouseFoci = nil
    Check(client:ReadMouseFocus() == oldFocus, "legacy focus when modern absent")
    e.GetCursorPosition = function() return 0/0, 1 end
    Check(client:ReadCursorPosition() == nil, "nonfinite coordinates rejected")
    local modernArgs, legacyArgs
    e.C_AddOns.GetAddOnInfo = function() return "Present" end
    e.C_AddOns.GetAddOnEnableState = function(...) modernArgs = { ... }; return 2 end
    local status = c.AddonStatus:Get("Present")
    Check(status.installed and status.enabled and not status.connected, "enabled does not establish business readiness")
    Check(modernArgs[1] == "Present" and modernArgs[2] == "ProbeCharacter", "modern addon argument order")
    e.C_AddOns = nil
    e.GetAddOnInfo = function() return "Present" end
    e.GetAddOnEnableState = function(...) legacyArgs = { ... }; return 0 end
    Check(not c.AddonStatus:Get("Present").enabled and legacyArgs[2] == "Present" and legacyArgs[1] == "ProbeCharacter", "legacy addon argument order")
    e.GetAddOnInfo = function() error("addon") end
    Check(c.AddonStatus:Get("Present").availability == "error" and c.AddonStatus:Get("Present").state == "unavailable", "addon exception not represented as missing")
    e.GetLooseMacroIcons = function(bucket) bucket[1] = "INV_Test" end
    e.GetMacroIcons = function() return { 123 } end
    Check(c:IsBuiltinIcon("Interface\\Icons\\INV_Test") and c:IsBuiltinIcon(123), "bucket and returned table icon forms")
    load("YiboCore/UI/IconPicker.lua")
    e.GetMacroIcons = function() error("icons") end
    Check(not c:IsBuiltinIcon("Interface\\Icons\\INV_Test"), "partial icon catalog not cached as success")
    e.GetMacroIcons = function() return { 456 } end
    Check(c:IsBuiltinIcon(456), "icon catalog retries after failure")
    load("YiboCore/UI/IconPicker.lua")
    e.GetLooseMacroIcons = nil; e.GetMacroIcons = nil
    e.GetNumMacroIcons = function() return 1 end; e.GetMacroIconInfo = function() return 789 end
    Check(c:IsBuiltinIcon(789), "legacy indexed icon catalog")
    e.InCombatLockdown = function() error("combat") end
    Check(client:IsInCombat(), "unknown combat state cannot authorize protected mutation")
    e.InCombatLockdown = function() return false end
    local driver = e.CreateFrame("Frame")
    Check(client:RegisterCombatDriver(driver) and driver.stateDriver[2] == "[combat] 1; 0", "secure driver unchanged")
    local accepted, cancelledPopup, popup = 0, 0
    e.StaticPopup_Show = function(_, _, _, data) popup = data; return {} end
    e.StaticPopup_Hide = function() end
    local function Options() return { text = "test", OnAccept = function() accepted = accepted + 1 end,
        OnCancel = function() cancelledPopup = cancelledPopup + 1 end } end
    local first = c.ItemConfirmation:Show(Options())
    local second = c.ItemConfirmation:Show(Options())
    e.StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, first)
    Check(cancelledPopup == 1 and accepted == 0, "replacement invalidates old popup")
    e.StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, second)
    e.StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil, second)
    Check(accepted == 1, "popup callback once")
    e.StaticPopup_Show = function() error("popup unavailable") end
    Check(c.ItemConfirmation:Show(Options()) == nil and cancelledPopup == 2 and c.ItemConfirmation.active == nil, "popup native failure cleans up")
    e.GetCursorPosition = function() return 50, 60 end
    local anchor = e.CreateFrame("Frame"); anchor:SetSize(100, 100)
    anchor.GetBottom = function() return 0 end
    Check(c.Entry:IsMouseOverFrame(anchor), "preview uses cursor geometry")
    e.GetCursorPosition = function() return 100000, 100000 end
    Check(not c.Entry:IsMouseOverFrame(anchor), "clipped preview cannot retain out-of-bounds cursor")
    local source, menu = e.CreateFrame("Frame"), e.CreateFrame("Frame")
    c.BusinessItemActions.bindings[source] = { menu = menu }
    c.BusinessItemActions.hoverControl = source
    e.GetMouseFocus = function() error("focus lost") end
    c.BusinessItemActions:RefreshHover()
    Check(not menu:IsShown() and c.BusinessItemActions.hoverControl == nil, "unavailable hover clears stale menu")
    c.Registry:Register("YiboFixture", { requiredAPI = 13 })
    c.AccountView._pages.fixture = { id = "fixture", addonName = "YiboFixture", title = "Fixture", defaultEnabled = true }
    Check(c.Entry:RegisterBusinessEntry("YiboFixture", { id = "fixture", pageID = "fixture", text = "Fixture" }) ~= nil, "entry registered")
    for _, id in ipairs({ "YiboCore", "fixture" }) do
        for mask = 0, 7 do
            local mini, broker, bar = mask % 2 == 1, math.floor(mask / 2) % 2 == 1, math.floor(mask / 4) % 2 == 1
            c.Entry:SetEntryChannel(id, "minimap", mini)
            c.Entry:SetEntryChannel(id, "broker", broker)
            c.Entry:SetEntryChannel(id, "builtinBar", bar)
            local actual = c.Entry:GetEntryChannels(id)
            Check(actual.minimap == mini and actual.broker == broker and actual.builtinBar == bar, "three independent channels, all eight combinations")
            c.Entry:SetBuiltinBarEnabled(false)
            Check(c.Entry:GetEntryChannels(id).builtinBar == bar, "bar off retains intent")
            c.Entry:SetBuiltinBarEnabled(true)
        end
    end
    c.Entry:UnregisterEntriesForPage("fixture")
    Check(not c.Entry:GetEntryAvailability("fixture"), "unregister removes entry availability")
    for _, language in ipairs({ "zh", "en" }) do
        c.Locale.previewLanguage = language
        for _, width in ipairs({ 800, 1920 }) do
            e.UIParent:SetSize(width, 1080)
            c.AccountView:ShowPage("settings"); flush()
            Check(c.AccountView.frame:GetWidth() <= width, "shared workbench within screen width")
        end
    end
    -- Native event registration may be absent; polling must still resolve or time out.
    e.C_Item.RequestLoadItemDataByID = function() end
    local oldCreate = e.CreateFrame
    e.CreateFrame = function(...) local f = oldCreate(...); f.RegisterEvent = function() error("unsupported event") end; return f end
    load("YiboCore/Runtime/ItemResolver.lua")
    local polled = 0
    c.ItemResolver:Request(20, function(value) polled = polled + 1; Check(value.state == "ready", "poll fallback ready") end)
    cached[20] = "Poll"
    local frame = e.TEST_FRAMES[#e.TEST_FRAMES]; frame.scripts.OnUpdate(frame, .2)
    Check(polled == 1 and frame.scripts.OnUpdate == nil, "event unavailable retains bounded poll")
end
print("CoreSurfaceR1 passed: " .. checks .. " checks (real Mists/Forever manifests; synthetic item/UI native APIs)")
