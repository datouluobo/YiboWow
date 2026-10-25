# Mists 副本目标目录

2026-10-26：SW新增原生成功事件ID映射；现场采集与本周期手动确认遵循来源唯一所有权，详见[取证与验证记录](../../Docs/行动中心-SW锁定取证与本周期确认.md)。原生接口不能还原的历史进度保持待核实。

当前难度身份：八个TBC团本的旧目录3/4由Mists适配层解析为客户端175/176，目录、手册和原生锁定共用同一身份；其它地图难度不作全局替换。来源还公开历史目标身份别名，使Hub的添加/查找/复制复用既有目标。详见[身份一致性记录](../../Docs/行动中心-搜索焦点与副本身份一致性.md)。

2026-10-25。Mists/RaidCatalog.lua 维护21个旧团本、135个遭遇的稳定业务ID、合法难度、显式尾王和中英文显示/搜索资源。数据仅属于AltoBoss；Hub经Core公开目录服务查询，不在Hub或Core再存一份业务目录。

维护事实依据为本机已安装DBM-Raids-BC r11、DBM-Raids-WoTLK r344及DBM-Raids-Vanilla r815的Mists分组、遭遇模块与游戏名称，参考项目：[DBM Burning Crusade](https://github.com/DeadlyBossMods/DBM-BC)、[DBM Wrath](https://github.com/DeadlyBossMods/DBM-WotLK)、[DBM Vanilla](https://github.com/DeadlyBossMods/DBM-Vanilla)。核对用事实记录位于仓库根_NonRelease/TaskGoalIntegration/RaidCatalogFacts.json，保留模块路径便于审查；原始记录的nativeIDs是参考模块中出现的标识，不构成当前客户端运行时ID承诺。

仅整理游戏名称、分组和身份事实。运行文件为本项目实现，未复制第三方执行逻辑、警报、计时、说明、图像或UI；正式运行不加载或依赖DBM。尾王、难度和复合遭遇范围由本项目明确维护，不能从模块文件顺序或玩家锁定快照推定。

卡拉赞歌剧院合并三种剧目为一个遭遇；夜之魇和奥尔加隆等可选遭遇不改变已声明的主线尾王。黑曜石圣殿按萨塔里奥这个主遭遇登记；红玉圣殿目录包含三名具名守卫和海里昂，是否有完整周期击杀证据须另行验证。目录不表示所有客户端都会为每个条目提供锁定记录，进度不足继续返回未知。

Mists/TargetCatalogRuntime.lua 在原生手册可用时选定正确tier和实例，查询后恢复原选择。手册条目缺少DungeonEncounterID时使用单独命名空间的JournalEncounterID；已有数值ID保持原命名空间。维护目录覆盖没有手册支持的旧团本，旧存档中的局部目录仅用于名称到历史ID的兼容映射。

目录更新须同时审查稳定ID、合法难度、显示名称/别名、finalEncounterID、旧ID映射和精确进度证据，运行BossGoalEditorSpec及相关专项。离线通过不代替客户端目录/锁定核对；当前工作树未发布。
