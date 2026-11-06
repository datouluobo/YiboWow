# YiboCrafting 阶段 0 探针

这是独立于正式插件的非发布、只读插件。源码统一放在仓库根目录 `_NonRelease/YiboCraftingStage0Probe/`，并以同名目录联接到 `World of Warcraft/_classic_/Interface/AddOns/YiboCraftingStage0Probe/`（以实际 MoP Classic 安装目录为准）。正式 `YiboCrafting` 插件无需安装。

命令只有 `/yct`：`scan` 采当前专业列表，`recipe <SpellID>` 采配方法术与学习 API，`item <成品ItemID>` 优先查随探针生成的正式目录物品索引，再查已加载的 YiboCrafting 目录，最后才从本人当前可见列表反查，再执行同一检查，`archaeology` 只读采考古项目，`status` 查看数量，`events on|off` 控制事件记录。目录反查不要求该配方当前可见，也不依赖正式插件已安装；查不到只代表没有映射，不能推断未学。登录和打开专业窗口时也会自动采样，并标记本人候选、链接或公会来源；探针不打开窗口、不改变过滤、不执行制造或学习操作。事件只记录名称与最多三个数字/布尔参数。

退出游戏或 `/reload` 后，诊断数据写到 `WTF/Account/.../SavedVariables/YiboCraftingStage0Probe.lua`。最多保留 4 次会话、每次 24 次列表快照、200 条事件、40 个配方详情和 4 次考古项目快照。会话用角色标识哈希区分，专业快照保存可见行名称、配方法术 ID、产物 ID、筛选与分类形态；配方详情样本另记录 `GetRecipeInfo.learned`、`IsSpellKnown`、`IsPlayerSpell` 等返回。考古快照只保存项目法术 ID、稀有度及完成次数，不保存名称或描述。分享前请自行检查 SavedVariables 中的内容。

为确认 MoP Classic 的逐配方已学 API，运行探针 0.1.4 后分别查询一个明确已学和一个明确未学的配方：`/yct item 75082` 可作为已学正向样本；负向样本选当前角色专业界面中明确未学的条目，使用物品 tooltip 的成品 Item ID。生成的物品索引会将成品 Item ID 映射到配方 Spell ID，因此查询不要求条目当前出现在专业列表；聊天输出会列出匹配来源、配方法术 ID、本地化法术名、`GetRecipeInfo.learned`、`IsSpellKnown`、`IsPlayerSpell`，样本写入探针 SavedVariables，不自动改变正式插件状态。负向样本必须与已学样本属于同一专业/角色；若无法确定成品物品 ID，提供中文配方名和截图即可，不需要查 Spell ID。若 `GetTradeSkillRecipeLink` 的已学显示与这些 API 不一致，请保留两种证据，不要据单个 API 推断“未学”。

探针始终将扫描完整性记为 `unverified`。客户端样本应填入 [阶段 0 验证记录](../../YiboCrafting/_NonRelease/Docs/Stage0-客户端验证记录.md)。正式插件已可独立采集正向确认的已学配方；目录覆盖和完整扫描证明完成前，不建立完整扫描基线，也不推断“确认未学”。

`scan` 额外被动记录 MoP 专业窗口的子类别/装备栏、仅可制造、仅可涨技能、Blizzard 搜索框文本、底层物品名称/等级筛选值和分类展开返回值及空分类组数量（标题组没有可见配方行）。`visibleList` 将明确生效的原生筛选、搜索、已知折叠、行数截断，以及同一会话同一专业技能等级下相对先前本人列表的严格 ID 子集记为 `restricted`；其余记为 `unverified`，并保留不确定原因。两种情况的扫描完整性都仍是 `unverified`。第三方搜索框可能只过滤自身列表，当前构建的分类展开返回位在既有样本中为空。目标构建实测底层名称 Getter 在无筛选时返回 `nil` 且无调用错误，等级 Getter 返回 `0/0`；接口缺失或报错才记未知。探针不改变筛选或展开状态。

本地模拟验证：在仓库根目录运行 `lua _NonRelease/YiboCraftingStage0Probe/Tests/Smoke.lua`。

分析落盘数据（只输出专业、行数、配方 ID 数和集合变化，不输出角色或配方名称）：`lua _NonRelease/YiboCraftingStage0Probe/Tests/AnalyzeSavedVariables.lua "<SavedVariables 文件路径>"`。旧快照若缺少 `searchTextActive` 等有效状态字段，分析结果会输出 `searchState=unknown`，不再把非空占位文本推断为正在搜索。

目标构建目录只读对照：在仓库根目录运行 `python _NonRelease/YiboCraftingStage0Probe/Tests/AnalyzeBuildCatalog.py _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-batch2-recipe-ids.lua _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-mining-recipe-ids.lua`。脚本在线读取固定构建 `5.5.4.69934` 的 `SkillLine`、`SkillLineAbility`、`SpellReagents` 和 `SpellEffect` CSV，校验内容哈希，只输出各样本与候选目录的数量、缺项和例外；它不会保存或发布目录，候选多于已见也不等于“未学”。

可选的 `--legacy-catalog "<本机 alaTradeSkill/Data/classic-5mists.lua 路径>"` 只读比较旧候选目录与目标构建 DB2 的 ID 差异；该文件不属于探针，也不会被复制到仓库。

生成固定构建候选目录：运行 `python -B _NonRelease/YiboCraftingStage0Probe/Tests/BuildCandidateCatalog.py <去身份样本.lua> --build 5.5.4.70032 --output _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032.json --report _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-review.md`。也可省略 `--build` 使用默认 `5.5.4.69934`。目前两个固定 build 的五张表均按各自 Wago URL 取数并校验哈希；即使内容哈希相同，输出仍保留目标客户端 build。生成结果记录每个候选的技能线、分类、等级区间、材料 ID/数量、原始效果字段、`Effect=24/157` 对应的物品产物 ID、替代/被替代法术关系和客户端实见标记；提供 `--legacy-catalog` 时还记录旧目录文件哈希与逐项差异。审查报告另列无固定物品产物的边界候选和 DB2 替代关系；这些关系不自动删除旧 ID，产物缺失也不自动排除专业动作/研究技能。它是诊断候选，不是可发布的游戏配方目录。正式运行时目录生成器还同步产出探针使用的 `RecipeItemIndex.lua`，按成品 Item ID 反查配方法术，避免手工查询 Spell ID。离线检查：`python -B _NonRelease/YiboCraftingStage0Probe/Tests/TestBuildCandidateCatalog.py`。

用户已确认 `818`（烹饪用火）和 `110955`（释放灵魂）不是配方。生成器另按目标构建的名称与效果排除 `104115`（释放火焰之灵）、`105518`（打开箱子）、`13262`（分解）等通用操作技能；排除 ID 仅写入逐专业记录，不放入 `recipes`。同时缺少名称、材料、效果且无正向样本的 ID 暂列 `quarantinedIDs`，不当作可显示配方，也不判定无效。

半山烹饪六分支由用户确认纳入范围，生成器将解锁法术放在 `branchUnlocks`，将各子技能线的菜谱保留在 `recipes`。工程制作筛盐器的 `19567` 已在客户端样本中出现；旧目录制皮 `19566` 是使用筛盐器处理盐的效果，作为已结清差异保留，不并入配方。

用户确认旧雕文配方 `413897`、`414814` 在当前客户端已移除，生成器将它们放在 `removedRecipeIDs`。`66587`、`405005` 没有可用于中文客户端检索的目标构建法术名称；固定 ATT 5.3.15 历史数据已支持将两者归档为旧专业技能候选，因此运行时不列为当前 MoP 配方，也不要求玩家逐 ID 查找。

可选的 `--archaeology-sample _NonRelease/YiboCraftingStage0Probe/Samples/2026-09-27-build69934-archaeology-project-ids.lua` 会额外读取固定构建的 `ResearchProject` 和 `ResearchBranch`，与去角色标识的考古项目法术 ID 对照。该样本不含角色和完成次数。

固定版本的离线目录交叉审查（已生成报告）：

```powershell
python -B _NonRelease/YiboCraftingStage0Probe/Tests/AuditExternalCatalogs.py _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032.json --report _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-external-sources-review.md --csv _NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-external-source-diff.csv
```

脚本读取固定版本 AtlasLootClassic MoP v5.3.1、ATT 5.3.15 的上游 Lua 文件，逐源计算哈希并与客户端正向样本、旧 MoP 目录和 build 70032 候选对账；不把上游代码或数据复制到插件。当前结果为 5337 个 DB2 配方候选中 5282 个命中至少一类对照来源，55 个未命中这四类。另有用户截图及外部来源确认 54 个候选配方族有 CTM 专业供应商材料兑换来源；附魔 `Enchant Weapon - Tyranny` 则是 MoP PvP 荣誉点配方。供应商图样与目标候选 Spell ID 的一对一教授/替换关系仍须核验。报告按专业列出简体中文产物名称、英文配方名和配方 Spell ID，并明确区分 `recipeSpellID`（配方制作法术 ID）与 `createdItemIDs_ItemID`（制作产物物品 ID）；例如产物 Item ID `54491`“织焰长裤”对应配方 Spell ID `1224218`。54 个产物名称来自 `5.5.4.70032-zhCN-item-names.json` 中固定的 Wowhead zhCN 条目快照；附魔候选无产物，使用显式标注的直译。JSON 快照中的 `itemID` 是产物物品 ID，并给出关联的 `recipeSpellIDs`。命中和缺失只作为目录证据，不能单独断定当前可取得、目录完整或角色未学。已分类但取得路径未知的项目可在首版保留为 provisional/unknown，后续按具体差异修订；扫描完整性仍须独立验证。
