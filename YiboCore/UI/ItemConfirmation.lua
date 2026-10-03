local Core = _G.YiboCore
local Confirmation = {}
Core.ItemConfirmation = Confirmation

StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true,
    hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(_, data)
        if not data or data.finished then return end
        data.finished = true
        if Confirmation.active == data then Confirmation.active = nil end
        if not data.IsCurrent or data.IsCurrent() then data.OnAccept() end
    end,
    OnCancel = function(_, data)
        if data and not data.finished then
            data.finished = true
            if Confirmation.active == data then Confirmation.active = nil end
            if data.OnCancel then data.OnCancel() end
        end
    end,
}

function Confirmation:Show(options)
    -- Only one item-operation confirmation is active, with independent request data.
    if self.active then self.active:Cancel() end
    local data = options
    function data:Cancel()
        if self.finished then return end
        self.finished = true
        if Confirmation.active == self then StaticPopup_Hide("YIBO_CORE_ITEM_CONFIRM"); Confirmation.active = nil end
        if self.OnCancel then self.OnCancel() end
    end
    self.active = data
    local popup = StaticPopup_Show("YIBO_CORE_ITEM_CONFIRM", options.text, nil, data)
    if not popup then data:Cancel(); return nil end
    return data
end
