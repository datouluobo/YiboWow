# Yibo 插件小图标设计范例：货币管家

本范例记录 `YiboCurrency` 最终 Logo 的正向设计流程，适用于需要在《魔兽世界》插件列表、小地图或 Broker 中保持辨识度的 Yibo 系列图标。

## 1. 先定义小尺寸任务

Logo 的首要验收尺寸是 `32×32`，不是主图尺寸。目标是在 32px 下先认出主体，再看出业务含义；高分辨率版本只用于保留平滑边缘与有限的材质感。

固定约束：

- 透明背景，透明区域延伸到画布边缘。
- 使用 Yibo 系列的深青绿作为主体色，并以金色作为货币强调色。
- 只使用一个可辨认的奇幻物件，避免通用应用图标、面板或文字。
- 主体最多承载两种露出物；超过两种会在 32px 中挤成噪点。

## 2. 将业务语义压缩为可读物件

货币管家不是“只看金币”的插件：它还汇总标准货币、系统虚拟货币与物品代币。因此最终语义由三层组成：

1. **青绿束口钱袋**：表达“集中保管与整理”。
2. **狮头金币**：表达常见货币，同时呼应魔兽世界物件图标的质感。
3. **紫色宝石**：表达金币以外的泛用代币/货币资源。

钱袋的金色编绳必须保留。它让主体在缩小后仍明显是“钱袋”，而不是普通容器。

## 3. 生成主图时的构图规则

以约 128px 的视觉信息量设计主图，但不依赖复杂细节。推荐提示结构：

```text
128px-designed Warcraft add-on icon, judged at 32px.
One smooth dark-teal drawstring money pouch holds exactly two large objects:
a gold coin with a simple raised lion head on the left and one purple gemstone on the right.
A thick gold braided drawstring wraps the pouch neck, with two short downward cord ends.
Broad clean shading, genuinely transparent alpha background.
No extra decoration, text, frame, shadow, microtexture, or additional objects.
```

关键是限制对象数量、让钱袋占据主要轮廓，并让金币与宝石分别占据足够大的色块。狮头只作为金币的大型压纹，不应依赖细小线条传达语义。

## 4. 用真实 32px 验收

直接将主图高质量缩放为 `32×32` 透明 PNG，再检查：

- 一眼是否能认出钱袋；
- 金色与紫色是否仍分离可见；
- 青绿轮廓是否没有糊成深色块；
- 四角 Alpha 是否为 0，且没有棋盘格或底色被烘焙进资源。

若主体难辨认，应先减少对象或扩大主色块，而不是增加高光、描边或更多纹样。

## 5. 产出与接入

定稿后从同一透明主图导出：

- `YiboCurrencyIcon-v1.png`（512px 主图）
- `YiboCurrencyIcon-v1.tga`（带 Alpha，供游戏纹理使用）
- `YiboCurrencyIcon-v1-128.png`
- `YiboCurrencyIcon-v1-64.png`
- `YiboCurrencyIcon-v1-32.png`
- `YiboCurrencyIcon-v1-31.png`
- `YiboCurrencyIcon-v1-16.png`

在插件 `.toc` 中声明：

```toc
## IconTexture: Interface\AddOns\YiboCurrency\Media\YiboCurrencyIcon-v1
```

最后分别查看 32px PNG 与游戏内插件列表/小地图实际显示，确认透明边缘、主体识别与系列配色都符合预期。
