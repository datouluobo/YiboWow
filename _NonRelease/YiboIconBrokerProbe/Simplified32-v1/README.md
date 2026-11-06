# 32px 主意象简化预览

状态：待确认。日期：2026-10-13。

范围：YiboCore、YiboAutoOpen、YiboCrafting、YiboAltoBoss、YiboQuestBlocker。

保留现有主体意象和配色，减少金属配件、页线、鳞片分层、装饰圈层及碎高光。图标框内外空隙保持透明。

`Overview.png` 为内置 imagegen 生成的简化预览；`Compare32.png` 按行展示现用32px和草案32px，以及各自4倍最近邻放大，放大仅供观察像素形状。灰色属于对照画布，单枚 PNG 使用 RGBA 透明背景。

`Preview.py` 只生成本目录的五枚32px审阅PNG和对照，不输出游戏纹理、不变更探针引用。游戏内仍使用已接入的 `MediaTransparent/`。

下一阶段：确认简化方向后，导出相应测试纹理并更新临时客户端验证。
