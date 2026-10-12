# YiboMounts：YiboCore API 13 接入说明

状态：YiboMounts 1.0.0 发布源码；Core 当前基线为 1.12.0 / API 13，游戏内双语与低版本场景验收仍待完成。

## 职责与依赖边界

- YiboMounts 拥有坐骑目录、来源事实、收藏状态业务判断和 `YiboMountsDB` 设置。
- YiboCore 提供统一设置工作台、会话语言选择与 Locale 资源注册；Core 不读取坐骑目录或 SavedVariables。
- YiboCore 保持可选。Core 未安装或不兼容时，独立来源 Tooltip 使用原有内置双语词条继续工作；Core 设置面板和账号级收藏状态增强不可用。
- 为保持 Core 可选，Locale 文件同时作为 API13 的注册资源和独立运行模式的兼容文本目录。此例外仅覆盖基础 Tooltip 的固定 UI 文案；Core 可用时，显示语言由 `Core.Locale:GetLanguage()` 决定。动态 WoW 名称保持客户端原文，目录中已有的双语来源内容按活动语言选择。

## 能力契约

| 能力 | 提供方 / 消费方 | 最低要求 | 用途 |
|---|---|---|---|
| `localization:1` | Core 提供；YiboMounts 注册并查询 | YiboCore 1.12.0 / API 13 | 账号语言偏好、Tooltip 固定文案、设置面板标题和设置文案 |
| `RegisterSettingsPanel` | Core 提供；YiboMounts 注册 | API v6；本插件统一按 API 13 检查 | 将收藏状态偏好纳入 Core 统一设置工作台 |

资源 owner 为 `YiboMounts`，语言为 `zh` / `en`，key 使用现有稳定 ASCII 名称。Core 注册复制词条，YiboMounts 继续拥有资源定义及业务设置。设置只控制已拥有／未拥有两种收藏状态提示；不保存 Core 语言设置。

## 生命周期与失败行为

- `.toc` 使用 `OptionalDeps: YiboCore`：保证 Core 存在时先加载，不把 Core 变成独立来源 Tooltip 的硬依赖。
- `PLAYER_LOGIN` 检查 Core 已初始化、API v13、`localization:1`、Locale 注册/查询接口及设置注册接口，再重复安全地注册资源、插件与设置面板。
- Core 缺失、未就绪、能力不足或注册失败时给出一次升级/状态提示；Core 设置面板与收藏状态增强停止，基础来源 Tooltip 保持运行。
- 收藏状态仅在设置集成成功后出现；无法可靠判断时不显示。未安装 Core 时，Tooltip 使用客户端语言（zhCN/zhTW 中文，其它英文）；已接入 Core 时使用账号会话语言。
- 当前不向 Core 注册账号页面或入口、不提供跨业务 Service/Provider、不接收其它插件数据。

## 接入位置与验证边界

- `Namespace.lua`：由 Core.Locale 选择已注册词条；无 Core 的独立模式保留既有词条读取。
- `CoreIntegration.lua`：检查 API 与能力、注册 zh/en 资源及设置面板。
- `Bootstrap.lua`：在玩家登录后尝试 Core 集成，再初始化 Tooltip 回调。
- `YiboMounts.toc`：声明可选 Core 加载顺序。

本轮静态核对代码路径与 Core v1.12.0 / API 13 契约；未执行自动化测试或客户端验收。发布前应覆盖 Core 正常可用、Core 缺失、低于 API 13、手动中英文会话语言、统一设置工作台保存，以及未知收藏状态静默等场景。

后续修改设置、Tooltip 文案或坐骑目录显示时，按区域继续核对 CAP-004 与 CAP-009。若独立运行模式终止，重新评估 locale 兼容层并按 Core 依赖规范调整 TOC。
