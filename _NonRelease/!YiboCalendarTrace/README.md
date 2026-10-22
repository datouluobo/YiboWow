# 日历月份调用追踪

状态：非发布诊断0.1.1，离线21项验证通过；已读取首份0.1.0客户端日志，未复现登录后基准异常。仅部署MoP，不随Core或业务插件发布。

## 已确认与待确认

2026-10-22已确认服务器2026-10-22、日历基准2021-11；偏移59返回0，绝对切至当前月后返回3。来源尚未确定。Core当前读取保护与本探针独立：保护负责恢复业务读取，探针负责追溯调用。

本机安装代码的完整搜索发现以下调用路径；“存在调用”不等于“已证实责任方”：

| 插件与本机路径 | 行为 | 需要区分的情形 |
| --- | --- | --- |
| Questie12.1.0 / Database/Corrections/Holidays/QuestieEvent.lua:135–144 | 初始化OpenCalendar后调用SetMonth(0)，未先SetAbsMonth | 初始化时基准是否已异常；SetMonth调用前后是否首次发生跳变 |
| MountsJournal v3.4.41 / components/Calendar.lua:26–55、183–215、226–285 | 备份浏览年月，扫描当前／附近年份，最后恢复备份 | 是否首次改成异常年月，还是恢复了先前已异常的备份；扫描异常是否中断恢复 |
| DataStore_Agenda / DataStore_Agenda.lua:13–61、127–129 | 初始化绝对切当前月，扫描后恢复先前年月 | 是否传播先前异常；依赖加载阶段的日历事件可能嵌套 |
| AllTheThings / src/Modules/Events.lua:166–237 | 当前月起扫描前18月到后12月，最后切回当前月 | 扫描是否中断；不能仅因曾改月份而归责 |
| SilverDragon / systems/conditions.lua:299–315 | 非当前月且日历未显示时，优先SetAbsMonth | 本机代码注释已知“日历未打开时SetMonth可能跳错误年份”，是线索而非此次调用证据 |
| HandyNotes_MistsOfPandariaTreasures / handler/conditions.lua:301–317 | 与上一项类似的绝对月份保护 | 仅核查实际启用与调用记录 |

未修改以上第三方插件、其设置或SavedVariables。

## 采集

目录与TOC同名：`_NonRelease/!YiboCalendarTrace/!YiboCalendarTrace.toc`。本机MoP已建立同名Junction：`C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\!YiboCalendarTrace` → 本目录。

1. 完整退出游戏再启动，插件列表确认 `[Yibo] 日历调用追踪` 已启用。`!`名称用于尽量提前加载，但不保证早于所有依赖或已缓存API引用。
2. 进入角色后输入 `/ycm`：状态应显示SetMonth、SetAbsMonth、OpenCalendar均为true。命令已在整个工作区搜索SLASH注册，未发现占用。`/ycm mark`可增加当前状态标记；无清空或修改日历命令。
3. `/reload`或正常退出使记录写盘，再由Agent直接读取账号SavedVariables下 `!YiboCalendarTrace.lua`。可按平常操作换角色／打开坐骑收藏／日历，让正常调用自然发生；无需主动制造错误。

读取：`lua "_NonRelease/!YiboCalendarTrace/Read-Saved.lua" "<SavedVariables绝对路径>/!YiboCalendarTrace.lua"`。

## 记录与边界

独立运行且不依赖Core，以便尽早挂钩。只使用hooksecurefunc后置观察SetMonth、SetAbsMonth、OpenCalendar，不替换原API、不更改其参数／返回值、不改日历选择或筛选；无Broker／小地图／窗口。诊断消息使用本探针稳定ASCII key的中英文资源，不引入独立业务语言设置。

每条记录含序号、服务器时间、运行秒数、原参数、服务器日期、修改后浏览月、上一次观察月、相对月份偏移、来源位置和完整调用栈。`previousObserved`仅为上次观察，不是截获的真实调用前状态。调用栈是调用证据，需结合参数、先后与实际跳变归因，不能把“在异常基准上调用SetMonth(0)”直接认定为首次制造异常。

初始化时保存首个快照，捕捉“原生初始状态就异常”的情况；候选插件若在挂钩前已加载，记录于loadedBeforeHooks。后续事件发现未被钩子捕获的状态变化，仅标事件与unknown来源，不臆测调用者。原生内部变动、过早缓存的API函数引用可能逃逸；若出现此情形再据证据安排最小启用集合对照。

记录保留最近3次会话、每次最近180条；首次观察、首次异常观察／调用、首次已观察到的跨界及首次修复单独固定，避免被扫描量冲掉。日志只存在本机内存与本探针自己的SavedVariables。诊断异常吞入记录路径，不向调用插件传播。

## 验证与后续

`lua "_NonRelease/!YiboCalendarTrace/Tests.lua"`：21项通过，涵盖不修改日历、后置钩子、重复加载、原多返回值、调用来源、初始异常、恢复旧基准、未捕获变动不归责、环形上限、关键证据固定、命令与诊断故障隔离。Lua5.1语法通过；Junction与唯一TOC/脚本核对通过。没有改动正式运行代码或Core公共能力，CAP-012接入状态不变。

2026-10-22已读取首份日志：初始服务器日历日期1999-00-00与浏览月2004-11均处于未就绪阶段；登录前观测到2026-10，后续Questie与MountsJournal调用均未改离当前月。未出现2021-11，不能确定之前异常的责任方。0.1.1新增realmRaw／realmReady，日期无效时不计算偏移，避免把启动哨兵数据标为实际异常；原始0.1.0日志按原值保留。完整结论见[首份日志分析](../CalendarAnchor/Trace-Analysis-20261022.md)。后续正常使用保留追踪，遇到再次异常后保存日志再归因。
