local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, target in ipairs({ "Forever", "Mists" }) do
    local inventory = { { id = 7001, quantity = 3 }, { id = 7001, quantity = 4 } }
    local reagent = { { id = 7001, quantity = 5 } }
    local attached, cursor, control, hookCount = {}, nil, true, 0
    local e, _, mail, fire, flush, box = Boot(nil, function(e)
        e.Enum = e.Enum or {}; e.Enum.BagIndex = { ReagentBag = 5 }
        local methods = getmetatable(e.UIParent).__index
        methods.GetRegions = function() return end
        methods.SetParent = function(self, parent) self.parent = parent end
        e.MailFrame = e.CreateFrame("Frame", nil, e.UIParent); e.MailFrame:Hide()
        e.InboxFrame = e.CreateFrame("Frame", nil, e.MailFrame)
        e.SendMailFrame = e.CreateFrame("Frame", nil, e.MailFrame); e.SendMailFrame:Hide()
        for _, name in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailBodyEditBox",
            "SendMailCancelButton", "SendMailMailButton", "SendMailMoney", "SendMailCODButton" }) do
            e[name] = e.CreateFrame("Button", nil, e.SendMailFrame)
        end
        e.SendMailMailButton:SetScript("OnClick", function() error("quick attachment must not send") end)
        e.GetMoney = function() return 10000 end
        e.MoneyInputFrame_GetCopper = function() return 0 end
        e.IsControlKeyDown = function() return control end
        e.CursorHasItem = function() return cursor ~= nil end
        e.GetInboxText = function() return "" end
        e.CheckInbox = function() end
        e.HandleModifiedItemClick = function() return false end
        e.ContainerFrameItemButton_OnModifiedClick = function() end
        e.hooksecurefunc = function(name, callback)
            if name == "HandleModifiedItemClick" or name == "ContainerFrameItemButton_OnModifiedClick" then
                hookCount = hookCount + 1
            end
            local original = e[name]
            e[name] = function(...) local result = original(...); callback(...); return result end
        end
        e.C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or (bag == 5 and 1 or 0) end
        e.C_Container.GetContainerItemInfo = function(bag, slot)
            local item = (bag == 5 and reagent or inventory)[slot]
            if item then return { itemID = item.id, stackCount = item.quantity, hyperlink = "item:" .. item.id } end
        end
        e.C_Container.PickupContainerItem = function(bag, slot) cursor = { bag = bag, slot = slot } end
        e.ClickSendMailItemButton = function(slot)
            local source = cursor.bag == 5 and reagent or inventory
            attached[slot] = source[cursor.slot]; source[cursor.slot] = nil; cursor = nil
        end
        e.GetSendMailItem = function(slot)
            local item = attached[slot]
            if item then return "Item", item.id, 123, item.quantity end
        end
        e.GetSendMailItemLink = function(slot) if attached[slot] then return "item:" .. attached[slot].id end end
    end, target == "Forever")
    fire("PLAYER_ENTERING_WORLD"); box.open = true; e.MailFrame:Show(); fire("MAIL_SHOW"); flush()
    assert(mail.NativeUI.installed and hookCount == 1)
    local location = { IsBagAndSlot = function() return true end, GetBagAndSlot = function() return 0, 1 end }
    local button = { GetParent = function() return { GetID = function() return 0 end } end,
        GetID = function() return 1 end }
    local function Click()
        if target == "Forever" then assert(e.HandleModifiedItemClick("item:7001", location) == false)
        else e.ContainerFrameItemButton_OnModifiedClick(button) end
    end
    Click(); assert(#attached == 0, "hidden send page cannot attach")
    e.SendMailFrame:Show(); control = false; Click(); assert(#attached == 0)
    control = true; cursor = "held"; Click(); assert(#attached == 0); cursor = nil
    if target == "Forever" then
        e.HandleModifiedItemClick("item:7001", { IsBagAndSlot = function() return false end })
        e.HandleModifiedItemClick("item:7001", nil)
        assert(#attached == 0, "equipment and chat links are not bag clicks")
    end
    mail.Compose:InstallBagItemClicks(function() error("duplicate hook") end)
    assert(hookCount == 1)
    Click()
    assert(#attached == (target == "Forever" and 3 or 2) and attached[1].quantity + attached[2].quantity == 7 and not cursor,
        "one Ctrl click attaches matching stacks through the real Compose implementation")
    assert(target == "Forever" and attached[3].quantity == 5 or target == "Mists" and reagent[1].quantity == 5,
        "only Forever includes the explicitly reported reagent bag")
    Click(); assert(#attached == (target == "Forever" and 3 or 2), "repeat click cannot duplicate attachments")
end
print("PASS: actual Forever/Mists manifests, native quick-attach hooks, Ctrl/page/cursor gates, target reagent bag, no sends and single registration")
