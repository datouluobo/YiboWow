# YiboBuilds Forever 0.1.0 发布记录

2026-11-06：**已发布（用户确认手动上传发布）。** 就绪通知与用户确认日期：2026-11-06。渠道文件ID未提供；以下保留正式包准备记录。

- 包：`Builds/YiboBuilds-forever-v0.1.0-curseforge.zip`
- SHA256：`05f87217fcb7824e8cd8ca4a032bfca0f38503a28f15f572966a9558b76a79d1`；源码及配置摘要：`f59da2c47102fa13f358166167e535751a61d6c52cfb7241341c023cbfc6b0d5`
- 目标：Forever 1.60.1 / Interface16001；最低 Core API13，配套已发布的 YiboCore Forever0.2.1。
- [发布说明](../../YiboBuilds/Docs/Forever-v0.1.0-发布说明.md)

实机：复用头部空槽原生对照、穿回后自动更新。11月6日主手、副手与原生一致；完整退出后独立库保存19槽，重登不手动刷新，两槽一致、无报错。登录会自动重采，重登使用路径与实际落盘分开登记。将实际保存点的19槽ID与观察时间脱敏后在解包环境中验证原生扫描前读回，未执行玩家存档Lua。

构建：已有Forever目标新增正式发布配置；既有源码YiboBuilds_Forever.toc映射为包内默认YiboBuilds.toc。17文件、6个加载引用，运行Lua与已验源码逐字节相同。Mists/Forever构建预检、实际包67项模拟及19槽读回通过。修正统一构建器在严格模式读取可选Core元数据时的缺键问题，并用无该字段的Core构建预检核对；没有重跑MoP功能。

入口与兼容：源码TOC、Lua、Slash、XML及运行时加载/初始化未改。包回放核对实际目标、写库前停止、Core就绪与所需能力、幂等和独立YiboBuildsForeverDB schema1。技术名/存档保持；Mists旧源码入口与安装包未改。Forever首发无上一发行包，正式包覆盖升级不适用。无新增Core能力、业务接入或玩家文本，沿用CAP-001/003/004/007/009/010现有调用。仅声明当前装备快照；共用MoP正常场景复用，不要求重复实机。当前正式ZIP未另行部署或实机登录。

证据：_NonRelease/BuildsForever/Savepoint-20261106 与 Release-20261106。渠道上传时选择Forever1.60.1；本次未上传。
