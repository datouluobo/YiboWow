# YiboQuestBlocker Broker 支持决策与实施计划

> 面向 WoW 插件生态中的 LibDataBroker / LibDBIcon 兼容接入
>
> 最终决策：采用兼容接入路径，即优先使用 Broker 标准能力，缺库时自动回退到现有手写小地图按钮

---

## 1. 文档目的

本文档用于整理这次关于 `YiboQuestBlocker` 支持 Broker 的完整讨论结论，内容包括：

- 当前插件是否适合接入 Broker
- 现有代码里哪些能力已经具备
- 为什么不直接重写为纯 Broker 版本
- 为什么最终选择“优先 Broker、失败回退”的接入方式
- 后续实际实施时的改造边界、步骤、风险和验收标准

本文档不是并列方案清单，而是已经确定方向后的决策记录与实施计划。

---

## 2. 讨论结论先行

当前插件适合支持 Broker，而且改动面不大。

原因很直接：

- 已经有统一窗口开关入口
- 已经有可复用统计接口
- 已经有现成图标资源
- 已经有稳定 SavedVariables
- 已经有正常工作的手写小地图按钮作为兜底

因此这次接入的重点，不是“是否能做”，而是“该用多激进的方式做”。

最终决定：

- 保留当前手写小地图按钮能力
- 新增 `LibDataBroker-1.1 + LibDBIcon-1.0` 兼容
- 运行时优先走 Broker
- 缺库、漏打包或初始化失败时自动回退到现有按钮

这个方向本质上是“增强入口生态兼容”，而不是“重做整个插件入口层”。

---

## 3. 当前插件现状分析

### 3.1 仓库结构很轻

当前仓库核心文件很少：

- `YiboQuestBlocker_Core.lua`
- `YiboQuestBlocker_UI.lua`
- `YiboQuestBlocker.toc`
- `Media\\YQB_MinimapIcon`

没有 Ace3 框架，也没有现成第三方库打包结构。

这意味着：

- 好处是改动面清晰
- 风险是如果直接引入强依赖库，发布链路要求会显著提高

### 3.2 现有入口已经完整

当前插件已经具备 Broker 所需的几个核心入口能力：

1. 主窗口开关
   - `YQB.ToggleWindow()`

2. 统计接口
   - `YQB.GetStats()`

3. slash 命令
   - `/yqb`
   - `/yiboquestblocker`

4. 小地图图标资源
   - `Interface\\AddOns\\YiboQuestBlocker\\Media\\YQB_MinimapIcon`

这说明 Broker 接入不需要发明新的主行为，只需要把现有行为挂到新的生态入口上。

### 3.3 当前小地图按钮是手写实现

现有 UI 已经自己完成了小地图按钮整套逻辑：

- `CreateFrame("Button", "YQB_MinimapBtn", Minimap, ...)`
- 自己处理拖拽
- 自己处理环形定位
- 自己处理 Tooltip
- 左键开关主窗口

这有两个重要含义：

1. 当前按钮不是缺失状态，而是已经可用
2. Broker 接入时最应该避免的是“平白把稳定功能改坏”

### 3.4 当前数据层也具备复用条件

数据层里已经有适合 Broker 复用的信息：

- 统计数据：可直接给 tooltip 使用
- 窗口开关逻辑：可直接给左键行为使用
- 持久化能力：可承载图标位置与显隐配置

但同时也暴露出一个设计点：

当前 `minimapPos` 保存在角色级 `perChar[curCharKey]` 下，而 `LibDBIcon` 更适合使用账号级共享配置。

所以 Broker 接入不只是“加个库”，还涉及一处小型数据归位。

---

## 4. 我们讨论过的分歧点

### 4.1 看起来效果一样，实际差别在哪里

在用户感知上，下面两种做法看起来都可能表现为：

- 有 Broker 面板支持
- 有小地图图标
- 左键能开关窗口

但它们的差别不在表面效果，而在依赖模型。

一种思路是“完全交给 Broker 生态”：

- 入口只走 `LibDataBroker + LibDBIcon`
- 代码更干净
- 但只要库缺失、漏打包或加载顺序出问题，入口就可能一起丢

另一种思路是“Broker 是增强，不是单点依赖”：

- 有库时走标准 Broker
- 没库时继续用现在这套按钮
- 用户至少始终有一个稳定入口

我们最终选择的是第二种。

### 4.2 为什么不直接只保留纯 Broker

虽然纯 Broker 路线代码会更整洁，但当前仓库并不处在“必须去掉旧入口”的阶段。

直接彻底替换的主要问题：

- 当前手写按钮已经稳定工作，删掉没有明显收益
- 新增外部库后，发布包正确性要求更高
- 仓库目前没有 Ace3 / embeddable libs 的既有组织方式
- 这次需求本质是“支持 Broker”，不是“重构插件架构”

因此从投入产出比看，直接走纯 Broker 并不划算。

### 4.3 为什么最终采用“优先 Broker，失败回退”

这条路兼顾了四件事：

1. 满足生态兼容
   - 面板插件可以识别
   - 小地图图标可以交给 `LibDBIcon`

2. 保留用户入口稳定性
   - 缺库时不会失去入口

3. 便于渐进演进
   - 先挂接 Broker
   - 再决定是否进一步清理旧逻辑

4. 降低发布风险
   - 漏打包不至于让主入口全坏

所以这不是“保守妥协”，而是更适合当前仓库阶段的工程选择。

---

## 5. 最终采用的接入原则

### 5.1 总原则

- Broker 是增强能力
- 当前手写按钮是保底能力
- slash 命令始终保留

### 5.2 运行时优先级

1. 尝试探测 `LibStub`
2. 尝试探测 `LibDataBroker-1.1`
3. 尝试探测 `LibDBIcon-1.0`
4. 若都可用，则注册标准 Broker 数据源与小地图图标
5. 若任一步失败，则启用现有手写小地图按钮

### 5.3 接入边界

本次改造尽量只改“入口层”和“图标层”，不重写：

- 主窗口逻辑
- 任务拦截逻辑
- 网格 UI 刷新逻辑
- 拒绝列表结构
- 现有 slash 命令

---

## 6. 目标行为定义

### 6.1 LDB 对象类型

建议使用：

```lua
type = "launcher"
```

原因：

- 插件本质更像一个功能入口
- 并不是需要持续刷新的常驻文本数据源
- 对主流 Broker 面板兼容性更稳

### 6.2 点击行为

- 左键：调用 `YQB.ToggleWindow()`
- 右键：首版不强制定义

右键后续可扩展，但不应与本次接入绑定实现。

### 6.3 Tooltip 行为

Tooltip 建议复用当前统计能力，展示：

- 插件名
- 总拒绝数
- 全局拒绝数
- 当前角色拒绝数
- 左键提示

示例：

```text
YiboQuestBlocker
总计：12
全局：4
当前角色：8
左键开关窗口
```

### 6.4 图标资源

直接复用现有贴图：

`Interface\\AddOns\\YiboQuestBlocker\\Media\\YQB_MinimapIcon`

这样不新增素材成本，也能保持视觉一致。

---

## 7. 数据结构决策

### 7.1 当前问题

当前小地图位置保存在：

```lua
YiboQuestBlockerDB.perChar[curCharKey].minimapPos
```

这是角色级配置。

而标准 `LibDBIcon` 更适合使用账号级配置，例如：

```lua
YiboQuestBlockerDB.minimap = {
    hide = false,
    minimapPos = 220,
}
```

### 7.2 最终决定

Broker 路径新增顶层账号级配置：

```lua
YiboQuestBlockerDB.minimap = {
    hide = false,
    minimapPos = 220,
}
```

用途：

- `hide` 供 `LibDBIcon` 控制显隐
- `minimapPos` 供 `LibDBIcon` 控制位置

### 7.3 旧数据如何处理

这次不直接删除旧的 `perChar[*].minimapPos`。

处理原则：

1. 新增顶层 `minimap` 配置
2. 若新配置缺少 `minimapPos`，可尝试继承当前角色旧值
3. Broker 路径优先使用顶层 `minimap`
4. fallback 路径继续兼容旧字段，直到完全稳定

原因：

- 老用户升级后位置不容易突变
- fallback 仍可继续工作
- 可以分阶段清理旧字段，而不是一次性冒险

---

## 8. 依赖与加载策略

### 8.1 建议引入的最小库集合

建议最小集合如下：

- `LibStub`
- `CallbackHandler-1.0`
- `LibDataBroker-1.1`
- `LibDBIcon-1.0`

### 8.2 关键要求

即使这些库未来会被嵌入仓库或打入发布包，也不能在实现中假定它们“必然存在”。

必须做运行时探测。

### 8.3 回退触发条件

满足任一条件即进入 fallback：

- `LibStub` 不存在
- `LibDataBroker-1.1` 不存在
- `LibDBIcon-1.0` 不存在
- 注册过程中抛错

### 8.4 回退后必须保住的能力

- 有小地图入口
- 左键可开关窗口
- 可拖拽定位
- Tooltip 可显示统计
- slash 命令照常可用

---

## 9. 代码结构改造建议

### 9.1 建议拆成三层

建议把图标相关逻辑拆成三层职责：

1. 通用行为层
   - 窗口切换
   - Tooltip 统计内容
   - 图标配置读取

2. Broker 实现层
   - 创建 LDB launcher
   - 注册 `LibDBIcon`
   - 控制标准小地图图标

3. fallback 实现层
   - 保留当前 `CreateFrame` 按钮
   - 保留当前拖拽与 Tooltip 逻辑

### 9.2 首版不建议顺手做的事

以下内容不建议和本次接入绑在一起：

- 改造成 AceAddon
- 重写 UI 刷新架构
- 重写全部 SavedVariables 结构
- 做右键菜单
- 新增图形设置面板

这些都不是本次需求的核心目标，只会放大改动风险。

---

## 10. 实施计划

### 阶段 1：补齐依赖与 TOC 设计

目标：

- 确定库的组织方式
- 确认 `.toc` 加载顺序
- 保证缺库时插件本体仍能加载

计划：

1. 确定是否嵌库进仓库
2. 明确 `.toc` 中的库加载顺序
3. 确保库文件在 `Core` 和 `UI` 之前

建议补充的落地约束：

- 首版默认采用嵌库方式，不依赖用户额外安装独立库
- 库目录建议固定为 `Libs\\`
- `.toc` 中库文件必须显式列出，不依赖自动发现
- 如果后续要支持外部独立库，也应先保证嵌库版本可单独工作

### 阶段 2：抽公共行为

目标：

- 让 Broker 图标与手写按钮共用行为定义

计划：

1. 提炼左键切窗逻辑
2. 提炼 Tooltip 统计文案
3. 提炼图标配置访问接口

建议补充的落地约束：

- 公共行为优先挂到 `YQB` 下，避免在 `UI.lua` 内部形成新的隐式局部耦合
- Tooltip 文案应由一个统一函数生成，避免 Broker 与 fallback 两套文本逐渐分叉
- 图标配置访问接口应同时处理“顶层新配置读取”和“旧字段兼容读取”

### 阶段 3：接入 Broker 主路径

目标：

- 在支持库存在时创建标准 Broker 入口

计划：

1. 安全探测 `LibStub`
2. 获取 `LibDataBroker-1.1`
3. 获取 `LibDBIcon-1.0`
4. 创建 launcher 对象
5. 绑定 `OnClick` 和 `OnTooltipShow`
6. 注册小地图图标

建议补充的落地约束：

- Broker 初始化建议包在保护调用中，避免库内部异常直接中断插件加载
- `OnClick` 必须只复用现有窗口开关行为，不引入新的状态机
- 首版不设置动态 `text`，避免不同面板对文字展示差异带来额外兼容成本
- 注册使用的对象名应固定，例如 `YiboQuestBlocker`，避免后续重构时出现重复注册名

### 阶段 4：接通 fallback

目标：

- 缺库时自动走现有按钮

计划：

1. 封装当前手写小地图按钮初始化
2. 在 Broker 初始化失败时调用 fallback
3. 确保成功使用 Broker 时不重复创建手写按钮

建议补充的落地约束：

- fallback 不只是“缺库才创建”，还要覆盖“库存在但注册失败”的情况
- fallback 初始化函数应保证幂等，避免事件重入或二次调用创建多个按钮
- 若曾创建过 fallback 按钮，再次初始化时应优先复用，而不是重复 `CreateFrame`

### 阶段 5：数据迁移兼容

目标：

- 尽量平滑继承老用户图标位置

计划：

1. 初始化顶层 `YiboQuestBlockerDB.minimap`
2. 缺省时尝试继承当前角色旧 `minimapPos`
3. 验证新旧路径不互相冲突

建议补充的落地约束：

- 顶层 `minimap` 的默认值应在 `Core.lua` 的数据库初始化阶段统一补齐
- 迁移只做“缺省填充”，不覆盖用户已经存在的新配置
- fallback 路径在首版仍允许继续写旧 `perChar[curCharKey].minimapPos`
- 首版不做旧字段清理，避免升级首发把兼容面收得太紧

### 阶段 6：文档与发布说明

目标：

- 把能力和兼容行为说明清楚

计划：

1. 更新 `README.md`
2. 更新 `CHANGELOG.md`
3. 说明新增 Broker 支持
4. 说明缺库自动回退行为

建议补充的落地约束：

- `README` 里要明确说明“插件自带 Broker 支持，无需强制额外安装面板插件”
- 如果仓库引入 `Libs\\` 目录，发布说明要同步更新目录结构
- `CHANGELOG` 里要单独写明“Broker 支持”与“fallback 兼容”

---

## 11. 实施前还缺什么

从“能定方向”到“可以直接照文档开工”，目前还差以下几类信息。它们不改变决策方向，但如果不先补齐，实施时容易反复。

### 11.1 缺少明确的文件落点

目前文档已经说明了要改“入口层”和“图标层”，但还没把代码落点写死。

建议明确为：

- `YiboQuestBlocker.toc`
  - 增加 `Libs\\` 相关加载项
  - 保持库文件在 `Core` / `UI` 之前

- `YiboQuestBlocker_Core.lua`
  - 增加 `YiboQuestBlockerDB.minimap` 的初始化与兼容迁移
  - 暴露图标配置访问或公共 Tooltip 数据接口给 `YQB`

- `YiboQuestBlocker_UI.lua`
  - 抽离当前小地图按钮逻辑为 fallback 初始化函数
  - 增加 Broker 初始化入口
  - 保证 slash 命令与窗口逻辑保持不变

这样实施时就不会再回头讨论“Broker 逻辑放 Core 还是 UI”。

### 11.2 缺少建议目录结构

当前仓库没有第三方库目录，文档里虽然提到“嵌库”，但还没写清建议结构。

建议固定为：

```text
YiboQuestBlocker\
├── Libs\
│   ├── LibStub\
│   ├── CallbackHandler-1.0\
│   ├── LibDataBroker-1.1\
│   └── LibDBIcon-1.0\
├── Media\
├── YiboQuestBlocker.toc
├── YiboQuestBlocker_Core.lua
└── YiboQuestBlocker_UI.lua
```

这样可以直接指导后续 `.toc` 编排和发布结构。

### 11.3 缺少 `.toc` 目标形态示意

当前文档提到要补 `.toc`，但还没有“实施后应接近什么样”的示意。

建议目标形态如下：

```toc
## Interface: 50504
## Title: YiboQuestBlocker
## Notes: 任务屏蔽管理器 - 自动拒绝指定任务
## Author: Reasonix
## Version: 1.2.2
## SavedVariables: YiboQuestBlockerDB
## LoadOnDemand: 0

Libs\LibStub\LibStub.lua
Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua

YiboQuestBlocker_Core.lua
YiboQuestBlocker_UI.lua
```

说明：

- 这是目标结构示意，不代表必须逐字照抄
- 具体库文件名仍应以实际引入版本为准

### 11.4 缺少初始化时机说明

文档已写“运行时优先 Broker”，但还没明确在哪个初始化时机做更合适。

结合当前代码，建议：

- 数据初始化仍放在 `Core.lua`
- Broker / fallback 图标初始化放在 `UI.lua`
- 图标初始化应在 `YQB` 公共接口和 `EnsureCharDB` 可用之后执行
- 不额外依赖新的事件；首版尽量沿用当前加载路径

这样可以减少对现有 `ADDON_LOADED` 事件处理链的侵入。

### 11.5 缺少最小测试矩阵

当前验收标准够“判断成败”，但还不够“指导测试”。

建议补一个最小测试矩阵：

1. 有库，首次安装新版本
   - Broker 图标正常
   - 面板可识别
   - slash 正常

2. 无库，首次安装新版本
   - fallback 按钮正常
   - 不报错

3. 老用户升级，有旧 `perChar.minimapPos`
   - 新图标位置基本继承
   - 主窗口状态正常

4. 切角色登录
   - Broker 路径位置按顶层配置表现一致
   - fallback 路径不崩

5. `/reload`
   - 不重复生成图标
   - 不丢配置

6. Broker 初始化失败模拟
   - 能自动回退到手写按钮

### 11.6 缺少非目标说明

为了避免实施时边写边扩需求，建议明确本次非目标：

- 不新增设置面板
- 不新增右键菜单
- 不改主窗口布局
- 不改自动放弃逻辑
- 不清理旧 `perChar.minimapPos`

这能帮助控制首版范围。

---

## 12. 验收标准

### 11.1 库存在时

需要满足：

- Broker 面板可识别 `YiboQuestBlocker`
- `LibDBIcon` 图标正常显示
- 左键能开关主窗口
- Tooltip 能展示统计信息

### 11.2 库不存在时

需要满足：

- 插件不会因缺库报错阻止加载
- 手写小地图按钮仍可正常显示
- 左键仍能开关主窗口
- slash 命令照常可用

### 11.3 老用户升级时

需要满足：

- SavedVariables 不损坏
- 图标位置尽量继承旧配置
- 主功能不受影响

---

## 13. 主要风险与应对

### 12.1 发布包漏库

风险：

- `.toc` 写了库，但发布时没打进去

应对：

- 运行时探测库
- 缺库立即 fallback

### 12.2 图标重复

风险：

- Broker 图标和手写按钮同时出现

应对：

- 只有 Broker 初始化失败才创建 fallback 按钮

### 12.3 新旧位置数据不一致

风险：

- 切角色后位置变化
- Broker 与 fallback 表现不一致

应对：

- 顶层 `minimap` 作为新标准配置
- 旧字段先保留兼容，分阶段清理

### 12.4 不同面板显示差异

风险：

- 不同 Broker 面板对展示形式略有差异

应对：

- 首版只做最标准的 `launcher`
- 尽量只依赖标准 `OnClick` / `OnTooltipShow`

---

## 14. 后续可选增强

这次不做，但以后可以考虑：

- 右键快速菜单
- 小地图图标显示/隐藏开关
- 文本模式显示总拒绝数
- 更丰富的 Tooltip
- Broker 稳定后清理旧 `perChar.minimapPos`

---

## 15. 结论

这次关于 Broker 的讨论，最终不是在“两个实施方案里长期并存”，而是已经形成了明确决策：

- 要支持 Broker
- 但不把 Broker 做成硬依赖
- 优先走 `LibDataBroker + LibDBIcon`
- 缺库时自动回退到现有手写小地图按钮

这个决定和当前仓库状态是匹配的：

- 仓库轻量
- 现有按钮稳定
- 需求是增强兼容，而不是架构重写

因此后续实现应直接围绕这份决策推进，而不是再回到“纯 Broker 还是兼容 Broker”的分叉讨论。
