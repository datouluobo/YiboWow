if not _G.YAB.CoreReady then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Store, Targets, Editor, Progress = YAB.Store, YAB.CustomTargets, YAB.CustomTargetSettings, YAB.InstanceProgress
local Text = YAB.Text
local customID, instancesID = "alto-custom", "alto-lockouts"
local addonName = "YiboAltoBoss"
local icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon"

YAB.BusinessTabs = {
    { id = "custom", title = Text("UI.CUSTOM_TARGETS"), page = customID, width = 142 },
    { id = "lockouts", title = Text("UI.INSTANCES"), page = instancesID, width = 142 },
}

function YAB.GetAccountBusinessPageID()
    return Store.db.settings.accountPage == instancesID and instancesID or customID
end

function YAB.SetAccountBusinessPage(pageID)
    Store.db.settings.accountPage = pageID
end

function YAB.GetCharacterIdentity(id)
    return Core.Characters:Get(id, { identityOnly = true })
end

function YAB.FormatCharacterName(id, scope)
    local identity = YAB.GetCharacterIdentity(id)
    return Core.Characters:FormatName(identity, { nameMode = "short", realmMode = scope == "all" and "full" or "omit" })
end

function YAB.GetAccountCharacterKeys(context)
    local keys = {}
    for _, character in ipairs(context and context.characters or {}) do keys[#keys + 1] = character.id end
    return keys
end

local function CustomSettings(parent, context)
    local panel = parent.yabSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", 0, 0)
        panel:SetPoint("TOPRIGHT", 0, 0)
        parent.yabSettingsPanel = panel
        Editor.Create(panel, context, {
            hint = "FOREVER.NPC_HINT", empty = "FOREVER.CUSTOM_EMPTY",
            directory = function() return Store.db.customTargets end,
            add = function(input)
                local id = tonumber(input)
                if not id or id % 1 ~= 0 then return false, Text("UI.ENTER_A_VALID_NPC_ID") end
                local target, message = Targets:Add(Store.db.customTargets, id, nil, "manual")
                if not target then return false, message end
                Core.AccountView:NotifyPageChanged(customID)
                context.refreshPanel()
                return true
            end,
            remove = function(id)
                local ok, message = Store:RemoveTarget(id)
                if ok then
                    Core.AccountView:NotifyPageChanged(customID)
                    context.refreshPanel()
                end
                return ok, message
            end,
        })
    end
    local width = parent:GetWidth()
    panel.custom:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.custom:SetWidth(width)
    local height = Editor.Refresh(panel, context, Targets:List(Store.db.customTargets), width)
    panel.custom:SetHeight(height)
    panel:SetHeight(height + 12 + Editor.PlaceRemoval(panel, height + 12, width))
    panel:Show()
    return panel:GetHeight()
end

local custom = {
    id = customID, tab = "custom", title = function() return Text("UI.CUSTOM_TARGETS") end,
    empty = function(noTargets, context)
        if context and not context:GetFieldVisible("marks") then return Text("FOREVER.FIELD_HIDDEN") end
        return Text(noTargets and "FOREVER.ADD_TARGETS" or "FOREVER.NO_CHARACTERS")
    end,
    columns = function(context)
        if context and not context:GetFieldVisible("marks") then return {} end
        return Targets:List(Store.db.customTargets)
    end,
    status = function(id, target)
        if Store:Mark(id, target.key) then return "clear", Text("FOREVER.MANUAL_MARK") end
        return "unknown", Text("FOREVER.NOT_MARKED")
    end,
    tooltip = function(id, target, preview)
        local mark = Store:Mark(id, target.key)
        local lines = {
            { kind = "pair", label = target.name, value = tostring(target.id) },
            { kind = "text", text = mark and Text("FOREVER.MANUAL_AT", date("%Y-%m-%d %H:%M", mark.updatedAt))
                or Text("FOREVER.NOT_MARKED") },
        }
        if not preview and id == Core.Characters:GetCurrentID() then
            lines[#lines + 1] = { kind = "text", text = Text("FOREVER.TOGGLE_MARK") }
        end
        return lines
    end,
    canActivate = function(id) return id == Core.Characters:GetCurrentID() end,
    activate = function(id, target)
        if id == Core.Characters:GetCurrentID() and Store:ToggleMark(id, target) then
            Core.AccountView:NotifyPageChanged(customID)
        end
    end,
    snapshot = function(id) return Store.db.marks[id] ~= nil end,
}

local instances = {
    id = instancesID, tab = "lockouts", title = function() return Text("UI.INSTANCES") end,
    empty = function(noColumns, context)
        if context and not context:GetFieldVisible("lockout") then return Text("FOREVER.FIELD_HIDDEN") end
        return Text(noColumns and "FOREVER.NO_INSTANCE_DATA" or "FOREVER.NO_CHARACTERS")
    end,
    columns = function(context)
        if context and not context:GetFieldVisible("lockout") then return {} end
        local result = {}
        for _, instance in pairs(Store.db.instances) do result[#result + 1] = instance end
        table.sort(result, function(a, b)
            if a.name == b.name then return a.key < b.key end
            return a.name < b.name
        end)
        return result
    end,
    status = function(id, column)
        return Progress:Status(Store.db.instanceSnapshots[id], column, GetServerTime())
    end,
    tooltip = function(id, column)
        local snapshot = Store.db.instanceSnapshots[id]
        local now = GetServerTime()
        local _, label, active = Progress:Status(snapshot, column, now)
        local lines = { { kind = "pair", label = column.name, value = label } }
        if snapshot then lines[#lines + 1] = { kind = "text", text = Text("FOREVER.SNAPSHOT_AT", date("%Y-%m-%d %H:%M", snapshot.observedAt)) } end
        if active and active.resetAt then
            lines[#lines + 1] = { kind = "pair", label = Text("TP.RESET"), value = date("%Y-%m-%d %H:%M", active.resetAt) }
        end
        for _, boss in ipairs(active and active.bosses or {}) do
            local key = boss.killed == true and "TP.KILLED" or boss.killed == false and "TP.ALIVE" or "TP.UNKNOWN"
            lines[#lines + 1] = { kind = "pair", label = boss.name, value = Text(key) }
        end
        local history = snapshot and snapshot.history and snapshot.history[column.key]
        if history then
            for _, boss in ipairs(history.bosses or {}) do
                lines[#lines + 1] = { kind = "pair", label = boss.name, value = Text("TP.HISTORY", boss.kills) }
            end
        end
        return lines
    end,
    snapshot = function(id) return Store.db.instanceSnapshots[id] ~= nil end,
}

local function Register(view, field, label, scopedSettings)
    return Core.AccountView:RegisterPage(addonName, {
        id = view.id, title = view.title(), icon = icon, previewEnabled = true, defaultEnabled = true, columnPager = true,
        order = scopedSettings and 30 or 31, internal = not scopedSettings, hideFromSettings = not scopedSettings,
        fields = { { id = field, title = Text(label), defaultVisible = true } },
        scope = { mode = "realms" },
        HasCharacterSnapshot = function(character)
            return view.snapshot(character.id) or (scopedSettings and character.id == Core.Characters:GetCurrentID())
        end,
        GetEligibleCharacters = function(characters, context)
            local result = {}
            local currentID = scopedSettings and not context.preview and Core.Characters:GetCurrentID()
            for _, character in ipairs(characters) do
                if character.id == currentID or view.snapshot(character.id) then result[#result + 1] = character end
            end
            return result
        end,
        settings = scopedSettings and { title = Text("FOREVER.TITLE"), CreateSettingsPanel = CustomSettings } or nil,
        Create = function(parent) return YAB.CreateProgressPage(parent, view) end,
        Refresh = function(instance, context) YAB.RefreshProgressPage(instance, context, view) end,
        GetSurfaceMetrics = function(context) return YAB.GetProgressSurfaceMetrics(context, view) end,
        GetMeasuredHeight = function(instance, context) return YAB.GetProgressMeasuredHeight(instance, context, view) end,
        GetHoverMetrics = function(context) return YAB.GetProgressHoverMetrics(context, view) end,
    })
end

function YAB.RegisterForeverPages()
    local page, err = Register(custom, "marks", "FOREVER.MANUAL_MARK", true)
    if not page then return nil, err end
    page, err = Register(instances, "lockout", "UI.INSTANCE_LOCKOUTS", false)
    if not page then return nil, err end
    return Core.Entry:RegisterBusinessEntry(addonName, {
        id = "yab", brokerName = addonName, pageID = customID, resolvePageID = YAB.GetAccountBusinessPageID,
        text = "[Yibo] " .. Text("FOREVER.TITLE"), icon = icon,
    })
end
