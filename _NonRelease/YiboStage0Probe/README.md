# YiboStage0Probe

> 非发布、只读诊断插件。Vault 基础采集已有游戏内验证，日常 API 调用规则测试不需要加载本探针；仅在排查客户端 API、事件时序或大量邮件边界时按需启用。保留文件供复现和比对。

当前版本：`0.1.5`。银行开放状态以 `BANKFRAME_OPENED/CLOSED` 事件为主，并同时记录 `BankFrame`、`BankPanel`、`AccountBankPanel` 与容器暴露范围。银行未打开时客户端仍可能暴露基础银行容器，因此“槽位可读”只作为缓存可见性记录，不再判定银行已打开。物品链接探针同时记录 `item`、`battlepet` 等超链接类型及脱敏 payload。公会银行支持异步全页请求；拍卖行则在任意页签打开时主动查询本人上架列表，并等待更新事件后采样。

## 安装

将整个 `YiboStage0Probe` 目录复制到目标客户端的 `Interface/AddOns/`，确保最终路径为：

```text
Interface/AddOns/YiboStage0Probe/YiboStage0Probe.toc
```

角色选择页启用“加载过期插件”（如客户端把 Interface `50504` 判断为过期）。进入游戏后输入 `/ysp help`。

## 推荐测试流程

1. 登录后执行 `/ysp events on`、`/ysp bags`、`/ysp equipment`。
2. 移动、拆分、合并一组背包物品，再执行 `/ysp bags`。
3. 打开个人银行后执行 `/ysp bank`；只改变一个银行容器后再次执行。
4. 打开公会银行后执行 `/ysp guildbank all`，保持窗口打开直到报告全部页签完成；无需手动切换页签。
5. 在非“取消”页签打开拍卖行，等待自动报告完成；无需切换页签。必要时可用 `/ysp auction query` 手动重试。
6. 打开邮箱后执行 `/ysp mail`；等待 `MAIL_INBOX_UPDATE` 后再次执行。
7. 执行 `/ysp status`，然后 `/reload` 或正常退出游戏使 SavedVariables 落盘。

结果位于账号 SavedVariables 目录中的 `YiboStage0Probe.lua`；文件内的全局表名是 `YiboStage0ProbeDB`。提交验证结果时提供该文件即可。

## 安全与隐私

- 插件不调用收件、删除、退件、移动物品、上架、撤销或购买 API。
- 拍卖行打开后调用只读查询 `QueryOwnedAuctions`，不执行上架、撤销、购买或其它交易。
- 邮件发件人、主题、角色名和服务器名只保存长度与稳定哈希，不保存原文。
- 邮件正文从不读取。
- `/ysp clear` 只清除当前会话中可重新生成的诊断样本与事件记录。

## 命令

| 命令 | 用途 |
|---|---|
| `/ysp status` | 显示当前诊断数量 |
| `/ysp events on\|off` | 开关事件记录 |
| `/ysp bags` | 读取背包容器 |
| `/ysp equipment` | 读取装备槽 |
| `/ysp bank` | 读取个人银行候选容器 |
| `/ysp guildbank` | 读取当前公会银行页签 |
| `/ysp guildbank all` | 顺序请求并读取全部可访问页签，不切换 UI |
| `/ysp auction [query]` | 读取当前结果；带 `query` 时手动重发本人上架查询 |
| `/ysp mail` | 读取当前可见收件箱、附件与发票字段 |
| `/ysp snapshot` | 读取当前场景中可安全访问的来源 |
| `/ysp clear` | 清除当前会话诊断数据 |
