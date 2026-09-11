local _, NS = ...

local capturedMessage
NS.Probe.Print = function(message)
    capturedMessage = message
end

NS.InventoryProbe:PrintCapture()
if capturedMessage ~= "Mount Journal API is unavailable on this client." then
    error("inventory probe must report an unavailable Mount Journal API without raising an error")
end
