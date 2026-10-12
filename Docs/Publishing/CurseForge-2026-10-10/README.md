# CurseForge 内容集中补充 · 2026-10-10

状态：**本地双语草稿已整理，尚未修改 CurseForge 后台。** 本目录同时区分 CurseForge 当前发布包基线与仓库当前工作树版本。正文按用户要求以当前工作树功能撰写；工作树中尚未发布或未完成客户端验证的内容，正式发布前必须与最终安装包逐项核对。

覆盖仓库内 14 个已有 CurseForge 项目。YiboTaskHub 仍是未发布工作树插件，因此不作为可下载项目链接；TamerTimer 不属于本仓库。标题、摘要、分类和依赖建议见 [metadata.json](metadata.json)，其中分类仍需作者后台确认。页面正文均为英文在前、中文在后；先介绍 YiboCore 框架和依赖关系，再说明插件用途、相对特点及解决的痛点。

## 页面草稿

| 插件 | CF发布基线 | 当前工作树 | 页面 |
| --- | --- | --- | --- |
| YiboAltoBoss | 2.5.1 | 2.6.0 | [首页说明](descriptions/YiboAltoBoss.md) |
| YiboAutoOpen | 1.2.2 | 1.2.2 | [首页说明](descriptions/YiboAutoOpen.md) |
| YiboBeastPaths | 1.6 | v1.6 | [首页说明](descriptions/YiboBeastPaths.md) |
| YiboBuilds | 1.4.2 | 1.4.2 | [首页说明](descriptions/YiboBuilds.md) |
| YiboCore | 1.11.0 / API v12 | 1.11.0 / API v12 | [首页说明](descriptions/YiboCore.md) |
| YiboCrafting | 1.0.0 | 1.0.7 | [首页说明](descriptions/YiboCrafting.md) |
| YiboCurrency | 0.9.1 | 0.9.1 | [首页说明](descriptions/YiboCurrency.md) |
| YiboLegendary | 2.1.0 | 2.1.0 | [首页说明](descriptions/YiboLegendary.md) |
| YiboMail | 1.2.2-api1 | 1.2.6-api1 | [首页说明](descriptions/YiboMail.md) |
| YiboMounts | 0.8.5 | 0.8.5 | [首页说明](descriptions/YiboMounts.md) |
| YiboQuestBlocker | 3.0.2 | 3.0.2 | [首页说明](descriptions/YiboQuestBlocker.md) |
| YiboReputation | 1.5.2 | 1.5.2 | [首页说明](descriptions/YiboReputation.md) |
| YiboTodo | 1.1.2 | 1.2.0 | [首页说明](descriptions/YiboTodo.md) |
| YiboVault | 1.1.1-api1 | 1.1.1-api1 | [首页说明](descriptions/YiboVault.md) |

正文按当前代码和 README 重写；技术 CHANGELOG 仍记录各版本功能与修复，逐插件更新记录见各插件目录。Crafting、Todo、Mail 等页面中标注为工作树的能力尚未随公开包发布；发布前需要完成相应打包与客户端验证。截图状态和缺图清单见[截图清单](screenshots.md)。SEO 指让标题、摘要和首屏用途更容易被搜索与理解，不承诺下载量或搜索排名。

## 后台设置核对表

| 项目 | 本轮处理建议 | 边界 |
| --- | --- | --- |
| Project Name | 采用上表的品牌名＋具体用途；如希望中文也在搜索卡片中出现，可在末尾追加现有简短中文名 | 不加版本号，不堆叠全部关键词，不改 slug |
| Summary | 使用 metadata 中的一句话英文摘要 | 首句直接说用途；不用作者自述和模糊的“all-in-one” |
| Description | 英文在前，完整中文在后；功能、开始使用、依赖和数据说明分区 | 不写未发布 TaskHub 能力，不用本地相对图片链接粘贴到 CF |
| Categories | 选最相关主类，只有真实相关才补辅助类 | 官方允许主类外最多四个；本轮通常只建议一至两个，不为曝光凑数 |
| Dependencies / Relations | 对照 metadata 和发布包 RequiredDeps；Builds 另需 account-view v2，Mail 另需 services/name-format/item-picker 能力 | Core 最低 API 在正文写清；可选来源不设强依赖 |
| Game versions / Flavor | 大多数项目当前发布包为 MoP Classic 5.5.4；BeastPaths 另有 Retail | 不因改文案勾选未经验证客户端；BeastPaths TOC 另有问题见下 |
| Experimental | 成熟且正式分发的项目核对是否误开 | 官方说明 experimental 不同步常规 CF 生态；未读取后台，不能认定当前误开 |
| Comments / Feedback | 开启项目评论，或替换为作者实际维护的反馈入口 | 草稿默认使用 CF 评论，发布时应确认已开启 |
| Third-party distribution | 保持作者现有选择 | 与本轮搜索优化分开，不再反复开关来试图修复低下载 |
| License | 保留原授权设置 | 不为增长修改许可证 |
| File changelog | 给当前发布文件补对应版本说明，以后与发布包同步 | [发布版功能概览](release-notes.md)可作为补写草稿；不伪造历史修复记录 |

## 截图与发布边界

[截图清单](screenshots.md)记录已检查的画面、公开图库文件名、推荐图序、可用素材和补拍需求。已备好 Todo 两张新增图及中英图注，见 screenshots/。其它截图不是仅按版本号判断过期；未看过画面的项目明确标待目检。

当前检测到 WoW 进程，但未操作游戏或替换正在使用的插件。工作树存在未发布功能，直接截当前界面可能将尚未发布能力展示给用户。补拍应使用与本表匹配的已发布包和 Core，并记录游戏内加载版本。

## 其它发现

- BeastPaths v1.6 发布 ZIP 的中文 TOC 文本存在乱码；Mists TOC 标记 Interface 50400，而公开 CF 文件声明 5.5.4。这是发布包内容和兼容标记核对项，不是 SEO 文案能修复的问题。本轮只记录，不改包或未经验证更改客户端声明。
- QuestBlocker 的 CF 页面本次抓取失败。文案来自 3.0.2 发布包与本地说明；现有后台正文/图库待核对，不能称为已完成在线差异审计。
- Core、Mail、Vault、Currency 的服务/版本要求不能仅从工作树 README 推断；已对照发布包关键初始化代码。Core 新版未发布能力不出现在这些草稿中。

## 证据与验收

- [baselines.json](baselines.json)：发布包路径、SHA-256、TOC 版本、依赖和命令，支持重新核对。
- CF 公开项目链接保存在 metadata；公开页只能证明当时返回的内容，不能代替作者后台设置检查。
- [官方提交指南](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips)：命名、摘要、分类、Experimental、反馈和截图建议。
- 本轮未改运行代码、TOC、授权或 CF 设置；无需游戏功能回归测试。交付核对包含正文数量、发布包版本、命令注册、元数据长度、内部链接与截图文件一致性。

完成发布后，再把 Description、图库和当前文件 changelog 的实际更新状态记录到本目录；本目录目前全部是待发布内容。
