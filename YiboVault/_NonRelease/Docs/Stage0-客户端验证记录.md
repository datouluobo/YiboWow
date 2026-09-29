# YiboVault 阶段 0 客户端验证记录

> 目标客户端：魔兽世界熊猫人之谜经典版，Interface `50504`。
>
> 当前状态：`客户端验证进行中`。背包、银行、公会银行全页队列、本人 AH 主动查询及邮件边界已取得目标客户端样本；仍需完成下列边界场景后评审。

客户端采样使用仓库内的 [YiboStage0Probe](../../../_NonRelease/YiboStage0Probe/README.md)。诊断结果写入独立 SavedVariables，不进入 Vault 正式缓存。

## 1. 已由仓库确认

- YiboCore Public API 为 v6，可提供角色目录、页面 `context.characters`、服务器范围、统一入口、设置面板与角色缓存清理。
- 无需新增 Core 物品来源协议或 Capability。
- `/yva` 未被任何现有 `SLASH_*` 注册占用，且满足三个英文字母约束。
- 项目当前 `.toc` 基线为 Interface `50504`；正式实现时仍须以目标客户端构建为准。

## 2. 客户端探针矩阵

| 场景 | 候选 API / 事件 | 必须记录 | 状态 |
|---|---|---|---|
| 背包初次完整扫描 | `C_Container.GetContainerNumSlots`、`C_Container.GetContainerItemInfo` | bag `0..4` 共 100 槽，itemID/link/count 可读 | 已完成首轮验证 |
| 背包局部变化 | `BAG_UPDATE`、`BAG_UPDATE_DELAYED` | `BAG_UPDATE` 携带 bag ID；延迟事件无参数 | 已完成首轮验证 |
| 装备栏 | `GetInventoryItemID`、`GetInventoryItemLink`、`UNIT_INVENTORY_CHANGED` | `1..19` 可读；卸下槽位 7 后记录由 17 变 16，仅该槽位身份消失 | 已验证 |
| 个人银行打开 | `BANKFRAME_OPENED`、容器 API、银行相关 bag ID | 未打开仍暴露基础容器；打开后暴露基础容器与银行包 | 已完成首轮验证 |
| 个人银行变化 | `PLAYERBANKSLOTS_CHANGED`、`BAG_UPDATE*` | 单次移动触发 `BAG_UPDATE(11)`、`PLAYERBANKSLOTS_CHANGED(1)`、其它受影响 bag，最后触发无参数 `BAG_UPDATE_DELAYED` | 已完成首轮验证 |
| 公会银行打开 | `GUILDBANKFRAME_OPENED`、`QueryGuildBankTab`、`GetGuildBankItemInfo`、`GetGuildBankItemLink` | 两个同公会角色均自动请求 8/8 页、459 条，逐页占用数一致，均由更新事件完成 | 已验证 |
| 公会银行变化 | `GUILDBANKBAGSLOTS_CHANGED` | 已触发且无参数，刷新时必须重扫当前页签 | 已完成首轮验证 |
| 本人 AH 列表 | `C_AuctionHouse.QueryOwnedAuctions`、`OWNED_AUCTIONS_UPDATED` | 任意页打开均可主动查询；事件完成后稳定读取 45 条，切换多个页签结果一致 | 已验证 |
| AH 关闭/失效 | `AUCTION_HOUSE_CLOSED` 及关闭后再次读取 | 关闭后 `frame=false`、本人拍卖 API 返回 0；关闭后的结果不代表成功空扫描 | 已完成首轮验证 |
| 物品变体 | WoW 超链接类型与 payload | 已观察到非 `Hitem` 链接；具体类型与装备变体仍待新版探针补样 | 部分验证 |

## 3. 必测样本

1. 空背包、普通可堆叠物、拆堆、合堆、跨 bag 移动。
2. 同 itemID 但不同随机属性、升级、附魔或宝石的装备。
3. 未打开银行、打开银行、只改变一个银行包、关闭后查询。
4. 无公会、无权限页签、同一页签由两个角色访问、页签重命名。
5. 普通 AH 商品、可堆叠商品、取消、售出、到期；记录目标客户端实际字段。
6. 断线/重载、物品信息尚未缓存、API 返回 nil 或不完整结构。

## 3.1 首轮实测发现（2026-09-24）

- 测试环境使用 NDui 的背包/银行替代界面；原生 `BankFrame` 在银行关闭和打开时均为 `false`，不能作为银行开放依据。
- 未打开银行时手动执行探针：`eventOpen=false`，仍可读取 `28` 个槽位。这表明基础银行容器可能在银行关闭时继续由客户端缓存并暴露；不得据此宣布银行已打开或完成一次新扫描。
- 打开 NDui 银行后：收到 `BANKFRAME_OPENED`，`eventOpen=true`，可读取槽位从 `28` 增至 `80`，而 `BankFrame` 仍为 `false`。事件是本环境可靠的开放边界，额外 `52` 个槽位来自打开银行后暴露的银行包。
- 实现规则冻结为：只有收到 `BANKFRAME_OPENED` 后的稳定扫描才能把个人银行位置写为 `known/known-empty` 并替换正式缓存；银行关闭时可读到的基础容器只作诊断，不触发正式刷新，也不能把当时不可见的银行包解释成空。
- 探针 `0.1.2` 将 `accessible` 收紧为只认开放事件或可见银行框体，并把槽位暴露单列为 `containerExposure`。
- 银行打开状态下移动一次物品的事件顺序为：`BAG_UPDATE(11)` → `PLAYERBANKSLOTS_CHANGED(1)` → `BAG_UPDATE(0)` → `BAG_UPDATE(-2)` → `BAG_UPDATE_DELAYED()`，随后才收到 `BANKFRAME_CLOSED`。实现应把带 bag ID 的事件和基础银行槽事件用于标脏，在 `BAG_UPDATE_DELAYED` 统一读取并提交仍可访问的脏容器；关闭事件只结束开放状态，不用关闭后的残留可读性覆盖正式缓存。本次未留存移动前后的手动 `/ysp bank` 内容样本，因此只验证刷新事件与稳定边界，不据此断言具体槽位内容变化。

## 3.2 SavedVariables 脱敏分析（客户端 5.5.4 build 69934）

- 背包使用 `C_Container`，bag `0..4` 共 `100` 槽；同内容重复样本均为 `21` 条物品记录。
- `BAG_UPDATE` 实测携带 bag ID（样本含 `-2`、`0`、`1`、`2`），`BAG_UPDATE_DELAYED` 无参数。实现可按具体 bag 标脏，在延迟事件统一提交稳定快照。
- 装备槽 `1..19` 可读；`UNIT_INVENTORY_CHANGED` 已触发，但不依赖其参数定位单槽，按整套装备刷新。
- 装备变化复测中，第一次完整扫描得到 `17` 件，卸下槽位 `7` 的 `itemID=99115` 后第二次得到 `16` 件；逐槽比较只有槽位 `7` 从对应完整链接指纹变为 `nil`，其它槽位未变化。`UNIT_INVENTORY_CHANGED` 的实参在脱敏记录中表现为 table，不能作为稳定槽位 ID 使用，因此正式实现收到该事件后重扫 `1..19` 并按整套装备原子替换。
- 公会银行共 `8` 个页签，逐页采集均无 API 错误；`GUILDBANKBAGSLOTS_CHANGED` 实测无参数，因此只能重扫当前页签，不能假设事件提供 tab/slot。
- 公会银行全页队列与跨角色访问已验证：两个不同角色哈希分别完成 `8/8` 页扫描，均采集 `459` 条、收到 `8` 次事件响应且无错误/超时；每页占用记录数均为 `47/31/84/61/78/58/23/77`。两次脱敏内容指纹并非逐条完全相同，表示期间存在内容或堆叠变化，因此第二次结果必须按同一 `guildKey + tabID` 替换相应页签，不能按访问角色另存并累加。
- AH 页签解耦已验证：探针 `0.1.5` 在 `AUCTION_HOUSE_SHOW` 后主动调用 `C_AuctionHouse.QueryOwnedAuctions`，取得 `reason=auto-open`、`querySent=true`、`response=event`、`itemCount=45`。随后在多个不同页签读取均稳定为 `45` 条，不再依赖“取消”页加载列表。正式实现只在对应 `OWNED_AUCTIONS_UPDATED` 后替换缓存；打开瞬间未查询的 `0` 条不是 `known-empty`。
- AH 关闭边界首轮验证完成：两次会话均观察到 `AUCTION_HOUSE_SHOW`、查询更新事件和 `AUCTION_HOUSE_CLOSED`。关闭后样本为 `frame=false`、`eventOpen=false`，立即读取本人拍卖 API 得到 `0` 条；关闭前最后一次打开查询分别得到 `0` 条与 `8` 条。关闭后的 `0` 是不可访问状态下的 API 返回，不得作为 `known-empty` 写入或覆盖正式快照。已结束/撤销上架在 AH 重新打开查询后何时消失仍待验证。
- 若干容器记录的链接存在但无法按 `Hitem` 解析，说明严格身份必须支持非 `item` 超链接。探针 `0.1.3` 开始记录脱敏的 `linkType + payload`。

## 4. 通过标准

- 每个来源都能确定成功扫描边界、局部替换键、失败/不可用状态和事件稳定点。
- 示例数据能表达 `known`、`known-empty`、`not-yet-scanned`、`unavailable`、`partial`、`error` 与 `stale`。
- 同一个容器重复扫描业务内容相同时不产生变更；更新一个位置不改写其它位置。
- AH 与实体记录分开，公会银行不会因多个访问角色重复计数。
- 在记录实际 API 返回结构后，将本文件状态改为 `已验证`，并附客户端 build、日期和探针输出摘要；阶段 1 才可开始。
