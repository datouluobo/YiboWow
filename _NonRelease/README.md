# `_NonRelease` 内容索引

这里存放不进入玩家包的探针源码、验证材料、开发诊断和阶段性构建证据。目录名可能代表当前工作、历史快照或离线用例；不得仅凭名字判断是否可删除。

2026-11-02：已完成用途的十个旧发布快照与八个 TOC 探针源码移入 [`_ManualDelete-2026-11-02/`](./_ManualDelete-2026-11-02/)，由用户手工删除。相关验收结论文档保留。Retail TOC 探针原 AddOns Junction 的遗留状态和精确路径见暂存区 README。

## 分类导航

- **可加载客户端探针**：`Yibo*Probe/`、`Yibo*R4/`、`!YiboCalendarTrace/` 等。已完成的 Retail TOC 选择夹具暂存于 [`_ManualDelete-2026-11-02/CompletedTocProbes/`](./_ManualDelete-2026-11-02/CompletedTocProbes/)。稳定命名和加载规则见[非发布探针命名与组织规范](../Docs/非发布探针命名与组织规范.md)。各目录是否当前链接，以客户端 AddOns 的实际 Junction 为准。
- **业务诊断拆出的原生 API 探针**：`YiboCurrencyProbe/`、`YiboLegendaryProbe/`、`YiboMountsProbe/`、`YiboTodoProbe/`。四者只支持当前 Mists 目标，不读业务插件内部对象；MoP AddOns 中四个同名 Junction 已建立并核对目标。
- **客户端/系统诊断**：`ClientUpdateDiagnosis/`、`CalendarAnchor/`、`MailPerformance20261029/` 等。包含原始追踪、样本和分析文件，可能体积大且不一定可再生。
- **离线测试与契约夹具**：`Core*R*`、`CoreConsumerR3/`、`CurrencyMigration/`、`TaskGoalIntegration/`、`MailReturn/`、`MatrixBudget/` 等。由代码或文档引用，不能与游戏探针混为一类。
- **构建与发布快照**：`Release-*/`、`*-Release-*`、`Packaging/`、`VaultReleaseCheck-*/`、`Mounts-*/` 等。保留阶段源、打包内容、校验与回放证据；同一插件可能有多轮版本快照。
- **报告/资源/恢复记录**：`Localization/`、`LogoOrganization-*/`、`SourceJunctionRestore-*/`、`Recovery-*/`、`SuiteGallery/` 等。

## 维护边界

- 只有确认没有有效引用、没有证据价值且可重建的内容才列为清理候选；追踪日志、玩家数据副本、发布包及历史证据不因“旧”自动删除。
- 归档或移动目录前，检查文档、脚本、构建配置、测试和客户端 Junction，并同步有效引用。
- Forever 客户端目前不可用且已卸载。Forever 探针保留在源码区；待新正式版可安装后，重新核验目标身份及加载规则，再建立同名链接。
