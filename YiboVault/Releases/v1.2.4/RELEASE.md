# YiboVault Mists 1.2.4-api1 发布候选

状态：2026-10-25离线及已列客户端测试通过，发行范围为手动覆盖安装，未发布。仅用于 Mists of Pandaria Classic 5.5.4（Interface 50504）。Forever 开发实现不随本玩家包分发。正式产物与受测运行文件一致性及可发布结论见[发布检查](../../Docs/Mists-发布前检查-20261025.md)。

## 依赖与包

- 必须安装对应客户端的 [YiboCore](https://www.curseforge.com/wow/addons/yibocore)，最低 1.12.0 / API13，并满足 `localization:1`、`business-services:1`、`character-name-format:1`、`basic-input:1`、`item-resolver:1`、`character-identity:1`、`account-entry:2`。初始化同时检查实际方法，版本或能力不足时提示升级并停止依赖初始化。
- YiboCore is not included in this download. Core 只从其官方 CurseForge 项目获取；Vault 包不包含 Core 文件。
- 可选的 `business-item-actions:1` 数量目标增强缺失时，仅该增强不可用；兼容的 `mail.items` 提供方通过 Core 发现，不构成 Mail 强依赖。
- 玩家安装包：`YiboVault-mists-v1.2.4-api1-curseforge.zip`。GitHub 归档是开发源码与公开文档，包含未发布 Forever 实现，不作为玩家安装／升级包。
- 当前候选包、源码摘要和完整 SHA256 保存在仓库非发布证据目录 `_NonRelease/VaultReleaseCheck-20261025/Followup/`；具体包及运行证据见[发布前检查](../../Docs/Mists-发布前检查-20261025.md)。正式渠道上传前核对文件哈希、Mists 游戏版本和本页状态。

## 升级与安装

退出游戏，将玩家 ZIP 中的 `YiboVault/` 同名覆盖到 MoP 客户端 `Interface/AddOns/`。支持从 1.2.3-api1 直接覆盖，保留旧文件；新 TOC 只执行当前加载链，不需要清理旧 `Collector.lua` 或旧图标。新安装只展开该同名目录，不创建额外目录层。

`YiboVaultDB`、schema 1、角色缓存及设置身份不变；保留 `WTF` 和 SavedVariables，勿用其它客户端的存档替换。TOC 新增加载文件后须完整退出并重启客户端。

同一安装目录只选择一个更新管理来源。整合包与单体同时或交替管理的识别、覆盖和卸载尚未验收，当前不声明支持；手动覆盖证据不等同于 CurseForge 客户端更新证据。

本次仅声明手动解压、同名覆盖安装。CF渠道文件名表示安装包用途，CurseForge客户端自动更新流程未验证，不在本次兼容声明内。

## CurseForge 更新日志草稿

### English

- Show separate free-space groups for general and specialty bags in bags and personal bank storage, with total free space stated explicitly.
- Fix empty herb-bag classification and refresh bank capacity when a bank bag is removed or equipped.
- Split collector loading by client target while preserving existing saved data and safe in-place upgrades.
- Use the current shared Vault icon assets and correct the settings content height so cache controls remain reachable.

Requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore), API13 and the declared Vault capabilities. YiboCore is not included in this download. Items API remains v1. This package targets Mists of Pandaria Classic only.

### 中文

- 背包与个人银行区分通用／专用包空位，顶部明确总空位。
- 修复空草药包分类及银行袋子卸下／装回后的容量刷新。
- 按客户端职责拆分采集加载链，保持原存档及同名覆盖升级。
- 使用现行 Vault 图标，修正设置内容高度，确保缓存操作位于可达内容区内。

需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) API13 及 Vault 声明的公共能力，本包不含 Core。Items API 保持 v1，本玩家包仅用于 MoP。

本地包及验收通过不代表已上传或上架；渠道上传、审核与可下载状态须另附证据。
