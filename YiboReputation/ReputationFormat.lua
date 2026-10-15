local Addon = _G.YiboReputation
-- Core v5 added cross-client friendship normalization.  A v4 snapshot has
-- no reliable way to distinguish a normal standing from a friendship rank,
-- so never render it as current reputation data.
local REPUTATION_SNAPSHOT_VERSION = 5
local STANDING_KEYS = { [1]="STANDING.1", [2]="STANDING.2", [3]="STANDING.3", [4]="STANDING.4", [5]="STANDING.5", [6]="STANDING.6", [7]="STANDING.7", [8]="STANDING.8" }
local function Standing(rank)
 local key = STANDING_KEYS[tonumber(rank)]
 return key and Addon:T(key) or nil
end
local STANDING_COLORS = { [1]={0.95,0.28,0.28},[2]={0.95,0.42,0.24},[3]={0.98,0.68,0.22},[4]={0.92,0.86,0.36},[5]={0.30,0.88,0.40},[6]={0.32,0.70,1.00},[7]={0.70,0.48,1.00},[8]={0.96,0.78,0.20} }
-- Friendship ranks are a six-step relationship ladder, not normal standing
-- IDs.  Their colors intentionally reuse normal reputation standings 3–8:
-- 陌生人→冷淡 through 挚友→崇拜.
local FRIENDSHIP_COLOR_STANDINGS = { [1]=3,[2]=4,[3]=5,[4]=6,[5]=7,[6]=8 }
-- Older clients can provide the localized relationship label and progress
-- while omitting the numeric rank. “同伴” is Nat Pagle's official rank-two
-- label and therefore shares 熟人的 color.
local FRIENDSHIP_NAME_COLOR_STANDINGS = { ["陌生人"]=3,["熟人"]=4,["同伴"]=4,["哥们"]=5,["朋友"]=6,["好友"]=7,["挚友"]=8 }
local function Progress(data)
 local value, min, max = tonumber(data and data.value), tonumber(data and data.min), tonumber(data and data.max)
 if not value or not min or not max or max <= min then return nil end
 return value - min, max - min, math.floor((value - min) * 100 / (max - min))
end
local function HasFriendProgress(friend)
 local current, min, max = tonumber(friend and friend.current), tonumber(friend and friend.min), tonumber(friend and friend.max)
 return current and min and max and max > min
end
function Addon:GetReputationColor(data)
 local friend = self:GetFriendship(data)
 if friend then
  local standing = FRIENDSHIP_COLOR_STANDINGS[tonumber(friend.rank)] or FRIENDSHIP_NAME_COLOR_STANDINGS[friend.name]
  return STANDING_COLORS[standing] or {0.90,0.96,0.97}
 end
 local current, maximum = Progress(data)
 if current and maximum and current >= maximum - 1 then return STANDING_COLORS[8] end
 local standing = tonumber(data and data.standingID)
 return STANDING_COLORS[standing] or {0.90,0.96,0.97}
end
function Addon:FormatState(snapshot)
 if not snapshot then return self:T("STATE.UNSYNCED") end
 if (tonumber(snapshot.schemaVersion) or 0) < REPUTATION_SNAPSHOT_VERSION or not (snapshot.data and snapshot.data.contractVersion) then return self:T("STATE.RESCAN") end
 if snapshot.state == "stale" then return self:T("STATE.STALE") end
 if snapshot.state == "unavailable" then return self:T("STATE.UNAVAILABLE") end
 if snapshot.state == "error" then return self:T("STATE.ERROR") end
 if snapshot.state == "not-yet-scanned" then return self:T("STATE.UNSYNCED") end
 return nil
end
function Addon:IsComplete(data)
 local friend = self:GetFriendship(data)
 if friend then return friend.rank and friend.maxRank and friend.rank >= friend.maxRank end
 local current, maximum = Progress(data)
 return current and maximum and current >= maximum - 1
end
function Addon:FormatReputation(data, options)
 if not data then return self:T("STATE.UNSYNCED") end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank and not HasFriendProgress(friend) then return self:T("STATE.FRIENDSHIP_UNREADY") end
  if friend.maxRank and friend.rank >= friend.maxRank then return self:T("FRIENDSHIP.FALLBACK_6") end
  if data.factionID == 1359 and self.GetNomiDisplay then return self:GetNomiDisplay(data) end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  local progress = current and min and max and max > min and self:T("FORMAT.PROGRESS", current-min, max-min, math.floor((current-min)*100/(max-min))) or self:T("STATE.FRIENDSHIP_UNREADY")
  return self:T("FORMAT.FRIENDSHIP_PROGRESS", friend.name, progress)
 end
 local value, min, max = tonumber(data.value), tonumber(data.min), tonumber(data.max)
 local label = Standing(tonumber(data.standingID)) or self:T("STATE.UNKNOWN")
 if not value or not min or not max or max <= min then return label end
 local current, maximum = value - min, max - min
 if current >= maximum - 1 then return Standing(8) end
 return self:T("FORMAT.REPUTATION_PROGRESS", label, current, maximum, math.floor(current*100/maximum))
end
function Addon:FormatCompact(data)
 if not data then return "?" end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank and not HasFriendProgress(friend) then return "?" end
  if friend.maxRank and friend.rank >= friend.maxRank then return self:T("FRIENDSHIP.FALLBACK_6") end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  if current and min and max and max > min and current - min >= max - min - 1 then return self:T("FRIENDSHIP.FALLBACK_6") end
  return current and min and max and max > min and tostring(current-min) or "?"
 end
 local current, maximum = Progress(data); local standing = tonumber(data.standingID)
 if current and maximum and current >= maximum - 1 then return Standing(8) end
 if current and maximum then return tostring(current) end
 return "?"
end
function Addon:FormatMatrix(data, showProgress)
 if not data then return self:T("STATE.UNSYNCED") end
 local friend = self:GetFriendship(data)
 if friend then
  if not friend.rank and not HasFriendProgress(friend) then return self:T("STATE.FRIENDSHIP_NOT_READY") end
  local current, min, max = tonumber(friend.current), tonumber(friend.min), tonumber(friend.max)
  if current and min and max and max > min and current - min >= max - min - 1 then return self:T("FRIENDSHIP.FALLBACK_6") end
  if showProgress and current and min and max and max > min then return self:T("FORMAT.COMPACT_PROGRESS", friend.name or self:T("FRIENDSHIP.FALLBACK_5"), current-min, max-min) end
  return friend.name or self:T("FRIENDSHIP.FALLBACK_5")
 end
 local value, min, max = tonumber(data.value), tonumber(data.min), tonumber(data.max)
 local label = Standing(tonumber(data.standingID)) or self:T("STATE.UNKNOWN")
 if showProgress and value and min and max and max > min then
  local current, maximum = value-min, max-min
  if current >= maximum - 1 then return Standing(8) end
  return string.format("%s %d/%d", label, current, maximum)
 end
 return label
end
function Addon:FormatDetails(data, snapshot)
 local state = self:FormatState(snapshot)
 if state then return state end
 if not data then return self:T("STATE.NOT_APPLICABLE") end
 return self:FormatReputation(data)
end
function Addon:FormatSnapshotValue(snapshot, data, style, factionState)
 local state = self:FormatState(snapshot)
 if state and snapshot and snapshot.state ~= "stale" then
  return snapshot.state == "unavailable" and "—" or self:T("STATE.NEEDS_LOGIN")
 end
 if not data then
  if factionState == "not-yet-scanned" then return self:T("STATE.NEEDS_LOGIN") end
  if factionState == "unavailable" then return "—" end
  return "—"
 end
 return style == "compact" and self:FormatCompact(data) or self:FormatMatrix(data, true)
end
