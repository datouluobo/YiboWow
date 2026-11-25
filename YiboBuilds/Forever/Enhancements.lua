local Addon = _G.YiboBuilds
local Enhancements = {}
Addon.Enhancements = Enhancements

function Enhancements:Read(item)
    local link = item.itemLink
    if not Addon.Store:Plain(link) or type(link) ~= "string" then return nil end
    local payload = link:match("|Hitem:([^|]*)|h") or link:match("^item:([^|]*)$")
    if not payload then return nil end
    local itemID, enchant = (payload .. ":"):match("^(%d+):(%d*):")
    if item.itemID == 0 or tonumber(itemID) ~= item.itemID then return nil end
    local enchantID = enchant == "" and 0 or tonumber(enchant)
    if Addon.Store:Integer(enchantID, 0, 2147483647) then return enchantID end
end

function Enhancements:GetEnchantEffect(item, enchantID)
    if not enchantID or enchantID==0 then return nil end
    local lineTypes=Enum and Enum.TooltipDataLineType
    local enchantType=lineTypes and lineTypes.ItemEnchantmentPermanent
    local getTooltip=C_TooltipInfo and C_TooltipInfo.GetHyperlink
    if enchantType==nil or type(getTooltip)~="function" then return nil end
    local store=Addon.Store
    local ok,tooltip=pcall(getTooltip,item.itemLink)
    if not ok or not store:Plain(tooltip) or type(tooltip)~="table"
        or not store:Plain(tooltip.lines) or type(tooltip.lines)~="table" then return nil end
    local effect, matches=nil,0
    for _,line in ipairs(tooltip.lines) do
        if store:Plain(line) and type(line)=="table" and store:Plain(line.type) and line.type==enchantType then
            local id=line.enchantID
            if store:Plain(id) and id==nil then id=line.itemEnchantmentID end
            if store:Plain(id) and (id==nil or id==enchantID) then
                local text=line.leftText
                if not store:Plain(text) or type(text)~="string" or not text:find("%S") then text=line.rightText end
                if store:Plain(text) and type(text)=="string" and text:find("%S") then
                    if id==enchantID then return text end
                    effect,matches=text,matches+1
                end
            end
        end
    end
    if matches==1 then return effect end
end
