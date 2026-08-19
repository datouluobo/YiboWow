# YiboBeastPaths 1.5.0 正式服支持开发计划

## 文档定位

本文用于固化 `1.5.0` 版本的正式服支持方案。

`1.5.0` 的核心不是一次性解决所有正式服差异，而是先建立稳定的多客户端承载结构：

- 一个发布包
- 两个 TOC
- 一套共享代码主体
- 共享基线数据
- 按客户端 flavor 覆盖差异数据

后续如果正式服与 MoP Classic 在 API、地图、路线、宠物清单或位面上出现差异，再通过 `1.5.x` 系列逐步补齐。

---

## 版本目标

`1.5.0` 的目标是让同一个 CurseForge 发布文件同时支持：

1. Retail / 正式服
2. MoP Classic / `5.5.4`

发布包内只保留两个 TOC：

```text
YiboBeastPaths.toc
YiboBeastPaths_Mists.toc
```

其中：

1. `YiboBeastPaths.toc` 作为主 TOC，归属 Retail / 正式服。
2. `YiboBeastPaths_Mists.toc` 归属 MoP Classic / `5.5.4`。
3. 两个 TOC 引用同一批共享 Lua 文件。
4. 不为 Retail 与 Mists 分别打包。

---

## 设计原则

### 一、单包双 TOC

正式采用类似 WeakAuras 的发布模式：

1. 插件目录中同时存在多个客户端 TOC。
2. 用户只下载一个 zip。
3. CurseForge 上传时在同一个文件上选择多个支持的游戏版本。
4. 后续发布、版本号、资源文件和 changelog 尽量保持同步。

该方案会增加兼容性测试成本，但可以减少以下成本：

1. 多包构建成本
2. 多文件上传成本
3. 多包版本号同步成本
4. 用户下载和识别成本

### 二、共享代码主体

Retail 与 Mists 不拆成两份代码目录。

默认所有核心逻辑仍放在现有文件中：

1. `Core.lua`
2. `Renderer.lua`
3. `MinimapRenderer.lua`
4. `RouteResolver.lua`
5. 各类路线和显示数据文件

只有确认存在客户端差异时，才新增兼容层或覆盖数据。

### 三、共享基线 + flavor overrides

数据兼容采用“共享基线 + flavor overrides”模式。

含义是：

1. 当前 MoP Classic 已调好的数据作为共享基线。
2. Retail 默认复用共享基线。
3. 如果 Retail 与 Mists 的地图、路线、节点、脚印、显示参数不同，只为差异部分添加 Retail override。
4. 如果未来 Mists 也需要从共享基线分离，再添加 Mists override。

不在 `1.5.0` 阶段提前把所有数据拆成 Retail/Mists 两套完整文件。

---

## 文件结构目标

### TOC 文件

目标结构：

```text
YiboBeastPaths.toc
YiboBeastPaths_Mists.toc
```

建议归属：

```text
YiboBeastPaths.toc        # Retail / 正式服
YiboBeastPaths_Mists.toc  # MoP Classic / 5.5.4
```

两个 TOC 的文件列表应尽量一致。

发布版 TOC 中不得引用：

```text
_NonRelease\DebugCalibrator.lua
```

调试工具仍保留在 `_NonRelease/` 中，不进入 release zip。

### 运行时 flavor 文件

建议新增：

```text
Flavor.lua
```

职责：

1. 识别当前客户端 flavor。
2. 设置统一标记。
3. 为 API 兼容和数据覆盖提供入口。

建议暴露：

```lua
ns.FLAVOR
ns.IS_RETAIL
ns.IS_MISTS
ns.IS_CLASSIC
```

优先基于 `WOW_PROJECT_ID` 判断。

### 数据覆盖文件

建议预留：

```text
FlavorOverrides.lua
```

或按数据量进一步拆分为：

```text
RetailOverrides.lua
MistsOverrides.lua
```

`1.5.0` 推荐先使用一个轻量入口文件，不急于拆多。

职责：

1. 在共享基线加载后应用 flavor 专属覆盖。
2. 支持覆盖宠物基础信息。
3. 支持覆盖地图 ID。
4. 支持覆盖路线 transform。
5. 支持覆盖小地图 transform。
6. 支持覆盖 route nodes。
7. 支持覆盖 footprint anchors。

---

## 数据兼容边界

### 共享基线

以下文件在 `1.5.0` 仍视为共享基线：

1. `Data.lua`
2. `ReferenceRoutes.lua`
3. `ResolvedRoutes.lua`
4. `FootprintAnchors.lua`
5. `RouteTransforms.lua`
6. `MinimapTransforms.lua`
7. `RouteNodes.lua`
8. `RouteOverlays.lua`
9. `RouteDisplayMeta.lua`

### Retail override 候选

如果正式服实测发现差异，优先通过 Retail override 修正：

1. 地图 `mapID` 不一致
2. 地图画布比例或偏移不一致
3. 世界地图路线整体偏移
4. 小地图路线投影偏移
5. 起点节点偏移
6. 脚印点坐标不同
7. 某只宠物在正式服不存在、不可驯服或换区域
8. 正式服新增同类 Pandaria trackable hidden hunter pet

### 不在 1.5.0 解决的内容

以下内容不作为 `1.5.0` 必须完成项：

1. 噩兆 `50813` 的锦绣谷位面问题
2. Retail 专属新增宠物路线补齐
3. Retail 专属路线大规模重调
4. 正式服所有相位状态自动识别
5. Cata / Wrath / Vanilla 支持

这些内容进入 `1.5.1` 或 `1.5.x`。

---

## 宠物清单边界

`1.5.0` 初始支持范围仍为当前 10 只 Pandaria 隐藏猎人宠物：

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

`1.5.0` 必须完成一次宠物边界审计。

审计目标：

1. 确认这 10 只在 Retail 资料中仍存在。
2. 确认是否仍可驯服。
3. 确认是否仍位于同一 Pandaria 区域。
4. 确认 Retail 是否新增或移除了同类 Pandaria trackable hidden hunter pet。
5. 将不确定项记录到后续 `1.5.x` 清单。

参考资料候选：

1. Wowhead `Rare Pandaria Hunter Pets`
   https://www.wowhead.com/guide/rare-pandaria-hunter-pets-1293
2. Wowhead `Secret Hunter Pets Guide`
   https://www.wowhead.com/guide/secret-hunter-pet-tames
3. Wowhead 单体 NPC 页面，例如 `Patrannache`
   https://www.wowhead.com/npc=50885/patrannache

资料审计不能替代游戏内实测。

---

## 地图清单边界

`1.5.0` 初始地图范围仍为当前 7 张 Pandaria 地图：

1. 翡翠林 / `371`
2. 四风谷 / `376`
3. 昆莱山 / `379`
4. 螳螂高原 / `388`
5. 锦绣谷 / `390`
6. 卡桑琅丛林 / `418`
7. 恐惧废土 / `422`

`1.5.0` 必须完成一次地图边界审计。

审计目标：

1. Retail 下这些 `uiMapID` 是否仍可用。
2. Retail 世界地图是否能命中对应路线。
3. Retail 大地图路线是否有整体偏移。
4. Retail 小地图路线是否有整体偏移。
5. 是否存在相位导致的地图或目标差异。

如果发现差异：

1. 先记录。
2. 判断是否需要 Retail override。
3. 除非差异会导致 Retail 基础不可用，否则不强行纳入 `1.5.0` 修复范围。

---

## 噩兆与锦绣谷位面

噩兆 `50813 / Portent` 位于锦绣谷。

Retail 中锦绣谷可能受到剧情阶段、旧新版地图状态或 Zidormi 相位影响。

`1.5.0` 对该问题的处理原则：

1. 不把噩兆位面问题作为 `1.5.0` 阻塞项。
2. 在审计文档中记录实际表现。
3. 在 README 或 changelog 中标注已知限制。
4. 将专项修复放入 `1.5.1`。

`1.5.1` 可考虑：

1. 补充相位说明。
2. 补充游戏内提示。
3. 补充 Retail 专属地图或路线 override。
4. 如果可行，做 Zidormi 状态相关提示。

---

## API 兼容边界

`1.5.0` 需要建立基础 API 兼容层。

优先检查以下点：

1. `C_AddOns.IsAddOnLoaded` / `IsAddOnLoaded`
2. `WorldMapFrame`
3. `WorldMapFrame:GetMapID()`
4. `WorldMapFrame.ScrollContainer.Child`
5. `BackdropTemplate`
6. `SetAtlas`
7. `Texture:SetRotation`
8. `C_Minimap.GetViewRadius`
9. `GetCVar("rotateMinimap")`
10. `HereBeDragons`

原则：

1. 已有兼容函数继续保留。
2. 新增兼容逻辑尽量集中。
3. 不在渲染主体里散落大量 Retail/Mists 判断。
4. 如果某个 API 仅 Retail 或仅 Mists 存在，包装成 helper 后再调用。

---

## 构建与发布方案

### 构建结果

`1.5.0` 生成统一放在仓库根目录 `Builds/` 的两个 zip：

```text
YiboBeastPaths-v1.5-curseforge.zip
YiboBeastPaths-v1.5-github.zip
```

其中：

1. curseforge zip 用于 CF 上传。
2. github zip 用于 GitHub Release。
3. 两个 zip 都不包含 `_NonRelease/`。
4. 两个 zip 都保留顶级目录 `YiboBeastPaths/`。
5. curseforge zip 中同时存在两个 TOC。

### CurseForge 发布

CF 上传时，单个 release 文件选择多个 Game versions：

1. Retail 当前正式服版本
2. MoP Classic `5.5.4`

项目 ID 仍为：

```text
1575919
```

上传脚本仍使用：

```text
_NonRelease/Tools/Publish-CurseForge.ps1
```

---

## 1.5.0 实施阶段

### 阶段一：TOC 分流

目标：

1. 主 TOC 切换为 Retail。
2. 新增 `YiboBeastPaths_Mists.toc`。
3. 两个 TOC 引用共享文件。
4. release zip 内保留两个 TOC。

验收：

1. MoP Classic 能识别 `YiboBeastPaths_Mists.toc`。
2. Retail 能识别 `YiboBeastPaths.toc`。
3. release TOC 不引用 `_NonRelease/`。

### 阶段二：Flavor 标记

目标：

1. 新增运行时 flavor 识别。
2. 暴露 `ns.FLAVOR`、`ns.IS_RETAIL`、`ns.IS_MISTS`。
3. 替换隐式 flavor 判断。

验收：

1. Mists 下识别为 `mists`。
2. Retail 下识别为 `retail`。
3. 不支持的 Classic flavor 不宣称支持。

### 阶段三：Override 入口

目标：

1. 建立共享基线数据加载后的覆盖入口。
2. Retail 默认无差异时不改变现有数据。
3. 支持后续按 petID / mapID 覆盖局部数据。

验收：

1. 无 override 时行为等同当前数据。
2. 添加测试性 override 时可以只影响当前 flavor。
3. Mists 不受 Retail override 影响。

### 阶段四：API 兼容检查

目标：

1. 检查并收束 Retail/Mists API 差异点。
2. 避免正式服加载时出现 Lua 错误。

验收：

1. Retail 可加载。
2. Mists 可加载。
3. 世界地图打开无初始化错误。
4. 小地图初始化无 fatal error。

### 阶段五：宠物与地图审计

目标：

1. 完成 10 只宠物 Retail 边界审计。
2. 完成 7 张地图 Retail 边界审计。
3. 记录不确定项。

验收：

1. 形成审计记录。
2. 明确哪些问题属于 `1.5.0`，哪些进入 `1.5.1` 或 `1.5.x`。

### 阶段六：双端 smoke test

MoP Classic 验收：

1. 插件可加载。
2. 世界地图路线显示不退化。
3. 小地图路线显示不退化。
4. `/ybp`、`/ybp show`、`/ybp hide`、`/ybp mmdebug` 正常。

Retail 验收：

1. 插件可加载。
2. 插件列表不显示 TOC 过期。
3. Pandaria 世界地图路线能显示。
4. 地图按钮正常。
5. 起点节点和 tooltip 正常。
6. 小地图不报错。

---

## 版本边界

### 1.5.0 必做

1. 单包双 TOC。
2. 主 TOC 切换为 Retail。
3. `YiboBeastPaths_Mists.toc` 支持 MoP Classic。
4. 运行时 flavor 识别。
5. 共享基线 + flavor overrides 架构。
6. API 基础兼容整理。
7. 宠物边界审计。
8. 地图边界审计。
9. README / changelog 更新。
10. release zip 保留两个 TOC 且排除 `_NonRelease/`。

### 1.5.0 不做

1. 不拆成 Retail/Mists 两个发布包。
2. 不支持 Cata / Wrath / Vanilla。
3. 不新增宠物路线。
4. 不重建所有路线数据。
5. 不一次性解决噩兆位面问题。
6. 不一次性解决所有 Retail 路线偏移。

### 1.5.1 候选

1. 噩兆 / 锦绣谷位面专项处理。
2. README 增补相位说明。
3. 游戏内 tooltip 或提示补充。
4. Retail 专属锦绣谷 override。

### 1.5.x 候选

1. Retail 宠物清单差异补齐。
2. Retail 新增同类宠物路线。
3. Retail 专属地图/路线/小地图 transform 修正。
4. HereBeDragons 更新或 Retail 兼容修正。
5. 更系统的双端测试清单。

---

## 风险

### 一、数据偏移风险

Retail 与 Mists 的地图数据可能不完全一致。

如果出现偏移，必须避免直接覆盖共享基线。

处理原则：

1. 先确认差异是否只存在于 Retail。
2. 再通过 Retail override 修正。
3. Mists 已调好的数据不能被 Retail 修正影响。

### 二、宠物清单风险

Retail 相比 MoP Classic 可能存在同类宠物数量、可驯服状态或位置差异。

处理原则：

1. `1.5.0` 先完成边界审计。
2. 不确定项进入 `1.5.x`。
3. 不因为未补齐新增宠物而阻塞单包双 TOC 架构落地。

### 三、位面风险

Retail 中的 Pandaria 区域可能受相位影响。

处理原则：

1. 噩兆位面问题进入 `1.5.1`。
2. `1.5.0` 只记录和提示。
3. 不把相位问题混入基础 TOC 改造。

### 四、测试成本风险

单包双 TOC 会让每次发布都需要双端测试。

处理原则：

1. 建立固定 smoke test 清单。
2. 每次改 API 或数据覆盖时至少测对应 flavor。
3. 重大渲染改动必须双端都测。

---

## 最终结论

`1.5.0` 的正式方向为：

1. 采用单包双 TOC。
2. 主 TOC 归属 Retail。
3. `YiboBeastPaths_Mists.toc` 归属 MoP Classic。
4. 保持共享代码主体。
5. 采用共享基线 + flavor overrides。
6. 先完成 Retail 承载能力和边界审计。
7. 将噩兆位面、宠物增减、路线差异修正放入 `1.5.1` 和 `1.5.x`。

一句话收敛：

`1.5.0` 先把“一个包同时承载 Retail 与 MoP Classic”的结构搭稳，并为 API 与数据差异留出正确入口；正式服内容差异再按 `1.5.x` 持续补齐。
