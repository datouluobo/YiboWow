# Forever 0.2.0-api1 打包与提交

2026-11-19，按用户要求提交、推送源码并通过统一构建器打包。上个发布版本为Forever 0.1.5-api1；本轮0.2.0-api1仍为待实机验收构建，打包不代表上传渠道或发布通过。MoP版本保持1.3.5-api1，本轮只输出Forever玩家包及全目标源码归档。

37组Mail/Forever Spec、Mail135项/Vault3145项Smoke、Core物品元数据33项与三目标双语言档案回归通过。本地化报告重新生成并查看，缺英文/格式参数不一致为0；Mail3项既有候选，11未知key属其它插件。

四个Mail/Vault双目标候选的实际载荷、单目标清单和当前运行字节校验通过；干净安装、Forever0.1.5及MoP1.3.5/1.3.4保留旧文件覆盖、货币候选双目标覆盖共7组离线回放通过。原始证据位于本机 `_NonRelease/MailForever/Version020Candidate-20261119/Run-35ihz6_8/Results.json`，不随玩家包/源码包分发；后续仅清理CollectionRuntime文件末尾空行，无业务变更。正式包最终摘要登记于工作区无限服验收台账。

配套源码包含Core item-resolver:2物品元数据能力及金币列修复、Vault Forever公开邮件在途消费。Mail仍要求Core API13及既有能力版本；仅API13编号相同不足以证明旧Core满足item-resolver:2。本次不另行打包Core/Vault，不改变它们的发行状态。

加载边界沿用专项记录：源码YiboMail_Forever.toc、YiboMail_Mists.toc，目标玩家包默认YiboMail.toc；保留写库前目标身份/Core就绪/API与能力门槛、单次初始化和注册；YiboMailForeverDB/YiboMailDB及schema1不变；旧路径残留不进入当前链。构建器校验目标、Interface、引用和包内容。Core公共能力接入按本轮专项及CAP台账，无因打包新增接口。

新收件人/自动主题、规则寄、非空及货币附件、原生金币/COD、拍卖/退信样本、双角色送达抵消、语言、完整退出恢复及当前玩家包真实覆盖仍待。已验局部见对应手测与修复记录；不宣告整插件可发布。
