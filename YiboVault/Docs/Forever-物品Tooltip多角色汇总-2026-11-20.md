# Forever 物品 Tooltip 多角色汇总

2026-11-20：Forever 0.6.5-api1 代码完成，实机待验。原生物品提示复用共享 Tooltip，以 Core 的角色准入和排序展示当前服务器的角色缓存数量；当前角色通过既有查询获取，其他角色读取 Vault 自己保存的背包、装备、银行、邮件和拍卖快照。仅展示已有快照，不推算缺失数据；邮件提供者不可用时沿用 Vault 已有缓存。公会数据仍限制当前角色可查看的公会及页签，不推断离线角色公会权限。公开 `vault.items` 查询仍只接受当前角色。默认当前服务器；底层支持既有 all 范围设置，Forever 尚无切换该选项的设置界面。

职责单元为 Tooltip 及其 Forever 范围和快照适配；共享显示同时影响 Mists，已运行共享 Tooltip 专项及双目标构建预检。复用 Core API13、localization:1、character-name-format:1、account-character-admission:1 等现有检查，无新增 Core 公共能力接入或迁移台账变化。

源码使用 `YiboVault_Forever.toc`，玩家包由统一构建器输出 `YiboVault.toc`。身份及 Core 就绪和能力检查先于数据库初始化；重复初始化不会重复安装 Tooltip。存档继续使用 `YiboVaultForeverDB`，无 schema 改动。旧 TOC、XML 与间接引用未新增，目标清单仅加载新适用链；旧文件保留覆盖的实际客户端行为仍待验证。构建预检核对目标、Interface、引用与包内容计划，已生成 Forever 候选玩家包，尚未发布。

离线：真实 Core/Forever 清单模拟 3152 项通过，包括双角色数量、默认服务器范围、重复安装及公开查询边界；共享 Tooltip 专项和 Mists／Forever 构建预检通过。待实机完整退出启动后核对原生和 Vault 物品格 Tooltip、两个角色及来源数量、更新／重载、语言、干净安装和保留旧文件覆盖、完整退出恢复。无此证据不判定发布就绪。
