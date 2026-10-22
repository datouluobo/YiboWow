# API13 日历当天查询

2026-10-22 工作树实现。最低要求：Core API13、`calendar-day-query:1`，且 `Core.Calendar.ReadDay` 存在；首次实现位于 Core Mists 1.12.8，同版本旧包不保证包含此能力，必须检查 capability。Forever 未提供此能力。

## 职责与接口

`Core.Calendar:GetCurrentDate()` 返回服务器年月日与星期的独立表，尚未就绪返回nil。客户端启动时已观察到1999-00-00；API存在但失败或年月日无效时不使用本机日期回退，也不据此校正日历。优先使用 `C_DateAndTime.GetCurrentCalendarTime`；旧客户端无此 API 时使用服务器时间戳的日期接口。

`Core.Calendar:ReadDay()` 无参数，查询当前服务器日期，返回独立快照：

- `state = "ready"`：含 `date`、`events`、`originalOffset`、`repairedAnchor`。events 每项仅含 `title/eventID/calendarType/sequenceType` 等原始事实。零项表示本次有效查询未返回事件，是否足以确认关闭由消费方结合本会话同步状态判断。
- `state = "unknown"`：含 ASCII `reason`，可为 `unavailable/month/anchor/count/partial/query/reading`；不得当作活动关闭或完成证据。

查询先相对 `GetMonthInfo(0)` 换算当前服务器月。普通浏览保留原月份。对于绝对偏移超过 12 个月的基准，采用保守保护策略：先 `SetAbsMonth` 校正为服务器当前月、再次核实年月，再以偏移 0 查询；校正失败返回未知。12 是本接口的查询保护范围，不宣称是客户端 API 的精确上限。校正会让这种远期或历史浏览回到当前月，避免重新留下失效基准；不恢复失效基准。普通跨月浏览不受此校正影响。

`Core.Calendar:IsReading()` 表示正在读取／校正。消费方收到校正同步触发的日历事件时应跳过递归刷新；操作异常也会清除读取标志。此模块不创建事件帧、缓存、SavedVariables 或用户设置，不主动请求日历，不修改筛选开关。初始化、请求、同步事件和快照失效仍由消费方按已有生命周期处理。

## 业务边界与接入

Core 只处理客户端查询基准、服务器日期、错误与数据副本，不识别暗月／节日名称、不计算任务周期、不采集完成记录。活动身份、资格、完成证据、重置和是否显示均归业务插件。

- YiboTodo：`Mists/Darkmoon.lua` 的暗月与节日判断使用本接口；原 SpecialActivity 节日日历逻辑迁入同一目标适配层。启动检查 capability，缺失时提示升级并停止集成。
- YiboAltoBoss：`Mists/Calendar.lua` 使用本接口，HolidayBoss 消费其开放／已知结果；同步就绪按服务器日期记录，避免永久布尔标志跨天沿用。CoreRequirements 检查 capability，缺失时提示升级并停止运行。

无本地日历查询回退。其它业务插件在触及同类查询时再评估接入，不要求本次全仓迁移。

## 证据与验证

2026-10-22 用户同一会话输出：服务器 2026-10-22，浏览基准 2021-11，暗月／节日筛选均为 1；偏移 59 查询返回 0。切至服务器当前年月后，基准 2026-10，偏移 0 返回 3。不能由此确定是谁更改了基准，也不能外推出所有偏移的精确可用范围。用户随后换角色，两插件恢复；这不是新增代码的实机验收。

Core CalendarDaySpec 19 项与两个真实消费方的 CalendarAnchor 12 项覆盖该复现、读序互换、外部再次改动、失败未知、递归保护、普通跨月、旧 Core 停止与结果隔离。两个业务插件完整实机、周四在线重置、周日关闭边界和正式包干净／保留旧文件覆盖更新仍待验证。
