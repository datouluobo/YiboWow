# MoP 1.3.0 交付记录

日期：2026-10-22。版本：1.3.0-api1；目标：Mists／Interface50504；插件公开API1，最低YiboCore 1.12.1／API13。技术目录YiboMail、SavedVariables YiboMailDB保持不变。

## 范围与实机依据

包含单封／批量退信、二次确认、AH禁用与混选跳过、收件刷新闪烁修复。用户已确认普通单封／批量、确认／取消、金币／COD及退回内容、取消上架AH、拍卖所得单选禁用和混选跳过；本轮刷新修复反馈“已测试”。精确迭代版本与证据限制见[退信验收](Mists-单封与批量退信方案与验收.md)。紫翠玉39705铜历史为已收取，实际钱包到账缺少独立余额证据。

## 交付验证

- 从限定MoP改动的Git暂存快照构建，隔离工作区其它插件、Forever适配及资源归档改动；沿用该快照中的统一构建脚本与配置。安装包、源码归档与最终提交使用相同源码树。
- 11组Lua5.1回归通过：ReturnQueueSpec、ReturnUISpec、CollectionQueueSpec、MailRuntimeSpec、AttachmentReadinessSpec、CollectionLoadingSpec、InboxReleaseSpec、MailAPIConsumerSpec、NativeInboxSpec、RecipientUISpec、TransfersPerformanceSpec。
- TOC闭包、Lua语法、目标／版本校验通过；本地化专项0硬编码候选、0未知key、0中英文格式差异。上述均为离线证据。
- 实际安装包干净加载、从1.2.24覆盖、从1.2.22覆盖的启动模拟通过。1.2.22残留根目录Scanner.lua与Queue.lua保留，实际TOC不再加载它们；收件实现由Mists/InboxUI.lua单次加载，原NativeUI.lua只保留邮箱入口与发件职责。模拟核对设置保留与幂等初始化，不记作真实客户端完整退出恢复。
- 新包仅含Mists运行闭包与资源，不带Forever TOC／运行模块、测试或本地诊断数据；源码包保留本次提交已有的公开源码及文档，不作为玩家安装包。Core确认、当前角色与语言继续复用既有公共能力，无新增版本要求。
- 产物：Builds/YiboMail-mists-v1.3.0-api1-curseforge.zip，以及同源码摘要命名的github源码归档；具体摘要以包内YiboReleaseManifest.json及本地交付证据为准。旧同类包按约定保留在Archive。

## 状态与剩余范围

本次用户授权的交付为版本更新、Git提交／推送及本地打包；渠道上传／GitHub Release另行记录。未完成的语言模式、异常中断、全部AH来源、安装覆盖的真实客户端保存恢复等专项仍见退信验收清单，不能因打包成功标记为全部测试通过或渠道已发布。

离线证据：仓库根目录_NonRelease/Release-Mail-1.3.0/下的Tests.json、Localization.md、PackageValidation.json、构建与交付清单；不随玩家包分发。
