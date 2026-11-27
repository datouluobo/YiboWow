# YiboReputation

> 文档状态更新（2026-10-16）：现有功能已由用户确认实机验收收口。当前源码版本与发行证据见[状态总览](../Docs/仓库当前状态总览.md)，后续任务见[延期清单](../Docs/后续开发任务清单.md)。下文旧版本的开发／待验收描述按其原日期理解；当前版本渠道状态没有明确证据时保留待核对。

当前工作树为 **Mists 1.9.0／Forever 0.3.0**，需要 **YiboCore API14** 和两端各自声明的能力。两端共用主矩阵、关注悬停、配色和中英文资源。MoP 截图确认主矩阵与悬停的暗金满级样式，Forever 实机待验。 [双端实施与验收](Docs/双端共享矩阵-实施与验收.md)

依赖 YiboCore 的多角色声望浏览与比较插件。

新版界面采用明确分工：

- 主窗口提供“声望为行、角色为列”的完整账号矩阵，用于浏览、搜索和角色间比较。
- 悬停预览显示最多 20 名有声望数据角色的监控矩阵。

主窗口与悬停预览共享本插件的稳定 faction ID 快照、数据状态和数值格式。入口、窗口壳、角色范围、角色排序和设置工作台由 YiboCore 统一承载。

Mists 提供资料片分类、好友度和公会分组，角色快照保存于 `YiboReputationDB`。Core 的旧声望快照按角色导入，保留原始时间和旧版本标识。Forever 使用 `YiboReputationForeverDB`，显示已观察阵营和角色对照，当前角色的有效观察提供会话净变化。两端各自维护采集和存档。

Core 与 Reputation 需配套升级。旧 Core 仍注册声望采集器时停止初始化并提示升级；旧版 Reputation 与新 Core 搭配会读到不再更新的历史快照，属于不支持组合。降级不能自动带回切换后的新采集。

实施边界见 [声望数据归属迁移方案](Docs/声望数据归属迁移方案.md)，验证证据见 [迁移实施与验收记录](Docs/声望数据归属迁移-实施与验收记录.md)。真实客户端首次导入与界面验收待完成。

`/yrp` 打开矩阵，`/yrp status` 查看采集状态，`/yrp scan` 扫描当前角色。Mists 的 `/yrp migrate` 可重试历史导入，已有本地快照优先。角色缓存删除统一从 Core 的“角色与排序”进入。


## 行动中心主动添加（2026-10-10 工作树）

角色声望格可添加标准／已知友谊等级阈值；新鲜已知来源快照才完成，rank缺失或未采集保持未知。

新增强最低 Core API v12 / business-item-actions:1，不足提示升级并停止增强；原基础业务保留既有最低版本，作为旧 Core 兼容例外，无新交互本地回退。整体提高最低版本时收拢此例外。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。

## 图标资源（2026-10-14）

当前图标为 `Media/YiboReputationIcon`：默认TGA为64px，插件列表使用128px TGA；PNG提供16/24/32/64/128/512/1024px，母版为312px透明位图。版本、统一缩放和验证范围见[系列资源记录](../Docs/Design/Yibo系列Logo-20261014/README.md)。

![YiboReputation 图标](Media/YiboReputationIcon-128.png)

## 打包

从仓库根目录运行 `Tools/Build-ReleasePackages.ps1 -Addon YiboReputation -Target Mists -Channel CurseForge -ValidateOnly` 校验目标包。Forever 将 `-Target` 改为 `Forever`。两个玩家包均以 `YiboReputation.toc` 加载。

## Forever 最小适配历史（2026-10-20）

Forever开发清单 `YiboReputation_Forever.toc` 当前为0.1.1／Interface16001：当前角色已观察声望只读采集，独立保存至YiboReputationForeverDB。普通声望显示中立／友善等等级名称、当前级进度及对应颜色进度条；主窗口和悬停共用显示逻辑。`/yrp`打开，`/yrp scan`刷新；覆盖为可见及此前已观察的项目，缺失或折叠不补零。特殊声望与共享规则另验，Mists保持1.7.2。91项目标模拟、MoP原有回归及语法通过。0.1.1等级名称、进度与颜色条已获用户实机确认，增长后的声望值已采集展示；自动刷新路径、悬停、语言模式和存档独立恢复等仍待验证，见[实施与验收](Docs/Forever-当前角色声望最小适配与验收.md)。
