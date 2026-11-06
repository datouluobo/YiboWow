# YiboCore Forever 0.2.1 发布记录

日期：2026-11-05（北京时间）。状态：**已发布（用户确认手动上传发布）**。就绪通知日期：2026-11-05；发布反馈日期：2026-11-05。

渠道：[CurseForge YiboCore](https://www.curseforge.com/wow/addons/yibocore)。公开文件列表请求返回403，未独立取得文件ID或直达链接。下方保留正式包准备阶段记录。

## 产物

- 文件：`Builds/YiboCore-forever-v0.2.1-api13-curseforge.zip`
- 版本：Forever0.2.1 / API13；Interface16001，schema11。
- 大小：1526342字节。
- ZIP SHA256：`3649cd279a012533e6e38ef9a45a73bb3498b8092f89ad5852ff405c21e21827`。
- 源码/构建配置SHA256：`01935f004659e2e03ad2231de40129542bafb9fc4964a30ba8f8f6e0d37a61e5`。
- 发布说明：`YiboCore/Docs/Forever-v0.2.1-发布说明.md`；CF描述稿：`YiboCore/CURSEFORGE_DESCRIPTION.md`。
- 旧0.2.0包已由统一构建器归档至`Builds/Archive/YiboCore/`；本轮未生成GitHub源码包，Mists/Retail包保持。

## 声明范围与测试结论

Core基础设施：完整双名、GUID目录、身份/位置和专业档案、统一窗口/角色档案/设置、入口与悬停、角色显示与等级过滤、语言和窗口设置。

用户已确认当前无限客户端Core就绪/独立存档/单次初始化、页面、完整姓名、小地图/预览和战斗关闭、等级过滤、reload与完整退出恢复、手动English/中文/auto及英文布局复验。按用户明确要求，MoP正常且未反馈异常的共用行为复用既有证据，后续实际出现问题再定位，不追加重复测试。实际客户端证据为1.60.1.70790、Interface16001、project18、zhCN。

最终版仅将已验候选的Forever版本标识0.2.0调整为0.2.1；59个运行Lua逐项比对，功能字节一致。相对候选的包差异恰为Target.lua版本、默认TOC的版本/说明和发行清单。新包默认TOC加载引用与已验候选完全一致，不把新包本身记为已另行游戏实测。

## 构建与包检查

统一构建器Forever目标ValidateOnly与正式构建完成；构建后源码/配置摘要再次核对一致。73个文件、60项唯一加载引用；仅默认YiboCore.toc，包含Forever和所需共享实现，不含其它目标、WTF、探针。版本/API/Interface/存档声明及版本索引正确。现有Ace3/LDB通知和UPSTREAM来源说明逐字节保留。Core563个语言键无缺失英文、未知键、重复或格式差异；27项候选人工复核为未进入Forever玩家链的Hint和Mists专业映射。

TOC源为YiboCore_Forever.toc、玩家实际加载名YiboCore.toc；技术名/安装目录YiboCore，SavedVariables为YiboCoreForeverDB；schema11与GUID保持。Core自身无强依赖，消费者API/能力门槛沿用。误目标写库前停止、Core就绪与幂等、覆盖引用/单次加载复用既有与本轮适用证据，本次未改变这些机制。无限服没有上一正式发行版，既有候选覆盖已完成离线核对，通用正常升级复用用户认可的MoP证据。

## 渠道准备

- CurseForge项目：1653084，[YiboCore项目页](https://www.curseforge.com/wow/addons/yibocore)。本轮仅只读核对项目。
- 目标/flavor：Forever / forever；游戏版本名称1.60.1；上传类型Release。
- 数字gameVersions ID属于上传时的平台解析字段。公开legacy版本接口返回403，尚未解析；没有使用猜测ID，也未执行上传。上传时按当前平台Forever1.60.1列表选择/解析。
- 本轮准备包与说明，不操作渠道描述、上传、提交或推送。

当前客户端仍安装此前0.2.0候选普通目录，原源码联接与4份存档备份保留于Deployment-20261105-122535记录所列路径；本次没有改写游戏安装目录或存档。正式0.2.1包可按发行说明覆盖代码目录使用。

原始结果：`_NonRelease/CoreForeverRelease-20261105/`中的Build-Validation.json、Build-Result.json、Accepted-Runtime-Comparison.json、Final-Package-Checks.json。

