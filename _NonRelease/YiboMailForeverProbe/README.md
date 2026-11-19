# Forever 邮件操作观察探针

0.1.2，2026-11-18。非发布、只读、默认关闭；已部署联接，尚未实机运行。唯一命令 `/ymf on|sample|off`，无旧别名。仅支持实测产品身份 WOW_PROJECT_CAMELOT、Interface16001。关闭采样后事件不读取邮箱/草稿；重复加载通知不重复注册。新增canReply/isGM及原生删除资格的标量采样，不读邮件正文。

运行前完整退出客户端，将本目录以同名 Junction 联接至 Forever Interface/AddOns。不得向源码联接解压包；此探针不进入正式包。部署时另记源路径、客户端路径及日期。

2026-11-18已部署至`D:/Program/World of Warcraft Forever/World of Warcraft/_forever_/Interface/AddOns/YiboMailForeverProbe`，指向仓库本目录；Junction及Probe.lua两端SHA256一致，记录见Deployment-20261118.json。Core和Mail也已核对为仓库源码联接。本次未启动/操作游戏；需完整退出重启以发现新插件。测试完成正常退出后，本机SavedVariables可直接用于分析，无需改动业务存档。

进入游戏后 `/ymf on`，按整体方案第6节在原生邮箱正常操作，关键操作前后 `/ymf sample`，结束 `/ymf off` 并正常退出。提交 SavedVariables/YiboMailForeverProbe.lua。单次上限1000条，达到上限停止采样；不提供运行时清盘命令。

记录 build/project、哈希角色/发件人/主题（用于关联，不是匿名安全保证）、铜币/COD/期限、附件ID数量槽位、原生控件存在性及方法、玩家操作和事件时序。正文和SendMail参数不采集，不调用任何取件/发送/退信/删除接口，不访问业务插件数据库。不记录UI错误文本或事件负载。记录中的事件或API存在只证明观察到该事实，不能直接证明操作成功。

取证一次集中完成：开关邮箱及切发件页；按本人需要正常收附件/金币；自然发送廉价附件给本人另一角色并切角查看；有现成退信/COD/失败样本时观察；最后退出恢复。不要为测试付款、塞满背包或制造百封邮件。缺样本保持待验。

发件页可见时采样收件人/主题哈希、铜币/COD和附件ID/数量/槽位/链接哈希，绝不读取正文。原生发送按钮OnMouseDown只读观察补充点击前样本；它不代表SendMail精确调用时的完整草稿，程序化点击或原生确认后改变草稿仍需结合事件和截图。操作hook仍不记录SendMail参数、不替换安全函数。安全点击、原生确认、装填/撤下和跨角色送达需结合截图及后续收件样本判断。OfflineSpec覆盖末附件槽、金额/COD、哈希而非原文、正文禁止读取、关闭后零读取和点击前样本。
