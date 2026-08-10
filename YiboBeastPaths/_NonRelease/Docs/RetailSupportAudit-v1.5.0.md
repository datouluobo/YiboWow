# YiboBeastPaths 1.5.0 Retail 支持审计记录

## 审计定位

本文记录 `1.5.0` 正式服支持落地时的边界状态。

`1.5.0` 已先完成承载架构：单包双 TOC、运行时 flavor 识别、共享基线与 flavor override 入口。

Retail 已完成若干路线的游戏内初测。世界地图显示正常，小地图与世界地图基本一致。

仍需在发布前继续补齐更完整的路线覆盖测试，尤其是锦绣谷相位。

---

## 已完成的结构项

1. `YiboBeastPaths.toc` 作为默认入口，归属 Retail / 正式服。
2. `YiboBeastPaths_Mainline.toc` 归属 Retail / 正式服，供支持 `_Mainline` suffix 的客户端识别。
3. `YiboBeastPaths_Mists.toc` 归属支持 `_Mists` suffix 的 MoP Classic 客户端。
4. 各 TOC 引用同一批共享 Lua 文件。
5. 新增 `Flavor.lua`，暴露 `ns.FLAVOR`、`ns.IS_RETAIL`、`ns.IS_MISTS`、`ns.IS_CLASSIC`。
6. 新增 `FlavorOverrides.lua`，预留 Retail/Mists 差异覆盖入口。
7. 构建脚本会清理 release zip 内所有 `YiboBeastPaths*.toc` 的 `_NonRelease` 引用。

---

## 当前数据边界

`1.5.0` 继续以当前 10 只 Pandaria 隐藏猎人宠物作为共享基线：

1. `50811` 重蹄 / `Stompy`
2. `50812` 帕特兰纳克 / `Patrannache`
3. `50813` 噩兆 / `Portent`
4. `50816` 刺脊 / `Bristlespine`
5. `50817` 血牙 / `Bloodtooth`
6. `50818` 赫克萨波斯 / `Hexapos`
7. `50820` 洛克海德 / `Rockhide the Immovable`
8. `50821` 萨维奇 / `Savage`
9. `50822` 微光之蛾 / `Glimmer`
10. `66522` 邦比 / `Bombyx`

当前 7 张 Pandaria 地图也继续作为共享基线：

1. 翡翠林 / `371`
2. 四风谷 / `376`
3. 昆莱山 / `379`
4. 螳螂高原 / `388`
5. 锦绣谷 / `390`
6. 卡桑琅丛林 / `418`
7. 恐惧废土 / `422`

---

## 发布前实测清单

### MoP Classic

1. 插件可加载。
2. 世界地图路线显示不退化。
3. 小地图路线显示不退化。
4. `/ybp`、`/ybp show`、`/ybp hide`、`/ybp mmdebug` 正常。

### Retail

1. 插件可加载，插件列表不显示 TOC 过期。已初测通过。
2. 打开 Pandaria 地图不报 Lua 错误。已在部分路线初测通过。
3. 世界地图路线能按当前地图过滤显示。已初测通过。
4. 起点节点与 tooltip 正常。已初测通过。
5. 小地图初始化不报错。已初测通过。
6. 小地图路线在若干路线附近目测可用。已初测通过。
7. 小地图与世界地图存在轻微差别，暂列为已知问题。
8. 锦绣谷相位导致的目标不可见或路线差异仍需专项确认。

---

## 已知限制

1. Retail 正式服的宠物可驯服状态和新增/移除清单仍需游戏内或资料二次确认。
2. Retail 锦绣谷可能受剧情阶段、旧新版地图或 Zidormi 相位影响。
3. 噩兆 `50813 / Portent` 的锦绣谷位面问题不阻塞 `1.5.0`，进入 `1.5.1`。
4. Retail 小地图与世界地图存在轻微差别，当前不阻塞 `1.5.0`。后续优先通过脚印采集、路线融合和 Retail override 逐步细调。
5. 如果 Retail 出现路线偏移，不直接修改共享基线，应通过 `FlavorOverrides.lua` 添加 Retail override。
