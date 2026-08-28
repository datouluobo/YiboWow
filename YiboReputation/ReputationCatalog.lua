local Addon = _G.YiboReputation
-- Display metadata only. IDs, values and standings always originate in Core.
Addon.Catalog = {
 { id="classic", title="经典旧世", categories={
  {id="cities",title="主城阵营",factions={47,54,68,69,72,76,81,530}},
  {id="steamwheedle",title="热砂港",factions={21,369,470,577}},
  {id="forces",title="战场阵营",factions={509,510,729,730,889,890}},
  {id="major",title="其它阵营",factions={59,70,87,92,93,270,349,471,529,576,589,609,749,809,909,910}},
 }},
 { id="tbc", title="燃烧的远征", categories={
  {id="cities",title="主城阵营",factions={911,922,930}},
  {id="shattrath",title="沙塔斯城",factions={932,934,935,1011,1031,1077}},
  {id="outland",title="外域阵营",factions={933,941,942,946,947,967,970,978,989,990,1012,1015,1038}},
 }},
 { id="wotlk", title="巫妖王之怒", categories={
  {id="alliance",title="联盟先遣军",factions={1037,1050,1068,1094,1126}},
  {id="horde",title="部落先遣军",factions={1052,1064,1067,1085,1124}},
  {id="basin",title="索拉查盆地",factions={1104,1105}},
  {id="major",title="诺森德阵营",factions={1073,1090,1091,1098,1106,1119,1156}},
 }},
 { id="cata", title="大地的裂变", categories={{id="major",title="主要阵营",flat=true,factions={1133,1134,1135,1158,1171,1172,1173,1174,1177,1178,1204}}}},
 { id="mop", title="熊猫人之谜", categories={
  {id="academy",title="熊猫人阵营",factions={1216,1228,1242,1352,1353}},
  {id="black-prince",title="黑王子",primaryFactionID=1359,factions={1359}},
  {id="tillers",title="阡陌客",primaryFactionID=1272,factions={1272,1273,1275,1276,1277,1278,1279,1280,1281,1282,1283}},
  {id="anglers",title="垂钓翁",primaryFactionID=1302,factions={1302,1358}},
  {id="major",title="主要阵营",factions={1269,1270,1271,1286,1337,1341,1345,1351,1375,1376,1387,1388,1419,1435,1440,1492}},
 }},
 { id="guild", title="公会", categories={{id="guilds",title="公会",flat=true,guild=true,factions={1168}}}},
}

-- These are native top-level/category headers observed on Interface 50504.
-- They are only used for factions not yet present in the canonical catalog.
Addon.NativeGroupExpansions = {
 ["经典旧世"]="classic", ["联盟"]="classic", ["部落"]="classic",
 ["联盟部队"]="classic", ["部落部队"]="classic", ["热砂港"]="classic",
 ["燃烧的远征"]="tbc", ["沙塔斯城"]="tbc",
 ["巫妖王之怒"]="wotlk", ["联盟先遣军"]="wotlk", ["部落先遣军"]="wotlk", ["索拉查盆地"]="wotlk",
 ["大地的裂变"]="cata",
 ["熊猫人之谜"]="mop", ["阡陌客"]="mop", ["垂钓翁"]="mop",
}
-- Register before PLAYER_LOGIN collection so collapsed Blizzard faction
-- headers cannot turn catalog entries into false “unscanned” states.
do
 local entries, seen = {}, {}
 for _, expansion in ipairs(Addon.Catalog) do
  for _, category in ipairs(expansion.categories) do
   for _, factionID in ipairs(category.factions) do
    if not seen[factionID] then seen[factionID] = true; entries[#entries + 1] = {factionID=factionID,expansionID=expansion.id,expansionTitle=expansion.title,categoryID=category.id,categoryTitle=category.title} end
   end
  end
 end
 if _G.YiboCore and _G.YiboCore.RegisterReputationFactions then _G.YiboCore:RegisterReputationFactions(entries)
 elseif _G.YiboCore and _G.YiboCore.RegisterReputationFactionIDs then local ids={};for _,entry in ipairs(entries) do ids[#ids+1]=entry.factionID end;_G.YiboCore:RegisterReputationFactionIDs(ids) end
end
function Addon:GetExpansion(id) for _, item in ipairs(self.Catalog) do if item.id == id then return item end end end
function Addon:GetCategory(expansionID, categoryID) for _, item in ipairs((self:GetExpansion(expansionID) or {}).categories or {}) do if item.id == categoryID then return item end end end
function Addon:GetFactionIDs(expansionID, categoryID)
 local ids, seen = {}, {}; for _, category in ipairs((self:GetExpansion(expansionID) or {}).categories or {}) do if categoryID == "all" or category.id == categoryID then for _, id in ipairs(category.factions) do if not seen[id] then seen[id]=true; ids[#ids+1]=id end end end end; return ids
end
function Addon:ResolveFactionMetadata(factionID, data)
 local metadata = _G.YiboCore and _G.YiboCore.GetReputationFactionMetadata and _G.YiboCore:GetReputationFactionMetadata(factionID)
 if metadata and metadata.expansionID then return metadata end
 local id, nativeGroup = tonumber(factionID) or 0, data and data.nativeGroup
 local expansionID = nativeGroup and self.NativeGroupExpansions[nativeGroup]
 local expansion = self:GetExpansion(expansionID)
 local categoryTitle = nativeGroup
 if expansion and nativeGroup == expansion.title then categoryTitle = "主要阵营" end
 return {factionID=id,expansionID=expansionID or "unclassified",expansionTitle=expansion and expansion.title or "未归类",categoryID="detected:"..tostring(nativeGroup or "other"),categoryTitle=categoryTitle or "其它阵营",inferred=true}
end
function Addon:GetFactionName(factionID, fallback)
 if type(fallback) == "string" and fallback ~= "" then return fallback end
 if C_Reputation and C_Reputation.GetFactionDataByID then
  local info = C_Reputation.GetFactionDataByID(factionID)
  if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
 end
 if GetFactionInfoByID then
  local name = GetFactionInfoByID(factionID)
  if type(name) == "string" and name ~= "" then return name end
 end
 return "未知声望 " .. tostring(factionID)
end
function Addon:GetFactionIcon(factionID)
 if C_Reputation and C_Reputation.GetFactionDataByID then
  local info = C_Reputation.GetFactionDataByID(factionID)
  if type(info) == "table" then return info.icon or info.texture or info.factionIcon end
 end
 return nil
end
