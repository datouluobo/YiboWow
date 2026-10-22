# 日历查询基准修复 — 2026-10-22

状态：Core 与两消费方代码及离线验证完成，新增代码客户端待验。当前 main，未提交、推送、打包或发布。

2026-10-22 来源追查：已审查本机SetMonth／SetAbsMonth调用，发现初始化相对切月与扫描恢复旧基准两类候选；未取得本次运行调用链，来源保持待定。独立非发布探针已联接MoP，记录首次异常及调用栈，不修改第三方插件；采集、边界和本机候选见[日历调用追踪](../!YiboCalendarTrace/README.md)。

首份客户端日志已读取：14条记录，启动期1999-00-00／2004-11，登录前恢复当前年月，之后Questie与MountsJournal调用均保持2026-10；未复现2021-11，责任方仍待定。新增日期有效性保护与探针0.1.1；详见[日志分析与原始证据](Trace-Analysis-20261022.md)。

## 直接证据

用户报告首次暗月修复后仍复发，且 AltoBoss 无头骑士显示活动未开放。游戏内输出：两个日历筛选均为1；服务器2026-10-22，GetMonthInfo基准2021-11；偏移59查询为0。执行SetAbsMonth切至2026-10后偏移0查询为3。随后用户换角色，两插件恢复。该对照证明本次相对查询的空结果不能直接当关闭证据；具体是谁改变基准尚无证据。

此前暗月同步补全与偏移换算不足以处理多年偏移；不能再把一次重载恢复写成完整修复验收。日历筛选关闭未在本次会话复现，不作为此次根因结论。

## 当前实现与边界

通用客户端读取收归Core `calendar-day-query:1`，见[接口契约](../../YiboCore/Docs/API-v13-日历当天查询.md)。超过12个月的查询基准先校正为服务器当前月并核对后再读；这是保守策略，不是客户端精确范围声明。普通浏览按偏移查询。远期／历史月份被校正后保留当前月，不恢复失效基准。读取失败／不完整／校正失败为未知；不改日历筛选和用户存档，不按固定日期推定活动。

Todo暗月与原SpecialActivity节日日历查询统一在Mists适配层消费Core；AltoBoss新增Mists/Calendar适配层，原HolidayBoss不再直接查询C_Calendar，首次完成就绪标志改为服务器日期。校正同步事件有递归读取保护。两插件检查Core API13及calendar-day-query:1，缺能力提示升级并停止，不执行本地回退。Core只管日期与原始事件，暗月和节日规则仍归各业务所有者。CAP-012登记部分接入，最低能力及客户端验证未完成不标全部完成。

迁移单元为两插件本次触及的完整日历读取职责，未扩展到节日目录、排队、完成采集或其它插件。仅Mists：新Core与AltoBoss目标模块分别由默认TOC加载一次，Forever TOC不引入此能力。插件技术名、安装目录和SavedVariables身份不变；覆盖更新旧文件残留不额外加载或注册第二份日历实现。正式干净／保留旧文件覆盖安装仍待验证。

## 离线验证

- Core CalendarDaySpec：16项；59个月返回0的原始复现、当前月恢复3条、重复读取、普通跨年浏览、失败／缺API、结果隔离和递归保护。
- 本目录Spec：12项；真实Core＋Todo＋AltoBoss，互换读取顺序、外部再次改动、校正失败未知、同会话恢复与缺能力停止。
- Todo DarkmoonCalendarSmoke、DarkmoonCycleSmoke、SpecialActivitySmoke通过；TodoSourcesSpec177项通过。
- AltoBoss HolidayBossSpec284、InstanceKills56、LockoutProjection16、BossGoals19、CustomBossGoals25通过。
- 三插件TOC Lua5.1检查107文件通过，三插件Mists发行清单ValidateOnly通过，未生成新包。
- BossTargetsSpec在其前置ActionIntegrationSpec:188的本地化夹具断言停止；EventGoals仍有此前已记录的前置GoalSourcesSpec:154 provider-error。本轮未宣称这些综合脚本通过。

## 客户端待验

新增TOC加载点后须完整退出MoP再进入，保证Core与AltoBoss新适配文件都加载。核对暗月列、无头骑士、入口预览与行动中心；普通翻月、再次偏移多年、角色切换、重载及完整退出恢复。周四任务重置、周日实际关闭边界与关闭日周期连续性继续待验。日历基准异常的来源尚未定位，不将任何第三方插件判为已证实责任方。
