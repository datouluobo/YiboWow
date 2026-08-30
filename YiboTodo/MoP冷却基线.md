# YiboTodo - MoP 5.5.4 冷却基线

这是 YiboTodo 0.1 的**单一目录输入**。目标客户端为 MoP Classic 5.5.4；按本客户端仍可使用的、由维护者确认的专业冷却收录。先由维护者确认本文件，再以本文件一次性生成/更新 `ActivityCatalog`、`CooldownCatalog`、`CooldownGroupCatalog` 与 `Ruleset_50504`；不得再按口头描述逐条添加冷却。

## 使用规则

- 本表的“用户确认”表示**应一次性实施**，不是候选池；缺少 spellID、itemID 或 API 原值只标注为待补证，不阻断目录落地。
- 公共冷却组是业务实体：同一组只能产生一个待办。表中未明确为共 CD 的项目，先按独立组实现；以后只能通过更新本表调整组关系。
- 国服每日专业制造统一按服务器时间 `07:00` 跨日；客户端 API 返回的零点式剩余时间只作为当日制作观察，不得覆盖该跨日规则。
- 本文件确认后，实施需将表内所有条目一次写入目录；探针只用于补齐或修正数据，不再临时新增代码分支。

## 用户确认的 MoP 0.1 冷却目录

| 稳定 ID | 中文名称 | 专业 | spellID | 产物 itemID | 公共冷却组 | 关系 / 待补证 |
|---|---|---:|---:|---:|---|---|
| `mop.blacksmithing.lightning-steel-ingot` | 霹雳钢锭 | 锻造 164 | 138646 | 94111 | `mop.blacksmithing.lightning-steel-ingot` | 独立组；已有 5.5.4 实机记录 |
| `mop.blacksmithing.balanced-trillium-ingot` | 两仪延极锭 | 锻造 164 | 143255 | 98717 | `mop.blacksmithing.balanced-trillium-ingot` | 独立组；已有 5.5.4 实机记录 |
| `mop.tailoring.imperial-silk` | 帝王丝绸 | 裁缝 197 | 125557 | 82447 | `mop.tailoring.imperial-silk` | 独立组；补 API 原值与重置语义 |
| `mop.tailoring.celestial-cloth` | 神纹布 | 裁缝 197 | 143011 | 98619 | `mop.tailoring.celestial-cloth` | 独立组；已有 5.5.4 实机制作用后冷却记录 |
| `mop.alchemy.living-steel` | 转化：活化钢 | 炼金 171 | 114780 | 72104 | `mop.alchemy.living-steel` | **已确认与其它转化不共 CD**；独立组 |
| `mop.alchemy.balanced-trillium-ingot` | 转化：延极锭 | 炼金 171 | 114783 | 72095 | `mop.alchemy.other-transmutes` | 与其它非活化钢转化是否共 CD：待后续验证；不得并入活化钢组。外部资料显示该配方本身无 API 冷却，实施时不得将“无冷却”误报为待办。 |
| `mop.enchanting.sha-crystal` | 邪煞水晶 | 附魔 333 | 116499 | 74248 | `mop.enchanting.sha-crystal` | 独立组；补 API 原值与重置语义 |
| `mop.engineering.jards-energy-source` | 贾德的特制能量源 | 工程 202 | 139176 | 94113 | `mop.engineering.jards-energy-source` | 独立组；已有 5.5.4 实机记录 |
| `mop.inscription.scroll-of-wisdom` | 智慧卷轴 | 铭文 773 | 112996 | 79731 | `mop.inscription.scroll-of-wisdom` | 独立组；补 API 原值与重置语义 |
| `mop.jewelcrafting.blue-gem-research` | 6 种蓝宝石研究 | 珠宝加工 755 | 131593 / 131688 / 131691 / 131695 / 待索引×2 | 不产出物品 | `mop.jewelcrafting.blue-gem-research` | 6 种共 CD；已索引碧蓝之心、翠榄石、皇紫晶、日曜石；余两种补索引后同组写入。 |
| `mop.jewelcrafting.serpents-heart` | 神龙之心 | 珠宝加工 755 | 140050 | 95469 | `mop.jewelcrafting.serpents-heart` | 独立组；补 API 原值与重置语义 |
| `mop.leatherworking.magnificent-fur` | 华丽毛皮 | 制皮 165 | 140040 / 140041 | 72163 | `mop.leatherworking.magnificent-fur` | 华丽制皮秘决与华丽制鳞秘决共用每日 CD；与强化华丽毛皮不共 CD；使用成品图标。 |
| `mop.leatherworking.enhanced-magnificent-fur` | 强化华丽毛皮 | 制皮 165 | 142976 | 98617 | `mop.leatherworking.enhanced-magnificent-fur` | 与华丽毛皮不共 CD；使用成品图标。 |

## 已核对的外部资料

- Wowhead MoP Classic：`Transmute: Living Steel`（spell 114780），页面标注 1 天冷却及产物 Living Steel。
  <https://www.wowhead.com/mop-classic/spell=114780/transmute-living-steel>
- Wowhead MoP Classic：`Imperial Silk`（spell 125557），页面标注 1 天冷却；资料说明和谐之歌可绕过该冷却。
  <https://www.wowhead.com/mop-classic/spell=125557/imperial-silk>
- Wowhead MoP Classic：`Celestial Cloth`（spell 143011，产物 98619），页面标注 1 天冷却；5.5.4 简体客户端名称为“神纹布”。
  <https://www.wowhead.com/mop-classic/spell=143011/celestial-cloth>
- Wowhead MoP Classic：`Scroll of Wisdom`（spell 112996），页面标注 1 天冷却。
  <https://www.wowhead.com/mop-classic/spell=112996/scroll-of-wisdom>
- Wowhead MoP Classic：`Transmute: Trillium Bar`（spell 114783，产物 72095）。资料页的法术详情为无冷却；这不否定其在目录中的配方身份，但禁止将无冷却状态显示成“可处理”。
  <https://www.wowhead.com/mop-classic/spell=114783/transmute-trillium-bar>
- Wowhead MoP Classic：`Sun's Radiance`（spell 131695）明确说明该研究与其它五种潘达利亚宝石研究共享每日冷却。
  <https://www.wowhead.com/mop-classic/spell=131695/suns-radiance>
- Wowhead MoP Classic：`Sha Crystal`（spell 116499）与 `Serpent's Heart`（spell 140050，产物 95469）。
  <https://www.wowhead.com/mop-classic/spell=116499/sha-crystal>
  <https://www.wowhead.com/mop-classic/spell=140050/serpents-heart>
- 中文名称采用当前简体客户端常用译名；实施时以目标客户端 `GetTradeSkillInfo` 返回的名称为显示名校验，不用本地化名称作存储键。

## 实机探针记录模板

每个条目在实施后以同一轮探针补齐以下字段：

| 稳定 ID | 完整构建 | 专业窗口归属 | 配方已学习 | API 原始冷却值 | `readyAt` | 公共组一致 | 观察时间 |
|---|---|---|---|---|---|---|---|
| `mop.…` | `5.5.4` | 自己 / 非自己 | 是 / 否 | 秒或 start/duration | Unix 时间 | 是 / 否 | `YYYY-MM-DD HH:mm` |

任何配方未学习、当前无冷却、与组成员冲突或 API 语义不一致，都应更新本表的结论，再统一更新目录；不要在 Lua 中添加临时例外。
