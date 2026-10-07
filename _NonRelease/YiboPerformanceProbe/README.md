# Yibo 卡顿诊断

状态：探针已完成；实机归因待采样。此探针不参与发布。

## 使用

探针目录名与 TOC 同为 `YiboPerformanceProbe`，客户端 AddOns 下使用同名联接。
客户端发现新 TOC 需要完整退出游戏再进入；在插件列表启用 `[Yibo] 性能诊断探针`。

1. 进入角色，等待加载结束，再执行 `/ypf start`。
2. 按平时路线跑动，复现两三次卡顿；期间不要切后台、打开设置或主动 `/reload`。
3. 执行 `/ypf stop`，再执行 `/ypf report`。
4. `/reload` 或正常退出，将结果写入 `WTF/Account/<账号>/SavedVariables/YiboPerformanceProbe.lua`。

开始会覆盖上一次探针采样；停止会还原仍由探针持有的函数。重载后不自动采样。
默认不启用 `scriptProfile`，不记录角色名、聊天、邮件或物品内容。
每项仅保存计数、累计和峰值，慢调用与长帧分别最多保留最近 60 条。

### 全插件 CPU 采样（v0.2）

当方法计时未能定位长帧时，执行 `/ypf cpuon`，客户端开启 `scriptProfile` 并自动重载。
重载后执行 `/ypf start`，复现后 `/ypf stop`、`/ypf report`。
最后执行 `/ypf cpuoff` 关闭 CPU 计时并重载，记录同时写入存档。
更新已存在探针只需 `/reload`，无需再次退出客户端。

此模式使用客户端原生 UpdateAddOnCPUUsage/GetAddOnCPUUsage，按约 0.5 秒区间统计所有插件，
长帧出现时立即额外采样，报告邻近区间的前五名及 Yibo 合计（排除探针自身）。
CPU 区间与长帧并非严格同一帧，不能把区间累计视为某一长帧的精确占比。
共享函数/库和下游钩子的归属依客户端统计，跨插件数值可能重叠。
开启 scriptProfile 会增加运行开销，因此只用于短时诊断；探针也显示采样 API 自身峰值。
累计 CPU 不等于墙钟耗时，也不覆盖 GPU、磁盘等待或客户端本机代码。
cpuWindows 同样最多保留 60 条；完整长帧时间、CPU 前五名与方法耗时保存在同一文件。

## 如何判断

- 单个回调出现接近 1000ms 的峰值，且时间与卡顿相符：重点检查该路径及它触发的第三方钩子。
- 同期长帧明显，已测回调没有明显耗时：不能直接归因于 Yibo，继续检查未覆盖路径、其它插件或客户端资源加载。
- 耗时是包含子调用的包容时间，父子调用不能相加。长帧由 OnUpdate 间隔识别，回调累计由探针 OnUpdate 切分区间，两者可能错位一帧，应结合 slowCalls 时间分析。
- 插件抛错的调用不计时；探针下一帧恢复嵌套计数。加载界面和加载结束后的两秒不记长帧，调用统计仍保留。
- 只包装启动时已加载的指定方法，不覆盖所有 Lua 执行。短调用也有计时开销；采样结束后停止。

## v0.3 拾取专项采样（2026-10-03）

2026-10-04 补充 Core/Vault 计时：Characters.GetAll、Defaults.Copy、DomainStore.Commit、Events.Fire、ItemResolver.Finish、Vault.Tooltip.Append、Vault.AccountPage.GetTooltipScope。用于区分全插件 CPU 已显示 Core 耗时、但既有方法没有覆盖的复制、事件分发及物品悬停路径。计时包含下游调用，不相加；仍不能覆盖客户端本机执行或全部局部回调。更新后 RL 加载。

最新同角色反馈：天堂阴影启用或停用 NDui Plus 都会卡顿，奔跑时也会发生。下述拾取功能对照属于早期排查记录；当前优先在该角色保持 Plus 停用，单独对照 NDui 本体，而不是继续逐项关闭 Plus 功能。角色间同一插件也可能因职业/条件加载而运行不同内容，尚无新采样定责。

保持 CPU 计时关闭时，也会记录拾取/背包事件时间和次数，并计时 NDui 背包 UpdateBag、GetItemInfo、GetItemLevel、任务物品 tooltip 检查，以及 YiboVault:ScanBag。
不记录事件内容、物品 ID 或聊天文本；仅时间与事件名。事件记录最多保留 60 条。
第三方回调已纳入，因此报告的“已测回调”不再表示只有 Yibo；原生 CPU 模式中的 Yibo 合计仍仅包含 Yibo 插件。
Plus 离线背包的局部 SaveBag 函数未被直接包装，不能凭方法计时零耗时排除它。
修正重复 stop/cpuoff 延长 duration 的问题，并在停止时还原继承方法的原始属性状态。

对照优先关闭 Plus 设置的“离线背包”并重载，保留 NDui 和其它功能；随后再对照 NDui 背包增强。
如果背包窗口关闭仍卡顿，NDui cargBags 的可见性检查会跳过常规背包事件，优先检查 Plus 后台缓存及其它插件。
若需要采样：`/reload` 加载更新，`/ypf start` 后连续拾取，`/ypf stop`、`/ypf report`，然后重载写入存档。
原生全插件 CPU 模式仍可选，但因之前观测到采样自身 61.8ms 开销，先用默认方法计时。

## 2026-10-01 静态检查结果

1. `YiboBuilds/Bootstrap.lua` 的 SPELLS_CHANGED 等事件会 ScheduleCapture；`Snapshot:Capture` 无条件采集当前装备。ReadEquipment 遍历装备槽，读取宝石、附魔、工程增强和隐藏 tooltip。法术列表变化未必是装备变化，这条路径存在不必要扫描，并可能受到第三方 tooltip 钩子的影响。尚无实机耗时证据。
2. `YiboVault/Collector.lua` 对 UNIT_INVENTORY_CHANGED 未检查单位，每次扫描当前角色全套装备。非玩家单位更新也可能带来额外工作，需通过实测确定频率和耗时。
3. `YiboBeastPaths/MinimapRenderer.lua` 每 0.15 秒更新；移动后会投影并平滑当前地图完整路线再裁剪，产生临时表及纹理操作。最近保存的主要账号配置 visible=false，隐藏分支直接返回，降低这一路径的嫌疑。存档不能代表当前实时状态。
4. Core Characters:GetCurrent 深拷贝当前角色完整记录，多个事件/扫描路径重复调用；Domains 提交和兼容投影也会复制数据。该开销需计时确认。
5. Core AccountView:RefreshPage 已有窗口可见性检查，未发现关闭主窗口仍持续重绘账号页的问题。邮件扫描限定邮箱打开；未发现正式插件定时强制 collectgarbage。

### 第一轮实机反馈

用户确认关闭 YiboBeastPaths 后仍有同样卡顿，后续不再优先排查该插件。
截图显示 29.2 秒采样、0 次慢调用、4 个长帧（347、487、744、756ms）；
已测回调仅 Characters:GetCurrent 调用 2 次，峰值 0.9ms、累计 1.7ms，构筑 Capture 为 0 次。
这组采样不能由已测构筑扫描解释，但无法排除未测路径或其它插件。
v0.2 修正首领插件全局对象为 YAB，并增加原生全插件 CPU 计时以覆盖局部函数、事件和定时器。

### 第二轮实机反馈（截图）

31.4 秒采样，0 次超过 20ms 的已测调用，3 个长帧：

| 时间 | 长帧 | 邻近 CPU 区间 | Yibo 合计 | 较高的其它插件 CPU |
| --- | --- | --- | --- | --- |
| +18.1s | 295ms | 0.76s | 1.1ms | HandyNotes 68.7ms，NDui 66.9ms，Plater 20.8ms |
| +23.3s | 436ms | 0.60s | 5.5ms | NDui 100.0ms，HandyNotes 32.4ms |
| +28.5s | 670ms | 0.67s | 1.0ms | HandyNotes 27.0ms，NDui 4.4ms，HandyNotes_FPandaria 2.4ms |

构筑 Capture 峰值 19.2ms（1 次），CaptureSlot 18.0ms（2 次）；
首领 PersistDB 峰值 0.5ms、累计 26.2ms（101 次）。
已测 Yibo 路径和原生 Yibo CPU 统计均未显示能解释这些数百毫秒长帧的耗时。
HandyNotes/NDui 在邻近区间较高，但数值不足以解释全部长帧，且存在帧错位及共享库归属，尚不能定责。
探针 CPU 采样自身峰值 61.8ms，增加了诊断开销；下一步应先关闭 scriptProfile，
保留 Yibo，逐组禁用 HandyNotes 及其扩展、再单独对照 NDui，同一角色同一路线观察。
本轮原始存档尚未写出；读取到的文件仍为第一轮，以上数值来源是用户截图。

客户端插件目录已联接到本仓库。最近保存的插件配置含 WeakAuras、AllTheThings 和邮箱探针；并不能据此确认本次卡顿由它们或 Yibo 引起。未修改正式插件、插件启用状态或游戏配置。

若需对照测试，在游戏插件列表暂时禁用全部 Yibo（包括探针），同一角色同一路线观察相近时长。若卡顿消失，再逐项恢复定位。不要删除 SavedVariables。需要覆盖通常出现卡顿的时间跨度，短暂未复现不能视为排除。
