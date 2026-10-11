# API v13：语言服务

状态：1.12.0 / API v13 工作树已实现；客户端验收待完成，未发布。最低能力为 `localization:1`，保留现有 API v12 及更早接口。

## 职责与生效时序

Core 负责语言选择、账号偏好、字符串查询、格式化、中文回退与缺失报告；各业务插件拥有自己的翻译资源，业务数据和目录 ID 继续由来源插件维护。

`YiboCoreDB.settings.language` 保存 `auto` / `zh` / `en`，首次使用或无效值归一为 `auto`。自动模式下 zhCN、zhTW 使用中文，其他客户端使用英文。保存的是模式，不是自动判断结果。

Core 自身的 TOC 文件可能早于 SavedVariables 恢复执行，所以模块级公共文本表使用 `Locale:Bind` / `BindText` 保留表引用并延迟修正。`Core:Initialize()` 在 Database 初始化成功后解析会话语言、刷新内置元数据，然后标记 Core 就绪并发出 `CORE_READY`。依赖 Core 的业务插件在自身文件加载、注册页面前即可读取有效语言；Core 初始化失败时应等待就绪或停止依赖功能。

设置变更只写账号偏好；本会话语言与已注册文本均不改变。显示与入口页提供待生效提示和玩家主动点击的“重载界面”。偏好改回本会话模式时取消待生效状态。重新登录或重载后重新解析。

## 公共接口

| 接口 | 输入 / 返回 / 失败行为 |
|---|---|
| `Core:HasCapability("localization", 1)` | 消费前检查最低契约版本；同时检查 `CheckAPIVersion(13)` |
| `Core.Locale:Register(owner, language, resources)` | owner 为插件技术名；language 为 zh / en；resources 为稳定 key → 非空字符串表。复制资源到 Core 所有的目录；相同内容可重复注册，同 owner/语言/key 的不同内容抛错；先校验后写入 |
| `Core.Locale:GetLanguage()` | 返回本会话 zh / en；正式运行就绪后保持不变 |
| `Core.Locale:Get(owner, key, ...)` | 返回字符串；可用 `string.format` 参数。英文缺失回退中文；英文格式化失败尝试中文。所有资源都缺失时返回可诊断的 `[owner:key]`，不抛出 UI 错误 |
| `Core:Text(key, ...)` | Core 自身资源的快捷入口，相当于 owner=YiboCore；业务插件使用自己的 owner |
| `Core.Locale:GetPreference()` | 返回保存模式 auto / zh / en，不是会话语言 |
| `Core.Locale:SetPreference(mode)` | 返回 true；非法模式返回 false, invalid-language-mode；数据库未就绪返回 false, not-ready；不重载、不改变会话语言 |
| `Core.Locale:IsReloadPending()` | 保存模式与本会话启动模式不同则为 true |
| `Core.Locale:GetMissingEnglish(owner?)` | 返回按 owner/key 排序的新数组，每项 `{owner,key}`。扫描已注册的全部中文资源并合并查询中发现的未知 key；可过滤 owner；晚注册英文后清除已补齐项 |

资源注册只声明文本，不提供业务 Service，不读取业务 SavedVariables。不得把显示文本、翻译 key 或格式化结果用作角色身份、业务主键或操作地址。

## 插件语言与客户端 Locale

`GetLocale()` 是 WoW 的真实客户端语言，语言服务不会覆盖它。`Core.Locale:GetLanguage()` 是插件显示语言，返回 `zh` / `en`；本契约没有 `Core:GetLanguage()` 方法，也不返回 `enUS`。

例如 zhCN 客户端选 English 并重载后：

```lua
GetLocale()                      -- "zhCN"
Core.Locale:GetPreference()      -- "en"
Core.Locale:GetLanguage()        -- "en"
```

此时物品、技能、NPC 等动态 API 名称仍是客户端原文。业务只能用会话语言选择自有资源，不能用它判断原生 API 名称语言或修改数据身份。

正式账号设置已满足日常插件语言覆盖需求，无需新增 Locale Override。正式设置＋重载用于已迁移区域的完整初始化验证；`/ylp en` 仅作非发布 Core 快速预览，不保证重建业务插件的模块级文本。当前业务插件尚未接入，统一语言设置不等于全系列翻译完成。

中文客户端手动 English 能验证插件自有文本和布局；真实 enUS 仍须验证原生名称、Tooltip、字体、匹配及业务行为，英文客户端手动中文还须验证中文字体覆盖。详细验证路径见 [实施与验收记录](../../Docs/Core系列中英文客户端适配-实施与验收记录.md)。

## 最小业务接入

```lua
local Core = _G.YiboCore
if not Core or not Core:CheckAPIVersion(13)
    or not Core:HasCapability("localization", 1) or not Core:IsInitialized() then
    -- 使用插件的启动错误提示通道明确要求升级/修复 Core，并停止初始化。
    return
end
Core.Locale:Register("YiboExample", "zh", { ["PAGE.TITLE"] = "示例" })
Core.Locale:Register("YiboExample", "en", { ["PAGE.TITLE"] = "Example" })
local function T(key, ...) return Core.Locale:Get("YiboExample", key, ...) end
-- TOC 中先加载以上两份资源，再加载页面注册文件。
-- title = T("PAGE.TITLE")
```

业务接入须在自己的初始化路径明确提示升级 Core，不静默继续，也不保留并行本地语言实现。未迁移插件保持已有最低版本，不因 Core 增加服务而统一升级。上例为契约演示，不替代插件原有启动与错误展示机制。

## 资源规范与边界

- key 使用稳定 ASCII 语义名，按区域组织，例如 `PAGE.TITLE`、`SETTINGS.RELOAD`。已有 `CORE.*`、`LANGUAGE.*`、`FORMAT.*` key 不随翻译调整重新生成；带数字消歧的历史 key 同样稳定。
- 中文和英文资源使用相同 key 和格式参数类型/顺序；完整句子优先使用 `%s` / `%d` 插值，避免新增语序固定的片段拼接。
- WoW API 返回的名称保持客户端原文。专业采集回退的原生名称别名是输入匹配资料，持久化身份使用 skill-line ID；不随插件语言翻译。
- 自定义文本、历史快照不改写；TOC Title-zhCN / Title-zhTW 仍由客户端选择，独立于 Core 偏好。
- `Bind` / `BindText` / `RefreshBindings` 用于 Core 内置显示元数据的初始化。业务插件正常依赖初始化后的会话语言，不依赖这些内部绑定细节。
- 正式服务没有强制预览命令。临时语言覆盖只在 `_NonRelease/YiboLocaleProbe` 中实现，不保存、不随正式包发布。

## 验证与迁移

自动化验证与客户端待验范围见 [实施与验收记录](../../Docs/Core系列中英文客户端适配-实施与验收记录.md)。目前只确认 Core 提供服务与公共文本接入；业务插件尚未接入。后续每次新增或修改玩家可见区域时迁移该区域并更新 CAP-009 台账。

2026-10-12 设置路径：语言选择位于 Core 常规设置 → 通用；保存偏好后仍由玩家主动重载生效。
