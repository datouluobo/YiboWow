local Addon = _G.YiboReputation
-- Reputation owns the catalog and discovered faction metadata; Core owns character identity.
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
  -- The expansion header already identifies this group.  Keep these as
  -- direct rows so “熊猫人之谜 → 熊猫人阵营” does not create a redundant
  -- second hierarchy level in the account matrix.
  {id="academy",title="熊猫人阵营",flat=true,factions={1216,1228,1242,1352,1353}},
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

-- A character can query a faction name only when the client exposes that
-- faction to its current faction list. Keep localized catalog labels for
-- known cross-faction entries so monitoring/settings remain readable even
-- when the logged-in character cannot resolve the faction through the API.
Addon.FactionNameFallbacks = {
 [1134] = "FACTION.WILDHAMMER",
 [1353] = "FACTION.HUOJIN",
}
-- Build local collection metadata before the first scan. Imported faction IDs
-- also remain queryable when they are absent from the current native list.
function Addon:InitializeFactionRegistry()
 self.FactionRegistry = self.FactionRegistry or {}
 for _, expansion in ipairs(self.Catalog) do
  for _, category in ipairs(expansion.categories) do
   for _, id in ipairs(category.factions) do
    self.FactionRegistry[id] = self.FactionRegistry[id] or {
     factionID=id, expansionID=expansion.id, categoryID=category.id,
     isPrimaryFaction=category.primaryFactionID == id,
    }
   end
  end
 end
 for _, record in pairs(self.Store.db.characters) do
  local snapshot=record.snapshot
  if snapshot and (tonumber(snapshot.schemaVersion) or 0)>=3 then
   for key, data in pairs(snapshot.data and snapshot.data.factions or {}) do
    local id=tonumber(type(data)=="table" and data.factionID or key)
    if id and id>0 then self.FactionRegistry[id]=self.FactionRegistry[id] or {factionID=id,discovered=true} end
   end
  end
 end
end
function Addon:GetExpansion(id) for _, item in ipairs(self.Catalog) do if item.id == id then return item end end end
function Addon:GetCategory(expansionID, categoryID) for _, item in ipairs((self:GetExpansion(expansionID) or {}).categories or {}) do if item.id == categoryID then return item end end end
local EXPANSION_KEYS = { classic="CAT.EXPANSION.CLASSIC", tbc="CAT.EXPANSION.TBC", wotlk="CAT.EXPANSION.WOTLK", cata="CAT.EXPANSION.CATA", mop="CAT.EXPANSION.MOP", guild="CAT.EXPANSION.GUILD" }
local CATEGORY_KEYS = {
 ["classic:cities"]="CAT.GROUP.CITIES", ["tbc:cities"]="CAT.GROUP.CITIES", ["classic:steamwheedle"]="CAT.GROUP.STEAMWHEEDLE",
 ["classic:forces"]="CAT.GROUP.FORCES", ["classic:major"]="CAT.GROUP.CLASSIC_MAJOR", ["tbc:shattrath"]="CAT.GROUP.SHATTRATH",
 ["tbc:outland"]="CAT.GROUP.OUTLAND", ["wotlk:alliance"]="CAT.GROUP.ALLIANCE", ["wotlk:horde"]="CAT.GROUP.HORDE",
 ["wotlk:basin"]="CAT.GROUP.BASIN", ["wotlk:major"]="CAT.GROUP.NORTHREND", ["cata:major"]="CAT.GROUP.MAJOR",
 ["mop:academy"]="CAT.GROUP.PANDARIA", ["mop:black-prince"]="CAT.GROUP.BLACK_PRINCE", ["mop:tillers"]="CAT.GROUP.TILLERS",
 ["mop:anglers"]="CAT.GROUP.ANGLERS", ["mop:major"]="CAT.GROUP.MAJOR", ["guild:guilds"]="CAT.GROUP.GUILD",
}
function Addon:GetExpansionTitle(expansion)
 return self:T(EXPANSION_KEYS[type(expansion)=="table" and expansion.id or expansion] or "CAT.GROUP.UNCLASSIFIED")
end
function Addon:GetCategoryTitle(expansion, category)
 local expansionID = type(expansion)=="table" and expansion.id or expansion
 local categoryID = type(category)=="table" and category.id or category
 local key = CATEGORY_KEYS[tostring(expansionID)..":"..tostring(categoryID)]
 return key and self:T(key) or (type(category)=="table" and category.title or self:T("MATRIX.OTHER_FACTIONS"))
end
function Addon:GetFactionIDs(expansionID, categoryID)
 local ids, seen = {}, {}; for _, category in ipairs((self:GetExpansion(expansionID) or {}).categories or {}) do if categoryID == "all" or category.id == categoryID then for _, id in ipairs(category.factions) do if not seen[id] then seen[id]=true; ids[#ids+1]=id end end end end; return ids
end
function Addon:ResolveFactionMetadata(factionID, data)
 local original = self.FactionRegistry and self.FactionRegistry[tonumber(factionID)]
 local metadata = original and self.Store.Copy(original)
 if metadata and metadata.expansionID then
  local expansion = self:GetExpansion(metadata.expansionID)
  local category = self:GetCategory(metadata.expansionID, metadata.categoryID)
  if expansion then metadata.expansionTitle = self:GetExpansionTitle(expansion) end
  if category then metadata.categoryTitle = self:GetCategoryTitle(expansion, category) end
  return metadata
 end
 local id, nativeGroup = tonumber(factionID) or 0, data and data.nativeGroup
 local expansionID = nativeGroup and self.NativeGroupExpansions[nativeGroup]
 local expansion = self:GetExpansion(expansionID)
 local categoryTitle = nativeGroup
 if expansion and nativeGroup == ({classic="经典旧世",tbc="燃烧的远征",wotlk="巫妖王之怒",cata="大地的裂变",mop="熊猫人之谜"})[expansion.id] then categoryTitle = self:T("CAT.GROUP.MAJOR") end
 return {factionID=id,expansionID=expansionID or "unclassified",expansionTitle=expansion and self:GetExpansionTitle(expansion) or self:T("CAT.GROUP.UNCLASSIFIED"),categoryID="detected:"..tostring(nativeGroup or "other"),categoryTitle=categoryTitle or self:T("MATRIX.OTHER_FACTIONS"),inferred=true}
end
function Addon:GetFactionName(factionID, fallback)
 if type(fallback) == "string" and fallback ~= "" then return fallback end
 if C_Reputation and C_Reputation.GetFactionDataByID then
  local info = C_Reputation.GetFactionDataByID(factionID)
  if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
 end
 if GetFactionInfoByID then
  -- Some client builds expose the legacy-named lookup as a structured
  -- result, while older builds return the name as the first tuple value.
  local result = GetFactionInfoByID(factionID)
  local name = type(result) == "table" and result.name or result
  if type(name) == "string" and name ~= "" then return name end
 end
 local key = self.FactionNameFallbacks[tonumber(factionID)]
 if key then return self:T(key) end
 return self:T("MATRIX.UNKNOWN_REPUTATION", tonumber(factionID) or 0)
end
function Addon:IsUnknownFactionName(name)
 local prefix = self:T("MATRIX.UNKNOWN_REPUTATION", 0):gsub("0$", "")
 return type(name) == "string" and name:sub(1, #prefix) == prefix
end
function Addon:GetFactionIcon(factionID)
 if C_Reputation and C_Reputation.GetFactionDataByID then
  local info = C_Reputation.GetFactionDataByID(factionID)
  if type(info) == "table" then return info.icon or info.texture or info.factionIcon end
 end
 return nil
end
