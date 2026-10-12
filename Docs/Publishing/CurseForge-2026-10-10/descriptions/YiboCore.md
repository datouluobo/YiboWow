# YiboCore — Shared Account Framework for Yibo WoW Addons

**Dependencies:** No required Yibo addon. Optional — [LibDataBroker-1.1](https://www.curseforge.com/wow/addons/libdatabroker-1-1) for Broker display.

YiboCore provides the shared account interface and runtime used by the Yibo WoW addon family. Install it alongside the business addons you choose to use. It gives their pages a shared character directory, account window, settings workspace, and entry lifecycle, while each addon continues to own its own feature data and rules.

## What the framework provides

- One account window for pages registered by installed Yibo addons.
- A character directory with realm scope, visibility, filtering, and sorting.
- A shared settings workspace for window behavior, character preferences, page visibility, entries, and fields.
- Core-managed Broker and minimap entry lifecycle, plus optional entries from supported addons.
- Versioned public capability contracts for addons that need to share an action or read-only data.
- Shared character identity and profile infrastructure, without storing addon-specific progress.

## Chinese and English interface

YiboCore supports Chinese and English interface localization. In Core Settings → General, choose **Follow client**, **Chinese**, or **English** for the account. The selected language takes effect after reloading the UI. Core's own interface is adapted for both languages; business addons are migrating their own text progressively, so untranslated addon content may still appear in Chinese.

## Choose the business features you need

These addons require YiboCore. Install only the features you want.

- [YiboAltoBoss](https://www.curseforge.com/wow/addons/yiboaltoboss) — Boss and instance-lockout tracking.
- [YiboBuilds](https://www.curseforge.com/wow/addons/yibobuilds) — Character builds.
- [YiboCrafting](https://www.curseforge.com/wow/addons/yibocrafting) — Recipe records.
- [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) — Account currencies.
- [YiboLegendary](https://www.curseforge.com/wow/addons/yibolegendary) — Legendary progress.
- [YiboMail](https://www.curseforge.com/wow/addons/yibomail) — Mailbox tools.
- [YiboQuestBlocker](https://www.curseforge.com/wow/addons/yiboquestblocker) — Quest blocklists.
- [YiboReputation](https://www.curseforge.com/wow/addons/yiboreputation) — Reputation tracking.
- [YiboTodo](https://www.curseforge.com/wow/addons/yibotodo) — Account to-do tracking.
- [YiboVault](https://www.curseforge.com/wow/addons/yibovault) — Item inventory search.

The following addons work without YiboCore for their basic feature and can use Core for optional settings or integration:

- [YiboAutoOpen](https://www.curseforge.com/wow/addons/yiboautoopen) — Container opening.
- [YiboBeastPaths](https://www.curseforge.com/wow/addons/yibobeastpaths) — Hidden hunter-pet map routes.
- [YiboMounts](https://www.curseforge.com/wow/addons/yibomounts) — Mount-source tooltips.

[YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) can also use [YiboVault](https://www.curseforge.com/wow/addons/yibovault) as an optional source for recorded item-token inventory. [YiboVault](https://www.curseforge.com/wow/addons/yibovault) can use [YiboMail](https://www.curseforge.com/wow/addons/yibomail) as an optional source for mailbox snapshots.

## What makes YiboCore different

YiboCore is the shared framework behind these addons, rather than another addon-specific tracker. A character page uses the same account window, character identity, scope, settings, and entry lifecycle as the other supported pages. This saves players from juggling separate account windows and saves each business addon from rebuilding its own character-management framework.

The framework connects addons through public, versioned capabilities. The addon that owns a feature remains responsible for collecting and interpreting its data; another addon can use an explicitly supported capability when available. This keeps optional integrations useful without making unrelated features depend on one another.

## Getting started

Install YiboCore and the business addons whose features you want. Open the shared account window with `/yco`, or open settings with `/yco settings`. Log in to each character to let the relevant business addons collect that character's data.

## Requirements and data

YiboCore targets Mists of Pandaria Classic (client 5.5.4). Optional Broker display requires a compatible LibDataBroker addon. Business addon pages appear when those addons are installed and registered.

YiboCore maintains the shared character directory and framework settings. Boss, item, mail, reputation, recipe, and other business snapshots stay with the addon that owns them. Some pages show the latest saved observation for offline characters; their own descriptions explain collection and freshness.

## Feedback

Report issues in this project's CurseForge comments with your YiboCore version, client version, the related business addon and its version, and steps to reproduce.

---

# YiboCore — Yibo 系列共享账号框架

**依赖：** 无必需的 Yibo 插件。可选外部依赖 — [LibDataBroker-1.1](https://www.curseforge.com/wow/addons/libdatabroker-1-1)，用于显示 Broker 入口。



YiboCore 为 Yibo 魔兽世界插件提供统一的账号界面和运行时框架。安装 Core 后，再按需安装业务插件。Core 为各业务页面提供共享角色目录、账号窗口、设置工作台和入口生命周期；具体业务数据与判断规则仍由相应插件负责。

## 框架功能

- 在同一个账号窗口打开已安装并注册的 Yibo 业务页面。
- 统一角色目录、服务器范围、角色显隐、筛选与排序。
- 统一设置工作台，管理窗口、角色偏好、页面显示、入口和字段。
- 由 Core 管理 Broker、小地图入口及支持插件的可选入口。
- 通过带版本声明的公开能力契约连接确有需要的跨插件操作或只读数据。
- 提供共享角色身份和档案基础设施，不保存业务插件专属进度。

## 中英文界面

YiboCore 界面支持中文和英文。在 Core 设置 → 通用中，可为账号选择“跟随客户端”“中文”或“English”；重载界面后生效。Core 自身界面已完成中英文适配；业务插件正逐步迁移自有文本，尚未适配的内容可能仍显示中文。

## 按需安装业务功能

以下业务插件需要 YiboCore；只安装你需要的功能即可。

- [YiboAltoBoss · 首领与副本锁定](https://www.curseforge.com/wow/addons/yiboaltoboss) — Boss and instance-lockout tracking。
- [YiboBuilds · 角色构筑](https://www.curseforge.com/wow/addons/yibobuilds) — Character builds。
- [YiboCrafting · 专业配方记录](https://www.curseforge.com/wow/addons/yibocrafting) — Recipe records。
- [YiboCurrency · 账号货币](https://www.curseforge.com/wow/addons/yibocurrency) — Account currencies。
- [YiboLegendary · 传说装备进度](https://www.curseforge.com/wow/addons/yibolegendary) — Legendary progress。
- [YiboMail · 邮件管理](https://www.curseforge.com/wow/addons/yibomail) — Mailbox tools。
- [YiboQuestBlocker · 任务屏蔽](https://www.curseforge.com/wow/addons/yiboquestblocker) — Quest blocklists。
- [YiboReputation · 声望追踪](https://www.curseforge.com/wow/addons/yiboreputation) — Reputation tracking。
- [YiboTodo · 账号待办](https://www.curseforge.com/wow/addons/yibotodo) — Account to-do tracking。
- [YiboVault · 物品库存搜索](https://www.curseforge.com/wow/addons/yibovault) — Item inventory search。

以下插件的基础功能无需 YiboCore；安装 Core 可获得可选设置或集成。

- [YiboAutoOpen · 容器自动开启](https://www.curseforge.com/wow/addons/yiboautoopen) — Container opening。
- [YiboBeastPaths · 隐藏猎人宠物路线](https://www.curseforge.com/wow/addons/yibobeastpaths) — Hidden hunter-pet map routes。
- [YiboMounts · 坐骑来源提示](https://www.curseforge.com/wow/addons/yibomounts) — Mount-source tooltips。

[YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) 可选使用 [YiboVault](https://www.curseforge.com/wow/addons/yibovault) 已记录的物品代币库存；[YiboVault](https://www.curseforge.com/wow/addons/yibovault) 可选使用 [YiboMail](https://www.curseforge.com/wow/addons/yibomail) 的邮箱快照。

## 与同类插件相比

YiboCore 是这些业务插件共享的框架，本身不再重复做一套首领、物品或任务追踪。各页面共用账号窗口、角色身份、范围设置和入口管理，玩家不必在多个插件各自的账号窗口之间切换，业务插件也无需重复实现角色管理基础功能。

插件通过公开且带版本的能力接口进行协作。业务数据仍由真正负责该功能的插件采集与解释；其它插件仅在相应能力可用时使用它。这让可选联动能工作，同时不把无关功能绑成强依赖。

## 开始使用

安装 YiboCore，再安装需要的业务插件。使用 `/yco` 打开统一账号窗口，使用 `/yco settings` 打开设置。登录各角色后，对应业务插件会采集各自需要的数据。

## 运行需求与数据说明

YiboCore 面向熊猫人之谜经典版（客户端 5.5.4）。显示可选 Broker 入口需要兼容的 LibDataBroker 插件。安装并完成注册后，业务页面会出现在统一账号窗口中。

Core 管理共享角色目录与框架设置；Boss、物品、邮件、声望、配方等业务快照仍由对应插件保存。离线角色的页面可能显示最近一次保存的观测；采集方式与数据时效以各业务插件说明为准。

## 问题反馈

请在本项目 CurseForge 评论中提供 YiboCore 版本、客户端版本、相关业务插件及其版本和复现步骤。
