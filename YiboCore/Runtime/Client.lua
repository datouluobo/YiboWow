local Core = _G.YiboCore
local Client = {}
Core.Client = Client

-- Internal boundary, not a business Service or a new public capability.
function Client:Configure(targetID, reader)
    local target = Core._private.target
    assert(target and target.id == targetID, "client-adapter-target-mismatch")
    if self.reader then return self.targetID == targetID end
    self.reader, self.targetID = reader, targetID
    return true
end

function Client:ConfigureSurface(targetID, surface)
    assert(Core._private.target.id == targetID, "client-surface-target-mismatch")
    if self.surface then return self.surfaceTarget == targetID end
    self.surface, self.surfaceTarget = surface, targetID
    return true
end

for _, name in ipairs({ "ReadItemInfo", "RequestItemData", "ReadBagItemIDs", "ReadCursorItem", "ClearItemCursor",
    "ReadMouseFocus", "ReadCursorPosition", "ReadAddon", "ReadBuiltinIcons", "IsInCombat", "ShowPopup", "HidePopup",
    "RegisterCombatDriver", "BindItemEvents" }) do
    local method = name
    Client[method] = function(self, ...)
        if not self.surface then return nil, "unavailable" end
        return self.surface[method](...)
    end
end

for _, name in ipairs({ "ReadGUID", "ReadNameRealm", "ReadCharacter", "ReadIdentity", "ReadLocation" }) do
    local method = name
    Client[method] = function(self, ...)
        if not self.reader then return nil, "unavailable" end
        return self.reader[method](...)
    end
end
