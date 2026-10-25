# SW 锁定取证与本周期确认

2026-10-26；AltoBoss 2.8.3／TaskHub 0.6.1 工作树。代码与离线检查完成，新增功能实机待验，未发布。

## 本次证据

用户确认太阳之井只有卡雷苟斯未击杀。原生团队信息存在25人锁定；保存的原生首领列表却只有卡雷苟斯一条未击杀记录。当前客户端实测 `C_RaidLocks.IsEncounterComplete(580,729,176)` 与遭遇2493均为false，分享链接字段为 `580:176:0`。因此这些接口在本次样本中不能还原其余五名首领的历史击杀，不能据此把基尔加丹判为未击杀或把缺席条目判为已击杀。

锁定列现显示“已锁定”，悬停保留到期时间及“首领进度待核实”；Hub任务继续保持待核实，直到来源获得明确证据。本次没有修改玩家WTF文件。

## 采集与数据所有权

Mists/RaidEvents.lua监听成功的ENCOUNTER_END和BOSS_KILL，在当前团队副本、当前实际难度内解析来源目录中的稳定首领ID。SW补充旧／新原生遭遇ID映射，并仅在SW监听战斗日志，以基尔加丹NPC25315的UNIT_DIED作为精确现场证据；伤害、失败、其它NPC、地图与难度不构成成功。投降或多实体遭遇仍需要原生成功事件，不能把单个实体死亡当作整场完成。

Common/RaidProgress.lua负责周期记录、合并、确认及失效；记录保存于AltoBoss角色业务数据的raidProgress，以mapID:difficultyID、稳定首领ID、weekly cycleKey、validUntil、observedAt及source标识归属。现场记录与手动记录分开保存；重复事件幂等，撤销手动确认不影响现场记录。重载和退出后沿用本周期记录，到期或周期改变后不再生效，不覆盖原生锁定快照。无法获得有效周期时不开放确认。

这是Mists功能；AltoBoss和Hub当前没有由本次改动新增的Forever实现或验收结论。客户端事件集中在Mists，共享合并与Hub操作位于Common；现有插件技术名和SavedVariables身份不变。当前TOC加载新路径，旧目录残留保持惰性。

## 公开契约与操作

Core发现的AltoBoss `action.targets` provider提升为1.2，兼容原1.x查询。Normalize附带可选actions元数据；ConfirmCycle／RevokeCycle只接收规范化intent及来源sourceEpoch、revision、cycleKey。服务重新验证角色、目录、难度、选中首领及周期；过期确认被拒绝。Hub通过Core.Contracts调用，Core.ItemConfirmation承载确认框；Hub不保存第二份完成状态。最低Core API13与既有能力要求不变。

游戏内：Hub→目标→对应副本目标的“编辑”→确认范围为基尔加丹→“手动确认本周期完成”。确认框列出角色、目标和失效时间；取消不写入，确认后来源明确显示“本周期已完成（手动确认）”。同页可以撤销。只确认当前所选范围，整本目标会确认整本，务必核对选择。目标原有“单次／按来源周期重复”的完成策略继续适用。

只读核对确认当前经典服的AltoBoss和TaskHub安装目录均为工作树同名目录的联接，代码已位于其加载来源。本次新增TOC条目，实机复测前完整退出并重启客户端；未代用户操作游戏或执行确认。

现场采集需插件在击杀时已启用；不能追溯安装前的击杀。该场景历史记录由用户明确确认补齐，不把用户口述硬编码为自动进度。

## 验证与待验

2026-10-26用户复测：AltoBoss太阳之井单元显示“已锁定”，Hub基尔加丹默认仍为“待核实”，用户明确反馈“手动确认可以”。据此将手动确认主流程记为实机通过；截图没有显示基尔加丹原生已击杀或新增现场采集证据，不能记为自动采集通过。代码复核确认AltoBoss该单元的“已锁定”正是unknown+lockout投影，Hub通过同一Plans:Progress评估目标，两处含义分别为副本锁定存在与首领完成待核实。专项RaidProgress40、LockoutProjection20再次通过。撤销、重载恢复、到期及新增现场击杀仍待验。

RaidProgressSpec 40项、BossGoalEditorSpec 468项、BossSearchIdentitySpec 33项在zhCN/auto、enUS/auto、zhCN/en、enUS/zh均通过；夹具BossGoalsSpec 19项。另有Goals94、GoalSurfaces30、CustomBossGoals25、LockoutProjection20、HolidayBoss284、InstanceKills56项通过。覆盖错误事件过滤、重复上报、来源隔离、手动确认／取消／撤销、过期对话框、跨周期失效、Hub和来源一致、来源注销／恢复。TOC加载Lua语法检查通过。

本地化报告无缺英文、重复key及格式参数差异；六个未知key属于既有AutoOpen区域。本次新增状态／确认文案使用AltoBoss owner中英文资源。

待实机：SW现场击杀、确认／撤销后双视图刷新、重载和完整退出恢复、自然周重置、中英文客户端与手动语言、干净安装及保留旧文件覆盖安装。离线模拟不计为这些客户端用例通过。已有用户截图／命令仅证明上述取证现象。
