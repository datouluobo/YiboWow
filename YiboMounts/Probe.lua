local _, NS = ...

NS.Probe = { enabled = false }

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] Mounts:|r " .. message)
    end
end

NS.Probe.Print = Print

function NS.Probe:Report(source, unit, spellID, matched)
    if not self.enabled then return end
    Print("source=" .. tostring(source) .. ", unit=" .. tostring(unit) .. ", spellID=" .. tostring(spellID) .. ", catalog=" .. (matched and "hit" or "miss"))
end

function NS.Probe:Initialize()
    if self.initialized then return end
    self.initialized = true

    SLASH_YIBOMOUNTS1 = "/ymt"
    SlashCmdList.YIBOMOUNTS = function(message)
        local command = (message or ""):lower():match("^%s*(%S+)") or ""
        if command == "debug" then
            self.enabled = not self.enabled
            Print("debug " .. (self.enabled and "enabled" or "disabled"))
        elseif command == "probe" then
            local tooltipName, unit = GameTooltip:GetUnit()
            local _, _, spellID = GameTooltip:GetSpell()
            local record = NS.Catalog:GetBySpellID(spellID)
            local exists = unit and UnitExists and UnitExists(unit)
            local mouseoverName = UnitName and UnitName("mouseover")
            local mouseoverGUID = UnitGUID and UnitGUID("mouseover")
            Print("tooltip unit=" .. tostring(unit) .. " (" .. tostring(tooltipName) .. "), exists=" .. tostring(exists)
                .. "; spellID=" .. tostring(spellID) .. ", catalog=" .. (record and "hit" or "miss"))
            Print("mouseover name=" .. tostring(mouseoverName) .. ", GUID=" .. tostring(mouseoverGUID))

            if not exists then
                Print("tooltip unit has no readable aura token; no target fallback was used")
                return
            end
            if not NS.Tooltip or not NS.Tooltip.FindMountAuras then
                Print("mount-aura scanner is unavailable")
                return
            end
            local matches, auraCount = NS.Tooltip:FindMountAuras(unit)
            Print("tooltip buffs scanned=" .. tostring(auraCount) .. ", mount aura hits=" .. tostring(#matches))
            for _, match in ipairs(matches) do
                local name = match.record.identity and NS:GetLocalizedText(match.record.identity.names)
                Print("mount aura spellID=" .. tostring(match.spellID) .. ", mount=" .. tostring(name))
            end
        elseif command == "inventory" then
            Print("inventory command received")
            if not NS.InventoryProbe then
                Print("inventory module is unavailable")
                return
            end
        elseif command == "sources" then
            if not NS.SourceFactProbe then
                Print("source fact probe is unavailable")
                return
            end
            local names = NS.SourceFactProbe:Capture()
            local count = 0
            for _ in pairs(names or {}) do count = count + 1 end
            Print("source names saved for " .. tostring(count) .. " mount facts")
            local ok, errorMessage = pcall(NS.InventoryProbe.PrintCapture, NS.InventoryProbe)
            if not ok then
                Print("inventory failed: " .. tostring(errorMessage))
            end
        else
            Print("/ymt debug — toggle Aura tooltip diagnostics")
            Print("/ymt probe — inspect the hovered tooltip unit and its mount auras")
            Print("/ymt inventory — save the client mount spellID inventory for catalog import")
            Print("/ymt sources — save client-resolved NPC names for source conversion")
        end
    end
end
