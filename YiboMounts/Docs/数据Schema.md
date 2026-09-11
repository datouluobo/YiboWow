# YiboMounts 数据 Schema

本文定义 YiboMounts 的规范化源数据、非发布核验证据和运行时生成物。产品边界见 [`../PRODUCT.md`](../PRODUCT.md)。

## 1. 设计目标

数据模型必须同时支持：

- V1 按 Aura `spellID` 常数时间查询；
- 同一坐骑对应多个 Aura、法术、物品或收藏目录 ID；
- `enUS` 与 `zhCN` 本地化及逐字段英文回退；
- 一条主要来源和若干备选/历史来源；
- 当前可获取、限时、轮换、已绝版和未知状态；
- V2/V3 目录页面读取图标、名称、完整来源与收藏标识；
- 生成前的重复 ID、缺失字段、非法枚举与本地化完整性校验。

源数据不得直接保存最终 Tooltip 整句。来源路径和条件行必须由语义字段生成，以便统一格式化和本地化。

## 2. 文件拓扑

```text
YiboMounts/
├─ Data/
│  └─ MountCatalog.generated.lua       # 发布运行时生成物
└─ _NonRelease/
   ├─ Data/
   │  ├─ mounts.schema.json            # 机器可读 JSON Schema
   │  ├─ mounts.json                   # 规范化源数据
   │  ├─ mount-source-catalog.md       # 可手工编辑的双向维护表
   │  ├─ mount-inventory.json          # 目标客户端导出的完整 spellID 基线（非发布）
   │  ├─ coverage-report.json          # 基线与正式目录之间的生成覆盖报告（非发布）
   │  ├─ att-mop-category-reference.json # ATT 转换的来源大类研究队列（非发布）
   │  ├─ source-fact-extract.json       # 本机资料提取的纯数字游戏事实（非发布）
   │  └─ source-evidence.csv           # 来源证据与核验状态
   └─ Tools/
      └─ generate_mount_catalog.py     # 校验并生成 Lua
```

`mounts.json` 是唯一人工维护的正式目录源。`MountCatalog.generated.lua` 不允许手工编辑。`source-evidence.csv` 只保存研究证据，不进入发布包。

`mount-source-catalog.md` 是给维护者直接编辑的同步视图：每行对应一个目标客户端 `spellID`，可填写来源类型、来源路径、状态、可用性和备注。它与 `mounts.json` 通过下列命令双向同步：

```powershell
# 将当前 YMS 数据导出为全量人工维护表
python _NonRelease/Tools/sync_mount_catalog_md.py export --catalog _NonRelease/Data/mounts.json --inventory _NonRelease/Data/mount-inventory.json --document _NonRelease/Data/mount-source-catalog.md

# 导入人工编辑，生成游戏目录后再 export 一次以规范化表格
python _NonRelease/Tools/sync_mount_catalog_md.py import --catalog _NonRelease/Data/mounts.json --inventory _NonRelease/Data/mount-inventory.json --document _NonRelease/Data/mount-source-catalog.md
python _NonRelease/Tools/generate_mount_catalog.py --input _NonRelease/Data/mounts.json --output Data/MountCatalog.generated.lua --channel alpha
```

维护目录优先于自动整理结果。每次准备写入该 Markdown 前，必须先运行 `check`：

```powershell
python _NonRelease/Tools/sync_mount_catalog_md.py check --catalog _NonRelease/Data/mounts.json --inventory _NonRelease/Data/mount-inventory.json --document _NonRelease/Data/mount-source-catalog.md
```

若结果为 `modified` 或 `untracked`，不得执行 `export` 覆盖文件；先核对手工内容与新资料，无法判定时询问维护者。确认手工内容后，先运行 `import`，再生成运行时目录并执行 `export`。同步状态文件只用于检测未导入编辑，不是可编辑的来源数据。

联盟与部落规则：同一来源体系但不同 `spellID` 时必须建立两条独立记录，分别保存阵营、声望、地点、NPC 与价格；Tooltip 默认显示当前角色阵营对应的记录。若同一 `spellID` 存在联盟/部落两套购买路径，目录须保存两个带阵营条件的来源，运行时按被观察单位的阵营选择；在未来接入 YiboCore 后，设置提供“当前角色阵营”与“双阵营”两种显示模式。

`mount-inventory.json` 是覆盖率基线与非发布事实快照，不是运行时来源数据。它由目标客户端导出，记录坐骑名称、Aura spellID、收藏目录 ID、图标，以及客户端坐骑日志提供的 `sourceText` 来源字段。原始 API spellID 集合是唯一的 V1 覆盖基线；角色的可见、可用、收藏、职业、种族或阵营标记只用于诊断，绝不用于从全量目录中排除记录。生成流程必须报告：原始基线总数、已覆盖数、缺失 spellID，以及目录中不在基线内的额外记录。V1 正式构建要求原始基线覆盖率为 100%。

当前实机快照包含 526 个唯一 spellID，其中 335 个对采样角色可见；这两个数字都是快照事实，不是手工维护的常量。`coverage-report.json` 在每次数据变更后重新生成。`att-mop-category-reference.json` 只保存转换后的 `spellID`、`itemID` 与来源大类。Alpha 可将其与本地 API 快照的交集导入为明确标记的 `candidate`：只显示来源类别和“详细地点待核实”，不复制 ATT 路径、文案或数据库；它不能代替逐条来源核验，也不能进入正式 V1。

Alpha 阶段可用 `/ymt inventory` 将目标客户端 API 返回的 `mountJournalID`、spellID、图标、名称、来源文本及可见性/收藏标记写入 `YiboMountsDiagnostics.mountInventory`。来源文本只来自目标客户端的坐骑日志，用于离线把所有来源类别归档为 Yibo 的规范化记录；它不参与运行时加载，也不记录角色收藏状态。

转换命令：

```powershell
python _NonRelease/Tools/import_mount_inventory.py `
  --saved-variables "<WoW>/_classic_/WTF/Account/<账号>/SavedVariables/YiboMounts.lua" `
  --output _NonRelease/Data/mount-inventory.json
```

将本次快照中的游戏内来源文本写回候选目录：

```powershell
python _NonRelease/Tools/import_client_source_facts.py `
  --catalog _NonRelease/Data/mounts.json `
  --inventory _NonRelease/Data/mount-inventory.json `
  --reference _NonRelease/Data/att-mop-category-reference.json `
  --apply
```

该步骤覆盖掉落、任务、商人、制造、成就、活动、推广和商城等所有坐骑日志类别；它只处理客户端返回的来源事实。手工核验过的结构化路径优先，不会被这一批候选覆盖。

当目标客户端未为旧坐骑提供坐骑日志来源文本时，可离线提取本机资料中的纯数字游戏事实：

```powershell
python _NonRelease/Tools/extract_local_mount_facts.py `
  --inventory _NonRelease/Data/mount-inventory.json `
  --source-root "<WoW>/Interface/AddOns/AllTheThings/db" `
  --output _NonRelease/Data/source-fact-extract.json
```

该提取器不执行 Lua，也不输出名称、文案、注释、代码、图标或原始数据库结构；输出仅用作 Yibo 自有目录的来源 ID 核验队列，不能直接作为发布数据。

## 3. 根对象

```json
{
  "schemaVersion": 1,
  "catalogVersion": "0.1.0-alpha.1",
  "target": {
    "flavor": "MISTS_CLASSIC",
    "gameVersion": "5.5.4",
    "interface": 50504
  },
  "mounts": []
}
```

约束：

- `schemaVersion`：数据结构版本，只在不兼容结构变化时递增。
- `catalogVersion`：内容版本；增加或修正坐骑记录时递增。
- `target.interface`：必须为整数 `50504`。
- `mounts`：坐骑实体数组；`mountKey` 在整个目录中唯一。

## 4. 坐骑实体

```json
{
  "mountKey": "astral-cloud-serpent",
  "status": "verified",
  "ids": {
    "spellIDs": [127170],
    "itemIDs": [87777],
    "mountJournalID": null
  },
  "identity": {
    "iconFileID": 656166,
    "names": {
      "enUS": "Astral Cloud Serpent",
      "zhCN": "星光云端翔龙"
    }
  },
  "restrictions": {
    "factions": [],
    "classes": []
  },
  "sources": [],
  "primarySourceID": "elegon-drop"
}
```

### 4.1 `mountKey`

- 小写 kebab-case ASCII，例如 `astral-cloud-serpent`。
- 是本项目持久、不可复用的实体标识。
- 不使用本地化名称、数组位置或客户端临时索引。
- 即使显示名称或来源改变，`mountKey` 仍保持不变。

### 4.2 `status`

允许值：

| 值 | 含义 | 是否进入生成物 |
|---|---|---|
| `candidate` | 已建候选，尚未完成交叉核验 | Alpha 可选；正式 V1 否 |
| `verified` | ID、身份和主要来源均已核验 | 是 |
| `rejected` | 已确认不是目标坐骑或 ID 错误 | 否 |

正式 V1 构建必须拒绝任何进入发布集合的 `candidate`。

### 4.3 `ids`

- `spellIDs`：非空正整数数组；每个值在全目录中只能属于一个 `mountKey`。
- `itemIDs`：可为空；每个值为正整数。共享或历史物品必须在证据备注中解释。
- `mountJournalID`：可空正整数。不得假定 MoP Classic 一定提供稳定可用的 Mount Journal API。
- 同一数组内部不得重复。

运行时 Aura 查询只依赖生成后的 `spellID → mountKey` 索引。

### 4.4 `identity`

- `iconFileID`：可空正整数；V1 Tooltip 不依赖图标，V2 页面使用。
- `names.enUS`：必填非空字符串。
- `names.zhCN`：正式 V1 必填；Alpha 可以缺失并回退 `enUS`。
- 名称只用于未来目录、诊断和测试，不替换原 Aura Tooltip 已有标题。

### 4.5 `restrictions`

- `factions`：`ALLIANCE`、`HORDE` 的零个、一个或两个值；空数组表示不限。
- `classes`：大写英文 class token 数组；空数组表示不限。
- 限制只在影响获取判断时进入条件行，不因为玩家当前职业或阵营不符而隐藏已识别坐骑。

## 5. 来源实体

```json
{
  "sourceID": "elegon-drop",
  "type": "boss_drop",
  "priority": 100,
  "active": true,
  "availability": "obtainable",
  "path": [
    {
      "kind": "instance",
      "refID": 1008,
      "labels": {
        "enUS": "Mogu'shan Vaults",
        "zhCN": "魔古山宝库"
      }
    },
    {
      "kind": "boss",
      "refID": 60410,
      "labels": {
        "enUS": "Elegon",
        "zhCN": "伊拉贡"
      }
    }
  ],
  "requirements": {
    "difficulties": ["NORMAL", "HEROIC"],
    "reputation": null,
    "costs": [],
    "questID": null,
    "achievementID": null,
    "eventKey": null,
    "notes": null
  }
}
```

### 5.1 `sourceID`

- 在当前坐骑的 `sources[]` 内唯一。
- 小写 kebab-case ASCII。
- 用于 `primarySourceID` 引用，不作为跨坐骑全局标识。

### 5.2 `type`

V1 枚举：

| 值 | 显示类型 | 典型路径 |
|---|---|---|
| `boss_drop` | Drop / 掉落 | 副本 > 首领 |
| `rare_drop` | Rare Drop / 稀有掉落 | 地区 > 稀有怪 |
| `achievement` | Achievement / 成就 | 成就名称 |
| `reputation_vendor` | Reputation / 声望 | 阵营 > 商人 |
| `vendor` | Vendor / 商人 | 地区 > 商人 |
| `quest` | Quest / 任务 | 地区 > 任务 |
| `class_reward` | Class / 职业 | 职业 > 来源 |
| `holiday` | Holiday / 节日 | 节日活动 > NPC |
| `event` | Event / 活动 | 活动 > 来源 |
| `promotion` | Promotion / 推广 | 活动或推广名称 |
| `store` | Store / 商城 | 商城渠道 |
| `crafted` | Crafted / 制造 | 专业 > 配方或制造物 |

可获取状态不是来源类型，不得创建 `unavailable` 类型。

### 5.3 主要来源选择

生成器必须检查：

1. `primarySourceID` 指向存在的来源；
2. V1 至少存在一个来源；
3. Tooltip 优先使用 `primarySourceID`；
4. 如果主要来源被标记为非当前主要来源，数据维护者必须显式更新 `primarySourceID`，运行时不猜测替代项；
5. V2/V3 可以读取全部 `sources[]`，V1 只渲染主要来源。

`priority` 用于未来目录排序和候选审计，不替代明确的 `primarySourceID`。

阵营替代来源例外：当同一 `spellID` 对应联盟与部落不同的商人路径时，两个来源都保留在 `sources[]`，并各自标明阵营条件。V1 Tooltip 默认按当前角色阵营选择一个匹配来源；无可匹配阵营或没有阵营上下文时才回退 `primarySourceID`。V2/V3 的 Core 页面可切换为同时展示两个来源。

### 5.4 `availability`

允许值：

| 值 | 含义 | V1 条件行 |
|---|---|---|
| `obtainable` | 当前持续可获取 | 无额外状态 |
| `limited_time` | 仅活动期间可获取 | 显示活动条件 |
| `rotation` | 周期轮换或不持续开放 | 显示轮换条件 |
| `unavailable` | 当前无法获取 | `No longer obtainable` / `当前已无法获取` |
| `unknown` | 尚未可靠确认 | 不得进入正式 V1 |

绝版坐骑仍保留历史来源路径；`unavailable` 只控制第二条逻辑行。

## 6. 路径节点

每个 `path[]` 元素结构如下：

```json
{
  "kind": "boss",
  "refID": 60410,
  "labels": {
    "enUS": "Elegon",
    "zhCN": "伊拉贡"
  }
}
```

允许的 `kind` 初始集合：

- `instance`
- `boss`
- `zone`
- `npc`
- `faction`
- `achievement`
- `quest`
- `event`
- `promotion`
- `store`
- `class`
- `profession`
- `custom`

规则：

- `labels.enUS` 必填；正式 V1 的 `labels.zhCN` 必填。
- `refID` 在存在稳定游戏 ID 时必填；`promotion`、`store` 或历史 `custom` 可为空。
- `path` 按玩家阅读顺序存储，不在格式化器中倒序或按类型重排。
- 来源类型标签由 Locale 文件提供，不写入每条记录的 `path`。

最终第一行格式：

```text
<localized source type> > <path[1]> > <path[2]> ...
```

商人路径若需要玩家定位，顺序固定为：`商人 > 阵营或声望 > 地点 > NPC`。联盟/部落限制、声望阵营以及对应的声望等级应明确记录；没有适用限制的节点不显示。

联盟/部落拥有不同 `spellID` 的对应坐骑不是一个共享记录：必须各有独立的 `mountKey`、spellID 和来源路径。只有共享同一 `spellID` 的双阵营购买路径才使用同一记录中的多个来源。

## 7. 获取条件

```json
{
  "difficulties": ["NORMAL", "HEROIC"],
  "reputation": {
    "factionID": 1337,
    "standing": "EXALTED"
  },
  "costs": [
    {
      "type": "money",
      "amountCopper": 100000000
    },
    {
      "type": "currency",
      "currencyID": 697,
      "amount": 20
    },
    {
      "type": "item",
      "itemID": 12345,
      "amount": 1
    }
  ],
  "price": {
    "enUS": "100 Gold",
    "zhCN": "100金币"
  },
  "questID": null,
  "achievementID": null,
  "eventKey": null,
  "notes": {
    "enUS": null,
    "zhCN": null
  }
}
```

规则：

- 条件对象只保存获取所必需的事实。
- `notes` 仅用于无法结构化但对获取判断必要的短说明，不得写成长攻略。
- `price` 是维护表导入的人工可读价格补充（例如兑换价格、暂未映射稳定货币 ID 的价格）；优先用于 Tooltip 显示。
- 金钱统一保存铜币整数，不保存 `10,000 Gold` 这类最终显示文本；已具备稳定 ID 的价格应同时或优先使用 `costs`。
- 货币和物品成本使用稳定 ID 与数量。
- 难度、声望等级、职业和阵营名称由 Locale 格式化。
- 第二条逻辑行按照统一顺序压缩：限制 → 难度 → 声望 → 成本 → 活动状态 → 不可获取状态。
- 条件过多时仍保持一个逻辑字符串，让 Tooltip 自然换行；不得静默丢弃关键条件。

## 8. Locale 回退

运行时 Locale 规则：

```text
zhCN 客户端：字段 zhCN → 字段 enUS
其它客户端：字段 enUS
```

Locale 文件负责：

- 来源类型标签；
- 难度名称；
- 声望等级；
- 阵营与职业名称；
- `No longer obtainable` 等状态；
- 分隔符和数值格式。

目录记录负责专有实体的本地化标签。不得在生成 Lua 时根据开发机 Locale 固化最终文案。

## 9. 非发布证据

`source-evidence.csv` 至少包含：

```text
mountKey,fieldPath,sourceURL,sourceType,checkedAt,gameVersion,build,status,notes
```

允许的 `status`：

- `candidate`
- `verified`
- `conflict`
- `rejected`

最低核验要求：

- `spellIDs`：目标客户端数据或实机探针；
- 主要获取来源：MoP Classic 对应版本资料；
- 绝版、推广和版本差异：至少增加一个独立来源复核；
- 冲突未解决时，记录不得进入正式 V1。

证据文件只保存 URL、事实摘要和核验结论，不复制第三方长篇描述。

## 10. 生成物契约

生成后的 `MountCatalog.generated.lua` 应暴露不可变意图的数据表，不执行事件注册或 UI 行为：

```lua
YiboMountsData = {
  schemaVersion = 1,
  catalogVersion = "0.1.0-alpha.1",
  mounts = {
    ["astral-cloud-serpent"] = {
      -- normalized runtime record
    },
  },
  mountKeyBySpellID = {
    [127170] = "astral-cloud-serpent",
  },
}
```

生成器必须保证稳定排序，使相同输入产生字节级稳定输出，避免无意义 Diff。

## 11. 生成器校验

以下任一问题必须阻断生成：

- JSON 无法通过 Schema；
- 重复 `mountKey`；
- 重复或非正整数 `spellID`；
- `primarySourceID` 不存在；
- 缺少 `enUS` 名称或路径标签；
- 非法来源类型、路径节点、难度、阵营、职业或可获取状态；
- `verified` 记录的主要来源仍为 `unknown`；
- 正式 V1 模式下缺少 `zhCN`；
- 成本缺少 ID、数量或使用负数；
- `unavailable` 记录没有历史来源路径。

以下问题应输出警告并在正式发布前清零：

- 缺少 `iconFileID`；
- `candidate` 记录进入 Alpha 集合；
- 存在多个来源但没有解释主要来源选择；
- 专有实体只依赖自由文本而没有可用 `refID`；
- 证据核验日期或客户端构建号缺失。

## 12. 兼容与变更规则

- 新增可选字段可以保持 `schemaVersion` 不变。
- 删除字段、改变字段含义、改变枚举语义或更换稳定键必须提升 `schemaVersion`。
- `mountKey` 一旦发布不得复用；合并记录时必须保留别名迁移表。
- 新来源类型必须先更新 Schema、Locale、格式化器测试和本文，再进入数据。
- V2/V3 可以扩充收藏状态与目录字段，但不得改变 V1 的 `spellID → mount entity → primary source` 查询契约。
