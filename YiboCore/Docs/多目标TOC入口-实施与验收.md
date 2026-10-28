# Core 多目标 TOC 源码与构建接入

日期：2026-10-26。范围：用户指定的第1项，正式源码与构建配置接入；发行状态仍为待检查。

## 已落地

- `YiboCore.toc` 仅加载 `Common/TocHint.lua`；无 SavedVariables、Core/API 对象或事件注册。
- `YiboCore_Mists.toc` 加载既有 MoP 运行链，版本1.12.9／API13，存档 `YiboCoreDB`。
- `YiboCore_Forever.toc` 加载既有 Forever 运行链，版本0.2.0／API13，存档 `YiboCoreForeverDB`。
- 两个目标清单声明 `X-Yibo-Target`。53个既有运行Lua未变；未修改业务schema、公共能力契约或业务消费者接入，公共能力迁移台账无新增项。
- 默认提示以稳定 ASCII key `TOC_TARGET_MISSING` 提供中英文资源。此处 Core 尚未加载，不能调用 `Core:Text`，因此仅此预启动提示使用局部资源表；运行语言服务保持原实现。
- `Tools/ReleaseProfiles.psd1` 登记两个目标的来源清单；安装包都输出单目标默认 `YiboCore.toc`。Forever目标版本读自 `Forever/Target.lua`，API独立读自 `Bootstrap.lua`。
- 全目标 GitHub 源码归档使用统一主版本1.12.9／API13和 `forever-mists` 标签，不随选择的安装目标改变。目标安装包分别采用1.12.9与0.2.0。其它插件的开发目标清单仅用于 Core 目标版本索引，不自动获得发行资格。

本次职责单元是加载入口与构建路由；客户端专用实现已位于 Mists／Forever，共享实现继续共用。保留旧文件的覆盖加载图检查复用 X05，不引入运行时磁盘清理。

## 验证结果

| 检查 | 结果与边界 |
| --- | --- |
| 正式源码与已验候选比较 | 53个既有运行Lua、两个目标TOC及Hint逐字节一致；默认TOC仅移除临时候选元数据。哈希记录位于 `_NonRelease/CoreTocEntry-20261026/SourceIntegration-Hashes.json` |
| 三TOC源清单验证 | 128项通过：加载、单次初始化、目标存档隔离、误目标停止和四种locale提示 |
| Core双目标模拟 | 69项通过 |
| 双目标构建计划 | 19项通过，含版本/API、清单、目标排除、业务版本索引及统一源码归档身份；仅 ValidateOnly |
| 通用打包回归 | ReleasePackagingSpec 52项、UniformNamesSpec 82项通过，使用独立夹具输出；未生成正式发行包 |
| 货币／声望迁移加载引用 | 货币23+55+15项、声望88项通过 |
| Forever联合模拟 | 268项通过，覆盖七业务／三探针、两种语言及两种业务加载顺序；不替代实机 |
| Lua语法 | 双目标构建计划检查所选加载Lua，Hint另行 `luac -p` 通过 |
| 本地化静态报告 | Core546 key，缺英文0、格式不匹配0；全仓6个未知key均在既有AutoOpen。Core唯一硬编码候选是上述双语预启动Hint，已审查 |
| 旧LocaleSpec | 第56行 `character.level` 字段不存在而失败；同样在接入前已验候选Mists清单复现。本次未修改运行字段以迎合旧夹具，该项不记通过 |

主验证脚本：`_NonRelease/CoreTocEntry-20261026/Verify.lua YiboCore`、`BuildProfilesSpec.ps1`。旧测试中直接读取 Core 默认TOC的适用入口已改读Mists清单；历史归档与已验候选保持原样。

## 实机证据复用与剩余工作

用户已经确认 X03 两端首次加载、X04 两端 reload、X06 两端完整退出恢复通过；版本、原角色、排序／设置和无新增错误按指定范围记录。正式源码运行字节与加载图一致，本步复用这些证据，不安排重复操作。旧TOC探针A—D同样保持已验结果。

X05使用真实旧MoP1.12.9／1.12.7包保留旧文件覆盖，已验证加载图与候选一致；它仍只是离线结构证据，不外推为最终单目标安装包或更新工具验收。

两端Core目前仍是已验候选普通目录，原联接保存在各自 `_YiboCoreTocTest/20261026-X03/OriginalYiboCore`。本步未改客户端目录、Vault、旧TOC探针或WTF。后续第2项再核对Vault差异与恢复源码联接，第3项再做最终目标包及尚未覆盖的安装／发行边界。Forever业务／其它探针继续暂停，Core整体UI和业务的未验范围仍按总台账保留。

本次未发布。CF版本数字ID、最终目标包清单和适用安装安全验收仍待发布检查。

## 第2项联接恢复补记（2026-10-26）

两端Core、Vault共4个源码联接已恢复，两端各15个正式插件联接核对通过。测试目录完整保留于各客户端 `_YiboSourceJunctionRestore/20261026-5c358d0c/`；247个文件与切换前哈希一致，110份Yibo存档文件备份后原WTF哈希不变。旧TOC探针部署保持原状。已验入口证据继续复用，最终目标包与安装安全检查是下一阶段，尚未执行。
