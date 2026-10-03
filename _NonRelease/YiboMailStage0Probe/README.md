# YiboMailStage0Probe

YiboMail 专用的非发布、只读客户端探针。目录名、`.toc` 文件名、SavedVariables 和 Slash 命令均独立于已有的 Vault 阶段 0 探针。它不执行收取、退回、删除或发件操作，也不读取邮件正文。

`0.1.1` 起，本次打开邮箱尚未收到 `MAIL_INBOX_UPDATE` 时标记为 `pending`；不会把打开瞬间的旧读数或暂时的 `0/0` 标为正式覆盖状态。

## 安装

将本目录以同名目录联接或复制到目标客户端的 `Interface/AddOns/`，最终路径应为：

```text
Interface/AddOns/YiboMailStage0Probe/YiboMailStage0Probe.toc
```

在角色选择页启用插件；若客户端提示过期，勾选“加载过期插件”。本探针可与 `YiboStage0Probe` 共存，正式 YiboMail 命令 `/yma` 尚未占用。

## 验证步骤

1. 登录后输入 `/ymp help`，再输入 `/ymp events on` 和 `/ymp watch on`。
2. 打开邮箱，输入 `/ymp mail`。记录可见数／总数、未扫描数、同签名组与覆盖状态。刷新时自动重扫；保持打开 60 秒后再次自动采样。
3. 对空邮箱、附件、金币、COD、重复邮件及有条件取得的 99／100 封和 `total > current` 邮箱，分别在场景前后输入 `/ymp mail`。同签名组只用于指出身份歧义。
4. 如果本来就要收取邮件，可在原生邮箱中手动取一件附件或金币。探针被动记录函数调用、事件和后续扫描；`pending-update` 只表示调用发生，不表示成功。
5. 关闭邮箱后输入 `/ymp mail`，核对残留 API 读数的覆盖状态为 `unavailable`。执行 `/ymp status`，然后 `/reload` 或正常退出使数据落盘。

结果位于 `WTF/Account/<账号>/SavedVariables/YiboMailStage0Probe.lua`。在安装了 Lua 的电脑上，可运行 `lua Tools/AnalyzeSavedVariables.lua <SavedVariables 文件路径>` 提取摘要。原始文件保留客户端 build、附件槽位与事件时间顺序；发件人、主题、角色和服务器名仅保存长度与哈希。
