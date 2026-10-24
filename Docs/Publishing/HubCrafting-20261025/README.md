# Core／Crafting／Hub Mists 版本与打包记录

日期：2026-10-25。Core 1.12.9 / Crafting 1.2.2 / Hub 0.6.1。

用户实机确认：附魔目标添加、制作卷轴后的Hub任务完成清理、Crafting来源角标清理。服务器范围的完整跨角色矩阵、中英文完整矩阵及客户端覆盖安装／退出恢复仍保留专项待验；本记录不将离线回放等同于这些客户端验收。

## 源码与验证

安装包及源码包使用单独暂存的本轮源码快照生成，版本在TOC和运行时一致，公开API、技术名、安装目录及SavedVariables身份保持稳定。

- Crafting原7组、EnchantGoals和RealmGoals通过，5275条产物证据核对含319条卷轴映射通过。
- Hub Goals94、GoalSurfaces30、BossGoals19、CustomBossGoals25及实际Core Events／Contracts／Hub缓存与Snapshot／标记联合回归通过。
- Core Contracts90、三个Mists TOC共85个加载Lua语法通过；本快照语言报告未知key0、缺英文0、格式参数不一致0。既有静态目录中文候选未作全插件语言验收声明。
- 干净安装和旧包覆盖新包的离线回放通过；覆盖保留旧文件，没有清空目录。旧路径不进入实际回放加载链，制造完成历史与来源标记状态正确。
- 升级起点：Core 1.12.8、Crafting 1.2.0（本地最近可用发行安装包，迁移前代表版本）、Hub 0.6.0。Crafting 1.2.1只有源码基线，没有找到对应本地发行安装包。
- 覆盖后仍保留YiboCrafting/GoalTargets.lua、YiboCrafting/RecipeCatalog.lua、YiboTaskHub/Goals.lua；当前清单加载Mists/与Common/中的新实现。
- 本轮仅生成本地发布资产，没有上传渠道。

## 包哈希

| 插件 | 版本 | 渠道 | 文件 | SHA256 |
|---|---|---|---|---|
| YiboCore | 1.12.9 | CurseForge | YiboCore-mists-v1.12.9-api13-curseforge.zip | 4351bf1474de93b147e344d7dd28f49a5520a4b3fcdd7d7226b5aa3d2ce61919 |
| YiboCore | 1.12.9 | GitHub | YiboCore-mists-v1.12.9-api13-src.350ece940040-github.zip | dd6743f05b6d4570c837ca8b121fe79c81c28a48b632b55e48132cd5048ddd72 |
| YiboCrafting | 1.2.2 | CurseForge | YiboCrafting-mists-v1.2.2-curseforge.zip | c7f1b2a2a502bddea27f882688c0c9ddceba5515aeef87fd1314cf086edbf20e |
| YiboCrafting | 1.2.2 | GitHub | YiboCrafting-mists-v1.2.2-src.76ae063cfab0-github.zip | c82aab6262b94f7458662f4fa6ccaccb7ae099cd9f252f63347fa7de88e8569b |
| YiboTaskHub | 0.6.1 | CurseForge | YiboTaskHub-mists-v0.6.1-curseforge.zip | 251840063c702dcb3c855221f43e068e9c0fb9d09d20b9995f2123d8e0f11f09 |
| YiboTaskHub | 0.6.1 | GitHub | YiboTaskHub-mists-v0.6.1-src.b67779ed61a2-github.zip | 1fbbb847723aa10cc0050dcf9961d246444ec04dbad126994aaadb8c923a48d1 |

## 可复验材料

构建计划、逐包哈希与回放输出保存在`_NonRelease/HubCraftingRelease-20261025/BuildPlans.json`、`Verification.json`；验证脚本为同目录`Verify-Packages.py`。解压回放目录为`Clean/`和`Overlay/`。本地构建与诊断文件不进入Git提交或安装包，验证脚本与此记录入库。

同时更新三个插件以获得完整修复。旧任一角色目标在Hub编辑、确认服务器后保存。其它安装与验收边界见各插件版本说明及Crafting专项记录。
