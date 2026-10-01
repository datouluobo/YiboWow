# YiboCrafting 阶段 0 探针

这是独立于正式插件的非发布、只读插件。源码统一放在仓库根目录 `_NonRelease/YiboCraftingStage0Probe/`，并以同名目录联接到 `World of Warcraft/_classic_/Interface/AddOns/YiboCraftingStage0Probe/`（以实际 MoP Classic 安装目录为准）。正式 `YiboCrafting` 插件无需安装。

命令只有 `/yct`：`scan` 采当前专业列表，`recipe <配方 ID>` 采产物与材料，`archaeology` 只读采考古项目，`status` 查看数量，`events on|off` 控制事件记录。登录和打开专业窗口时也会自动采样，并标记本人候选、链接或公会来源；探针不打开窗口、不改变过滤、不执行制造或学习操作。事件只记录名称与最多三个数字/布尔参数。

退出游戏或 `/reload` 后，诊断数据写到 `WTF/Account/.../SavedVariables/YiboCraftingStage0Probe.lua`。最多保留 4 次会话、每次 24 次列表快照、200 条事件、40 个配方详情和 4 次考古项目快照。会话用角色标识哈希区分，专业快照包含配方名称、ID、图标、已学字段和目标物品/材料 ID；考古快照只保存项目法术 ID、稀有度及完成次数，不保存名称或描述。分享前请自行检查 SavedVariables 中的内容。

探针始终将扫描完整性记为 `unverified`。客户端样本应填入 [阶段 0 验证记录](../../YiboCrafting/_NonRelease/Docs/Stage0-客户端验证记录.md)，完成目录和扫描完整性证明后才能启动正式缓存与“确认未学”状态。

`scan` 额外被动记录 MoP 专业窗口的子类别/装备栏、仅可制造、仅可涨技能、Blizzard 搜索框文本、底层物品名称/等级筛选值和分类展开返回值。`visibleList` 将明确生效的原生筛选、搜索、已知折叠、行数截断，以及同一会话同一专业技能等级下相对先前本人列表的严格 ID 子集记为 `restricted`；其余记为 `unverified`，并保留不确定原因。两种情况的扫描完整性都仍是 `unverified`。第三方搜索框可能只过滤自身列表，当前构建的分类展开返回位在既有样本中为空。目标构建实测底层名称 Getter 在无筛选时返回 `nil` 且无调用错误，等级 Getter 返回 `0/0`；接口缺失或报错才记未知。探针不改变筛选或展开状态。

本地模拟验证：在仓库根目录运行 `lua _NonRelease/YiboCraftingStage0Probe/Tests/Smoke.lua`。

分析落盘数据（只输出专业、行数、配方 ID 数和集合变化，不输出角色或配方名称）：`lua _NonRelease/YiboCraftingStage0Probe/Tests/AnalyzeSavedVariables.lua "<SavedVariables 文件路径>"`。

目标构建目录只读对照：在仓库根目录运行 `python _NonRelease/YiboCraftingStage0Probe/Tests/AnalyzeBuildCatalog.py _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-batch2-recipe-ids.lua _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-mining-recipe-ids.lua`。脚本在线读取固定构建 `5.5.4.69934` 的 `SkillLine`、`SkillLineAbility`、`SpellReagents` 和 `SpellEffect` CSV，校验内容哈希，只输出各样本与候选目录的数量、缺项和例外；它不会保存或发布目录，候选多于已见也不等于“未学”。

可选的 `--legacy-catalog "<本机 alaTradeSkill/Data/classic-5mists.lua 路径>"` 只读比较旧候选目录与目标构建 DB2 的 ID 差异；该文件不属于探针，也不会被复制到仓库。

生成固定构建候选目录：运行 `python -B _NonRelease/YiboCraftingStage0Probe/Tests/BuildCandidateCatalog.py _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-batch2-recipe-ids.lua _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-mining-recipe-ids.lua _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-28-build69934-filter-recipe-ids.lua --legacy-catalog "<本机 alaTradeSkill/Data/classic-5mists.lua 路径>" --output _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.69934.json --report _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.69934-review.md`。脚本校验五张目标构建 CSV 的哈希，写出每个候选的技能线、名称、材料表、效果类型和客户端实见标记；不会把候选发布为游戏插件配方目录。离线检查：`python -B _NonRelease/YiboCraftingStage0Probe/Tests/TestBuildCandidateCatalog.py`。

用户已确认 `818`（烹饪用火）和 `110955`（释放灵魂）不是配方。生成器另按目标构建的名称与效果排除 `104115`（释放火焰之灵）、`105518`（打开箱子）、`13262`（分解）等通用操作技能；排除 ID 仅写入逐专业记录，不放入 `recipes`。同时缺少名称、材料、效果且无正向样本的 ID 暂列 `quarantinedIDs`，不当作可显示配方，也不判定无效。

半山烹饪六分支由用户确认纳入范围，生成器将解锁法术放在 `branchUnlocks`，将各子技能线的菜谱保留在 `recipes`。工程制作筛盐器的 `19567` 已在客户端样本中出现；旧目录制皮 `19566` 是使用筛盐器处理盐的效果，作为已结清差异保留，不并入配方。

用户确认旧雕文配方 `413897`、`414814` 在当前客户端已移除，生成器将它们放在 `removedRecipeIDs`。`66587`、`405005` 没有可用于中文客户端检索的目标构建法术名称，继续隔离；不要求玩家逐 ID 查找。

可选的 `--archaeology-sample _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-archaeology-project-ids.lua` 会额外读取固定构建的 `ResearchProject` 和 `ResearchBranch`，与去角色标识的考古项目法术 ID 对照。该样本不含角色和完成次数。
