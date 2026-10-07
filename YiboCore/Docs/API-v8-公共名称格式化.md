# API v8：公共名称格式化

实施源码版本：YiboCore **1.7.0 / API v8**。渠道发布状态：尚未上传。新增能力 `character-name-format:1`，保持旧 API 与业务插件调用兼容。迁移进度见 [公共能力迁移台账](Core-公共能力迁移台账.md) 的 CAP-001。

## 职责与公开接口

Core 统一负责原名／短名选择和名称中的服务器显示策略。业务插件提供角色或联系人身份、显示策略与参照服务器，继续负责联系人备注、职业色、文本转义、布局、地址解析和业务操作。

```lua
local text, errorCode = Core.Characters:FormatName(identity, options)
```

成功返回显示文本；失败返回 `nil, errorCode`。输入为结构化身份，不解析“角色名-服务器”字符串，不按名称查找角色，不导入联系人，不修改输入、显示偏好或业务地址。

| 参数 | 约定 |
| --- | --- |
| identity | 角色记录或联系人 `{ name = "原名", realm = "服务器" }` |
| identity.name | 必须为非空字符串；输入原样用于显示，不负责地址合法性校验 |
| identity.realm | 可省略或为空字符串；存在时必须为字符串，输出保留原始拼写 |
| identity.id | 可省略；`nameMode="short"` 时仅以调用方提供的 Core 角色 ID 查询 Core 显示偏好。没有偏好时回退原名，不按 name／realm 推测 ID |
| options | 可省略的表；不会被接口修改 |
| options.nameMode | `original`（默认）：原名；`short`：优先 Core 自定义短名，未设置时回退原名，不自动截取 |
| options.realmMode | `omit`（默认）：只显示名称；`full`：名称-服务器；`sameRealm`：与参照服务器相同则只显示名称，不同则追加服务器 |
| options.referenceRealm | `sameRealm` 模式必须明确提供非空白字符串；其它模式不使用 |

两项策略可独立组合。精确身份提示、删除及人工确认通常使用 `nameMode="original", realmMode="full"`；紧凑显示可选择 `short`，由 UI 提供真实完整身份提示。

## 服务器与缺失数据

- `sameRealm` 比较忽略服务器字符串中的空白和 ASCII 大小写，兼容 `Silver Moon` 与 `SilverMoon`，但不修改输出拼写。不把连接服务器、不同名称的服务器或别名自动视为同服。
- 参照服务器必须由调用方明确提供。通讯录可使用当前登录角色服务器；所选单服账号页可使用所选服务器。接口不暗中读取当前角色，也不将 `context.scope` 当作服务器名称。
- `full` 缺少服务器时返回 `missing-realm`，避免将不完整身份误当完整身份。`omit` 可处理只有名称的联系人；`sameRealm` 遇到缺少服务器的联系人会返回原名／短名，不伪造服务器。
- Core UI 继续自行提供“未知角色／未知服务器”等占位文本，再交给接口格式化。调用方必须根据场景处理错误，不得把失败或未知身份写成业务地址。
- 返回未着色、未转义的显示字符串。调用方仍须在 WoW 富文本环境中转义外部名称，添加职业色或备注；不能将显示文本用于邮寄、匹配、存档键或角色关联。

错误码：`invalid-identity`、`invalid-options`、`invalid-name-mode`、`invalid-realm-mode`、`missing-name`、`invalid-realm`、`missing-realm`、`missing-reference-realm`。

## 目录外联系人与示例

```lua
local contact = { name = "联系人", realm = "Silver Moon" }
Core.Characters:FormatName(contact)
-- 联系人
Core.Characters:FormatName(contact, { nameMode = "short", realmMode = "full" })
-- 联系人-Silver Moon：未提供 Core 角色 ID，短名回退原名
Core.Characters:FormatName(contact, {
    realmMode = "sameRealm", referenceRealm = "SilverMoon",
})
-- 联系人
Core.Characters:FormatName(contact, {
    realmMode = "sameRealm", referenceRealm = "OtherRealm",
})
-- 联系人-Silver Moon

Core.Characters:FormatName(character, { nameMode = "short" })
-- 有 Core 自定义短名则显示短名，否则显示原名
Core.Characters:FormatName(character, { nameMode = "original", realmMode = "full" })
-- 真实角色名-服务器
```

无角色 ID 的联系人格式化不依赖角色目录，Core 数据库未初始化时也可使用。已知 ID 的短名读取在偏好尚不可用时回退原名；后续调用立即读取最新偏好。格式化不保留缓存、不保存快照时间、不引入刷新事件或业务重置规则。已存在的 `CHARACTER_DISPLAY_UPDATED` 通知继续用于需要重绘短名的视图；订阅清理沿用 Core.Events 契约。

## 兼容与渐进接入

- `Core.Characters:GetDisplayName(character, "full")` 继续只返回原始角色名，`"short"` 的既有行为保持不变，旧业务插件无需提高最低版本。
- `Theme:SetCharacterHeader` 保留参数、`options.name`／`realm` 覆盖优先级、旧 `nameMode="full"` 语义、单服／所有服务器副标题、职业色与状态提示；完整身份 tooltip 和名称组合交给新接口。宽度测量保留原名与既有字号、列宽上下限，完整行身份直接测量格式化后的字符串。
- Core 已接入共享表头及测量、角色档案身份字段、缓存删除确认、设置工作台排序与短名管理标签。共享表头内部使用新接口不代表业务插件已迁移至新契约。
- 业务插件以后修改对应显示功能时，按 AGENTS.md 更新最低要求，并同步更新台账。本轮没有改动业务插件，也没有修改角色数据结构、旧键或短名存档。

接入新接口前检查版本、能力与方法；失败时提示升级 Core 并停止依赖此能力的初始化或操作：

```lua
local core = _G.YiboCore
if not (core and core.CheckAPIVersion and core:CheckAPIVersion(8)
    and core.HasCapability and core:HasCapability("character-name-format", 1)
    and core.Characters and type(core.Characters.FormatName) == "function") then
    Addon:Print("需要升级 YiboCore：公共名称格式化要求 API v8。")
    return
end
-- 对依赖 Core 的业务插件，TOC 继续声明 RequiredDeps: YiboCore。
-- 初始化注册时将 requiredAPI 设为 8，并检查 RegisterAddon 的返回结果。
```

## 验证

从仓库根目录运行：

```powershell
lua YiboCore/_NonRelease/Tests/CharacterNamesSpec.lua
./Tools/Test-LuaSyntax.ps1 -Addon YiboCore
lua YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua
```

名称契约测试覆盖原名／短名及服务器策略组合、目录外联系人、未初始化与缺失数据、错误返回、输入和偏好无写入、短名更新事件、旧 API 版本检查及 GetDisplayName 语义；共享表头集成覆盖业务名称／服务器覆盖、独立副标题、真实身份 tooltip、状态提示、名称测量与档案字段。现有 Currency 测试作为旧 API v7 控件回归。

游戏内尚未验收：核对多个旧业务插件的主窗口与悬停表头、所有服务器／单服切换、短名修改即时刷新，以及 Core 档案、设置标签和删除确认中的真实完整身份。
