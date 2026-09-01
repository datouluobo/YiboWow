local Addon = _G.YiboReputation
local STANDING = { [1]="仇恨",[2]="敌对",[3]="冷淡",[4]="中立",[5]="友善",[6]="尊敬",[7]="崇敬",[8]="崇拜" }
local STANDING_COLORS = { [1]={0.95,0.28,0.28},[2]={0.95,0.42,0.24},[3]={0.98,0.68,0.22},[4]={0.92,0.86,0.36},[5]={0.30,0.88,0.40},[6]={0.32,0.70,1.00},[7]={0.70,0.48,1.00},[8]={0.96,0.78,0.20} }
local function SystemStandingColor(standing, fallback)
 local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
 if color then return { color.r or color[1], color.g or color[2], color.b or color[3] } end
 return fallback
end
local function Progress(data)
 local value, min, max = tonumber(data and data.value), tonumber(data and data.min), tonumber(data and data.max)
 if not value or not min or not max or max <= min then return nil end
 return value - min, max - min, math.floor((value - min) * 100 / (max - min))
end
function Addon:GetReputationColor(data)
 local friend = self:GetFriendship(data)
 if friend then return SystemStandingColor(8, {0.00,0.82,0.20}) end
 local current, maximum = Progress(data)
 if current and maximum and current >= maximum - 1 then return STANDING_COLORS[8] end
 local standing = tonumber(data and data.standingID)
 return SystemStandingColor(standing, STANDING_COLORS[standing] or {0.90,0.96,0.97})
end
function Addon:FormatState(snapshot)
 if not snapshot then return "? 未同步" end
 if (tonumber(snapshot.schemaVersion) or 0) < 4 or not (snapshot.data and snapshot.data.contractVersion) then return "? 需重扫" end
 if snapshot.state == "stale" then return "⌚ 过期" end
 if snapshot.state == "unavailable" then return "不可用" end
 if snapshot.state == "not-yet-scanned" then return "? 未同步" end
 return nil
end
function Addon:IsComplete(data)
 local friend = self:GetFriendship(data)
 if friend then return friend.rank and friend.maxRank and friend.rank >= friend.maxRank end
 local current, maximum = Progress(data)
 return current and maximum and current >= maximum - 1
end
function Addon:FormatReputation(data, options)
 if not data then return "? 未同步" end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank then return "好友度数据未就绪" end
  if friend.maxRank and friend.rank >= friend.maxRank then return "挚友" end
  if data.factionID == 1359 and self.GetNomiDisplay then return self:GetNomiDisplay(data) end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  local progress = current and min and max and max > min and string.format("%d / %d（%d%%）", current-min, max-min, math.floor((current-min)*100/(max-min))) or "好友度数据未就绪"
  return friend.name .. "  " .. progress
 end
 local value, min, max = tonumber(data.value), tonumber(data.min), tonumber(data.max)
 local label = STANDING[tonumber(data.standingID)] or "未知"
 if not value or not min or not max or max <= min then return label end
 local current, maximum = value - min, max - min
 if current >= maximum - 1 then return "崇拜" end
 return string.format("%s  %d / %d（%d%%）", label, current, maximum, math.floor(current*100/maximum))
end
function Addon:FormatCompact(data)
 if not data then return "?" end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank then return "?" end
  if friend.maxRank and friend.rank >= friend.maxRank then return "挚友" end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  if current and min and max and max > min and current - min >= max - min - 1 then return "挚友" end
  return current and min and max and max > min and tostring(current-min) or "?"
 end
 local current, maximum = Progress(data); local standing = tonumber(data.standingID)
 if current and maximum and current >= maximum - 1 then return "崇拜" end
 if current and maximum then return tostring(current) end
 return "?"
end
function Addon:FormatMatrix(data, showProgress)
 if not data then return "? 未同步" end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank then return "好友度未就绪" end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  if current and min and max and max > min and current - min >= max - min - 1 then return "挚友" end
  if showProgress and current and min and max and max > min then return string.format("%s %d/%d", friend.name or "好友", current-min, max-min) end
  return friend.name or "好友"
 end
 local value, min, max = tonumber(data.value), tonumber(data.min), tonumber(data.max)
 local label = STANDING[tonumber(data.standingID)] or "未知"
 if showProgress and value and min and max and max > min then
  local current, maximum = value-min, max-min
  if current >= maximum - 1 then return "崇拜" end
  return string.format("%s %d/%d", label, current, maximum)
 end
 return label
end
function Addon:FormatDetails(data, snapshot)
 local state = self:FormatState(snapshot)
 if state then return state end
 if not data then return "— 不适用" end
 return self:FormatReputation(data)
end
function Addon:FormatSnapshotValue(snapshot, data, style, factionState)
 local state = self:FormatState(snapshot)
 if state and snapshot and snapshot.state ~= "stale" then
  return snapshot.state == "unavailable" and "—" or "未同步"
 end
 if not data then
  if factionState == "not-yet-scanned" then return "未同步" end
  if factionState == "unavailable" then return "—" end
  return "—"
 end
 return style == "compact" and self:FormatCompact(data) or self:FormatMatrix(data, true)
end
