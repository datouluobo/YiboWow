# YiboBeastPaths Core API13 接入与验收

2026-10-28：v1.8.3将现有Core维护设置与四页签维护页开放到Retail，Mists沿用同一共享适配器。Core最低门槛按API13及所需能力／实际方法检查，不以Mists的1.12.x版本号限制Retail0.1.0。两目标真实Flavor入口联合测试988项、中英文四页签／91动作模拟、默认地图上下文及26文件语法通过，新增Retail交互待实机。当前以本段及[修订记录](Retail-Core维护接入-1.8.3.md)为准；下方Mists-only与Mainline不注册的表述是v1.8历史范围。

> 文档状态更新（2026-10-16）：现有地图与Core维护功能已由用户确认实机收口；本文原测试清单和版本记录保留证据，旧“待验收”由当前确认覆盖。后续宠物采集／四色识别见[DEV-002](../../Docs/后续开发任务清单.md)，发行见[状态总览](../../Docs/仓库当前状态总览.md)。

审查日期：2026-10-14。插件工作树版本 v1.8；固定基线是本仓库 `YiboCore/Bootstrap.lua` 声明的 **1.12.1 / API13**。API 文档中 1.12.0 为语言服务首批版本，运行接口与能力版本仍是判断依据。状态：适用公共调用代码完成；本轮实机确认小地图移动平滑，Core 维护页双语及完整交互仍待验收，未发布。

## 依赖、职责与生命周期

三份 TOC 继续使用 `OptionalDeps: YiboCore`。BeastPaths 是地图路线工具，无角色账号快照；Core 是可选的 Mists 维护宿主。Mainline 不注册维护页或设置，所有客户端基础路线显示保持独立运行。

维护增强初始化前检查 API13、`localization:1`、`basic-input:1`、`account-view:2`、`account-surface-budget:1`、Core 就绪状态以及实际使用的注册、页面、设置、主题和事件方法。缺失或不兼容时停止该增强，不构建本地替代窗口；`/ybp debug` 明确提示需要升级，已安装 Core 时登录也报告增强不可用。Core 缺失不阻断地图绘制。

适配器监听插件加载、登录和公开 `CORE_READY`；等待订阅在成功注册后移除，重复注册不产生第二份设置或页面。关闭维护模式注销业务页，保持设置入口；页面注册失败恢复关闭状态。Core 隐藏页面时取消导出框焦点及该插件确认弹窗，避免在隐藏页面接受待确认操作。

Core 负责窗口壳、导航、设置宿主、滚动、公共输入与语言选择。BeastPaths 继续拥有路线、脚印、参数、校验与 `YiboBeastPathsDB` / `YiboBeastPathsDebugDB`；不新增跨业务 Service 或 Provider，不读取其它业务插件实现或 SavedVariables。

## 适用能力核对

| 台账 | 处理与调用范围 |
|---|---|
| CAP-001 名称格式化 | 不适用：显示对象是宠物、地图与坐标，没有角色名称 |
| CAP-002 基础输入 | CoreDebugView 多行导出框使用 `UITheme:CreateInput`；maxLetters=0 不限长度、Enter 换行，保留 Core 的 IME、Esc 和隐藏焦点生命周期。旧 DebugCalibrator 独立布局不由 Core 页面构建 |
| CAP-003 物品能力 | 不适用：输入是路线参数，不是物品 |
| CAP-004 页面／入口／设置 | Mists 维护页和业务设置复用 Core；GetSurfaceMetrics 使用 surfaceAvailableHeight。维护操作仅由 Slash 触发，无账号快照、Broker、小地图入口或内置条；游戏小地图路线绘制是业务图层。无需 account-entry／builtin-entry-bar 能力 |
| CAP-005 跨业务连接 | 不适用：没有跨业务查询、聚合或操作需求；CORE_READY 复用公开事件 |
| CAP-006 首次提示 | 不适用：维护模式由玩家显式开启，无新增首次提示需求 |
| CAP-007 轻量身份 | 不适用：没有跨角色身份读取 |
| CAP-008 主动添加 | 不适用：没有角色驯服完成采集或可投影的任务目标 |
| CAP-009 语言服务 | Core 维护页的所有控件、页签、状态、确认及共享错误，维护设置、地图开关／按钮悬停和命令提示使用自有 zh/en ASCII key；Core 可用时通过 Core.Locale:Get 查询 |

## 语言兼容边界

`Locale.lua` 使用同一份资源声明注册 Core 目录并供独立地图功能使用。**独立模式兼容例外**：未安装 Core、Core 旧版或尚未就绪时，基础地图开关和命令提示按真实客户端 zhCN/zhTW→中文、其它→英文解析同一资源表；这保证 OptionalDeps 的独立产品契约。Core 就绪且具备 API13 / localization:1 后使用 Core 会话语言，不保存第二个语言设置，也不为 Core 维护页保留旧版本地实现。若未来产品改为强依赖 Core，再移除独立解析路径。

静态宠物／路线说明目录、原生地图匹配别名、小地图诊断报告、生成的 Lua 导出注释和未使用的旧独立调试布局保留原范围；它们不作为本轮 Core 控件文案已翻译的证据。游戏 API 名称、历史参数及用户脚印备注不改写。后续修改对应区域时继续按区域迁移。当前不宣称全插件英文目录完成。

## 验证证据与客户端清单

从仓库根运行：

```powershell
lua YiboBeastPaths/_NonRelease/Tests/Core13IntegrationSpec.lua
lua YiboBeastPaths/_NonRelease/Tests/CoreDebugViewSmoke.lua zh
lua YiboBeastPaths/_NonRelease/Tests/CoreDebugViewSmoke.lua en
lua YiboBeastPaths/_NonRelease/Tests/DebugContextSmoke.lua
./Tools/Test-LuaSyntax.ps1 -Addon YiboBeastPaths
python Tools/Check-Localization.py --addon YiboBeastPaths --output _NonRelease/Localization/BeastPaths-Core13-Report.md
```

Core13IntegrationSpec 使用真实 Core Locale 模块验证缺失、旧版、缺能力、未就绪、晚就绪、重复注册、关闭重开、注册失败回滚、表面高度预算、中文客户端手动英文以及资源格式一致性。双语 CoreDebugViewSmoke 覆盖四页签、91 个动作绑定、600/620/760 等宽度排版和多行公共输入。DebugContextSmoke 验证当前区域默认与地图选择跟随。TOC 的 26 个 Lua 文件通过 Lua 5.1 语法检查。

静态报告有 254 个硬编码候选，需要按上面的保留范围分类；缺英文／未知键／格式差异为 0。全仓检查器尚不识别 `ns.Text` / 本地 `T` 包装，因此显示 0 个语言引用；语言接入证据以真实 Core Locale 运行检查与源码审查为准，不用该计数推定覆盖率。

客户端待验收：

- Mists 中文、enUS、中文客户端手动英文及英文客户端手动中文，分别重载验证会话语言。
- `/ybp debug` 打开 Core 设置，启用维护、四页签切换、关闭再开启、窄屏与安全高度、长英文说明和按钮。
- 超过 255 字符的导出、换行、全选复制、输入法、Esc、隐藏页清焦点、关闭页取消待确认删除。
- Core 缺失／旧版时基础路线正常，维护提示升级；Mainline 不出现维护页。
- 世界地图／小地图路线显示、当前位置选宠、脚印编辑／确认、保存与重载保持原行为。

客户端全部通过后才将 CAP-002／004／009 从部分接入更新为已验收。
