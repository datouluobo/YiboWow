local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- These rules are deliberately scoped to the low-fidelity observation
-- feature. They record a witnessed action, never a crop or plot state.
Catalog.farmOperations["mop.farm.operation-observed"] = {
    id = "mop.farm.operation-observed",
    label = "农场操作",
    provider = "farm-operation-observation",
    scope = "character",
    defaultMode = "display",
    mapID = 376,
    resetHour = 7,
    rules = {
        [111003] = { kind = "till", label = "开垦土地", verificationStatus = "user-observed" },
        [129757] = { kind = "harvest", label = "收获", verificationStatus = "user-observed" },
        [129814] = { kind = "harvest", label = "收割风暴仙人掌", verificationStatus = "user-observed" },
        -- These are the spell IDs emitted by UNIT_SPELLCAST_SUCCEEDED when
        -- the corresponding farm items are used.  The item IDs are different
        -- and must not be placed in this spell catalog.
        [111108] = { kind = "operate", label = "使用生锈的洒水壶", verificationStatus = "user-observed" },
        [115481] = { kind = "operate", label = "使用优质杀虫剂", verificationStatus = "user-observed" },
        -- Some farm objects report the generic activation spell directly.
        [6478] = { kind = "operate", label = "开启农场设施", verificationStatus = "user-observed" },
        [139977] = { kind = "plant", plantType = "bundle", label = "播种一袋毒蛇茎种子", verificationStatus = "user-observed" },
        [139981] = { kind = "plant", plantType = "bundle", label = "抛撒魔法鳞茎种子", verificationStatus = "user-observed" },
        [139983] = { kind = "plant", plantType = "bundle", label = "抛撒风剪仙人掌种子", verificationStatus = "user-observed" },
        [139975] = { kind = "plant", plantType = "bundle", label = "抛撒欢歌铃种子", verificationStatus = "user-observed" },
        [139978] = { kind = "plant", plantType = "bundle", label = "抛撒谜之种子", verificationStatus = "user-observed" },
        [131095] = { kind = "plant", plantType = "bundle", label = "抛撒菜瓜种子", verificationStatus = "user-observed" },
        [139986] = { kind = "plant", plantType = "bundle", label = "抛撒食肉草种子", verificationStatus = "user-observed" },
        [131093] = { kind = "plant", plantType = "bundle", label = "抛撒女巫浆果种子", verificationStatus = "user-observed" },
        [131094] = { kind = "plant", plantType = "bundle", label = "抛撒碧玉瓜种子", verificationStatus = "user-observed" },
        [123567] = { kind = "plant", plantType = "bundle", label = "抛撒白色芜菁种子", verificationStatus = "user-observed" },
        [123566] = { kind = "plant", plantType = "bundle", label = "抛撒粉色芜菁种子", verificationStatus = "user-observed" },
        [123486] = { kind = "plant", plantType = "bundle", label = "抛撒魔古南瓜种子", verificationStatus = "user-observed" },
        [123537] = { kind = "plant", plantType = "bundle", label = "抛撒红韭花种子", verificationStatus = "user-observed" },
        [123362] = { kind = "plant", plantType = "bundle", label = "抛撒爽脆胡萝卜种子", verificationStatus = "user-observed" },
        [116356] = { kind = "plant", plantType = "bundle", label = "抛撒绿色卷心菜种子", verificationStatus = "user-observed" },
        [111102] = { kind = "plant", plantType = "single", label = "种植绿色卷心白菜", verificationStatus = "user-observed" },
        [123388] = { kind = "plant", plantType = "single", label = "播种小葱", verificationStatus = "user-observed" },
        [123389] = { kind = "plant", plantType = "bundle", label = "抛撒小葱种子", verificationStatus = "user-observed" },
        [123485] = { kind = "plant", plantType = "single", label = "播种魔古南瓜", verificationStatus = "user-observed" },
        [123568] = { kind = "plant", plantType = "single", label = "播种白色芜菁", verificationStatus = "user-observed" },
        [129974] = { kind = "plant", plantType = "single", label = "种植女巫浆果", verificationStatus = "user-observed" },
        [123361] = { kind = "plant", plantType = "single", label = "播种爽脆胡萝卜种子", verificationStatus = "user-observed" },
        [123535] = { kind = "plant", plantType = "single", label = "播种红韭花种子", verificationStatus = "user-observed" },
        [123565] = { kind = "plant", plantType = "single", label = "播种粉色芜菁种子", verificationStatus = "user-observed" },
        [123773] = { kind = "plant", plantType = "single", label = "种植毒蛇茎种子", verificationStatus = "user-observed" },
        [123774] = { kind = "plant", plantType = "single", label = "种植谜之种子", verificationStatus = "user-observed" },
        [123775] = { kind = "plant", plantType = "single", label = "种植魔法鳞茎种子", verificationStatus = "user-observed" },
        [129623] = { kind = "plant", plantType = "single", label = "种植风剪仙人掌种子", verificationStatus = "user-observed" },
        [129628] = { kind = "plant", plantType = "single", label = "种植食肉草种子", verificationStatus = "user-observed" },
        [129863] = { kind = "plant", plantType = "single", label = "种植欢歌铃种子", verificationStatus = "user-observed" },
        [129978] = { kind = "plant", plantType = "single", label = "种植菜瓜种子", verificationStatus = "user-observed" },
        [129976] = { kind = "plant", plantType = "single", label = "种植碧玉瓜", verificationStatus = "user-observed" },
        [133036] = { kind = "plant", plantType = "single", label = "种植不稳定的传送门碎片", verificationStatus = "user-observed" },
        -- Planting is split into three business types.  The exact spell table
        -- can grow as live probe captures confirm more seed items.
        [129883] = { kind = "plant", plantType = "single", label = "播种风暴仙人掌种子", verificationStatus = "user-observed" },
    },
    plantTypes = {
        single = "单个种子",
        bundle = "直接购买的种子包（4 块地）",
        -- Directly purchased and 30-seed exchange packages are normalized
        -- into one bundle type because both complete the same farm operation.
    },
}
