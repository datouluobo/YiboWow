# Crafting Forever 模拟验证

运行 `lua _NonRelease/CraftingForever/Smoke.lua`：76项通过，真实Core与Crafting清单、模拟WoW API／帧。包含七专业位、配方学习事实及3003条快照的可见行复用。不会操作真实游戏或读写玩家SavedVariables。范围与待实机项见[实施与验收](../../YiboCrafting/Docs/Forever-专业与配方最小适配与验收.md)。

0.1.1增加诊断回归：失败配方定位、缺失API、所属专业返回、限制值脱敏、失败保留快照、报告窗口复用及24条追踪上限。实机0.1.0配方采集失败仍待报告定位，模拟通过不代表已修复。
