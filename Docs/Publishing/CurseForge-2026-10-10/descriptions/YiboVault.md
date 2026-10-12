# YiboVault

**Dependencies:** Required — [YiboCore](https://www.curseforge.com/wow/addons/yibocore) (API v9+). Optional data source — [YiboMail](https://www.curseforge.com/wow/addons/yibomail): Vault uses its mailbox snapshots when available and falls back to Vault's own mailbox cache otherwise. Optional consumer — [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency): Currency can read recorded item-token counts from Vault.

## The YiboCore framework

YiboCore is the shared account window, character directory, and settings framework for Yibo addons. This addon requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore) to provide its account page and shared entry.

Cache items and equipped gear across your characters and supported storage locations. Search the account in one place, or hover an item to see its recorded counts and locations across characters and guilds.

## What makes it useful

Vault brings recorded items and equipment from every supported character and storage location into one searchable account view. Item tooltips can summarize the recorded account count, character holders, guild tabs, and storage locations together. This addresses a common pain point: players can find where an item is stored without opening each character's bags, banks, or guild tabs one by one.

## Features

- Account-wide snapshots of character bags, equipped gear, personal banks, mail attachments, auction listings, and guild-bank tabs.
- Search recorded items by name or item ID.
- Item tooltips gather recorded counts and locations across characters and guilds.
- Recorded capacity and free-slot summaries for supported storage locations.
- Optional YiboMail mailbox snapshots as Vault's preferred source, with Vault's own mailbox cache as fallback; optional read-only item-token data for YiboCurrency.

## Getting started

Use `/yva open` to search items by name or ID. Log into characters and open banks, mailboxes, auction houses, or guild-bank tabs to update those snapshots. Hover an item to see recorded counts and storage locations collected across the account.

## Requirements and data

Mists of Pandaria Classic; packaged for client 5.5.4. Requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore), API v9 or later. Keep Core updated together with this addon.

Vault displays saved snapshots, not live access to offline characters. Unknown sources remain unknown; partially visible mail is marked as partial. When YiboMail is available, Vault reads its mailbox snapshots per character; if Mail is unavailable or has no usable snapshot, Vault falls back to its own mailbox cache. The two sources are not added together. YiboCurrency can read Vault's recorded personal item-token counts; it does not provide data to Vault. Guild storage and auction listings remain distinct from personal holdings.

## Feedback

Report issues in this project's CurseForge comments with the addon version, client version, and steps to reproduce.

---

# YiboVault · 物品总览

**依赖：** 强依赖 — [YiboCore](https://www.curseforge.com/wow/addons/yibocore)（API v9+）。可选数据来源 — [YiboMail](https://www.curseforge.com/wow/addons/yibomail)：Mail 快照可用时由 Vault 优先读取，不可用时回退到 Vault 自有邮箱缓存。可选数据调用方 — [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency)：Currency 可从 Vault 读取已记录的物品代币数量。



## YiboCore 框架

YiboCore 为 Yibo 插件提供统一账号窗口、角色目录与设置工作台。本插件需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) 承载账号页和统一入口。

集中缓存各角色在支持位置的物品与装备；搜索物品或悬停提示即可查看账号内的记录数量、持有角色、公会页签和存放位置。

## 特点与解决的问题

所有角色已记录的背包、装备、个人银行、邮件附件、拍卖上架和公会银行物品集中在一个可搜索的账号视图中；物品提示可汇总跨角色与公会的数量和位置，并保留来源扫描状态与快照时效。
解决的痛点：无需逐个登录角色、打开背包和银行页签来找物品；一次搜索或悬停就能定位已缓存物品的持有角色和位置，同时识别尚未扫描的来源。

## 主要功能

- 缓存各角色的背包、装备、个人银行、邮件附件、本人拍卖上架及公会银行页签快照。
- 按物品名称或 ID 搜索已记录物品。
- 物品提示集中展示账号内各角色与公会的已记录数量和存放位置。
- 显示适用仓储位置已采集的容量与空位摘要。
- 可选优先读取 YiboMail 邮箱快照；Mail 不可用时回退 Vault 自有邮箱缓存，两份来源不会相加。
- YiboCurrency 可选读取 Vault 已记录的个人物品代币数量；数据方向为 Vault → Currency。

## 开始使用

使用 `/yva open`，按物品名称或 ID 搜索。登录各角色并打开银行、邮箱、拍卖行或公会银行页签更新快照；悬停物品可集中查看账号内已记录的数量与位置。

## 运行需求与数据说明

熊猫人之谜经典版；当前发布包对应 5.5.4 客户端。需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) API v9 或更新版本，建议与业务插件一起更新。

Vault 展示库存快照，不会实时访问离线角色。安装并启用 YiboMail 后，Vault 按角色优先读取 Mail 邮箱快照；Mail 不可用或没有可用快照时回退到 Vault 自有邮箱缓存，两份数据不会相加。没有快照的来源仍标为未知，部分可见邮件保留部分扫描标记；公会库存与拍卖上架区别于个人持有。YiboCurrency 可读取 Vault 已记录的个人物品代币数量，Currency 不向 Vault 提供数据。

## 问题反馈

请在本项目 CurseForge 评论中提供插件版本、客户端版本与复现步骤。
