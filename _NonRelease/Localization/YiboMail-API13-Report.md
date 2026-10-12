# Core 系列本地化静态检查

范围：TOC 实际加载的 Lua；排除注释、非发布文件和语言资源。候选项需要人工判断，布局风险不代表已确认缺陷。

Core 中文资源 532 项；缺英文 0；未知 key 0；格式参数不一致 0；重复 key 0。

| 插件 | 发布 Lua | 硬编码候选 | Core 语言引用 |
|---|---:|---:|---:|
| YiboMail | 26 | 0 | 816 |

区域覆盖度须按验收清单加权评估；上表字符串数量不是覆盖百分比。

## 资源问题

- missingEnglish: []
- extraEnglish: []
- duplicateKeys: []
- formatMismatch: []
- unknownKeys: []

## 硬编码候选

无中文硬编码候选。

## 已审查例外

- `YiboMail/SendRules.lua:22` Native item-category markers used only to recognize obsolete client categories; never displayed.
- `YiboMail/SendRules.lua:22` Native item-category markers used only to recognize obsolete client categories; never displayed.

## 静态目录人工核对

核对稳定 ID、显示名称资源及动态 API 名称边界：


## 固定尺寸布局人工复核

逐项结合英文预览检查自然宽度、换行与高度；实际客户端才可确认通过。

- `YiboMail/AccountPage.lua:217`
- `YiboMail/AccountPage.lua:222`
- `YiboMail/AccountPage.lua:228`
- `YiboMail/AccountPage.lua:235`
- `YiboMail/AccountPage.lua:238`
- `YiboMail/AccountPage.lua:290`
- `YiboMail/AccountPage.lua:324`
- `YiboMail/AccountPage.lua:345`
- `YiboMail/AccountPage.lua:587`
- `YiboMail/AccountPage.lua:653`
- `YiboMail/CacheUI.lua:52`
- `YiboMail/CacheUI.lua:53`
- `YiboMail/CacheUI.lua:58`
- `YiboMail/CacheUI.lua:236`
- `YiboMail/CacheUI.lua:338`
- `YiboMail/CacheUI.lua:584`
- `YiboMail/CacheUI.lua:603`
- `YiboMail/CacheUI.lua:624`
- `YiboMail/NativeUI.lua:56`
- `YiboMail/NativeUI.lua:334`
- `YiboMail/NativeUI.lua:337`
- `YiboMail/NativeUI.lua:359`
- `YiboMail/NativeUI.lua:374`
- `YiboMail/NativeUI.lua:375`
- `YiboMail/NativeUI.lua:378`
- `YiboMail/NativeUI.lua:380`
- `YiboMail/NativeUI.lua:382`
- `YiboMail/NativeUI.lua:383`
- `YiboMail/NativeUI.lua:384`
- `YiboMail/NativeUI.lua:385`
- `YiboMail/NativeUI.lua:404`
- `YiboMail/NativeUI.lua:405`
- `YiboMail/NativeUI.lua:406`
- `YiboMail/NativeUI.lua:407`
- `YiboMail/NativeUI.lua:444`
- `YiboMail/NativeUI.lua:455`
- `YiboMail/NativeUI.lua:457`
- `YiboMail/NativeUI.lua:467`
- `YiboMail/NativeUI.lua:484`
- `YiboMail/NativeUI.lua:724`
- `YiboMail/NativeUI.lua:986`
- `YiboMail/NativeUI.lua:1087`
- `YiboMail/NativeUI.lua:1208`
- `YiboMail/NativeUI.lua:1331`
- `YiboMail/NativeUI.lua:1338`
- `YiboMail/NativeUI.lua:1344`
- `YiboMail/NativeUI.lua:1547`
- `YiboMail/NativeUI.lua:1680`
- `YiboMail/NativeUI.lua:1710`
- `YiboMail/RecipientUI.lua:34`
- `YiboMail/RecipientUI.lua:54`
- `YiboMail/RecipientUI.lua:56`
- `YiboMail/RecipientUI.lua:72`
- `YiboMail/RuleSendUI.lua:30`
- `YiboMail/RuleSendUI.lua:41`
- `YiboMail/RuleSendUI.lua:61`
- `YiboMail/RuleSendUI.lua:167`
- `YiboMail/RuleSendUI.lua:173`
- `YiboMail/RuleSendUI.lua:203`
- `YiboMail/RuleSendUI.lua:219`
- `YiboMail/RuleSendUI.lua:224`
- `YiboMail/SendRulesSettings.lua:44`
- `YiboMail/SendRulesSettings.lua:45`
- `YiboMail/SendRulesSettings.lua:46`
- `YiboMail/SendRulesSettings.lua:87`
- `YiboMail/SendRulesSettings.lua:162`
- `YiboMail/SendRulesSettings.lua:359`
- `YiboMail/SendRulesSettings.lua:392`
- `YiboMail/SendRulesSettings.lua:463`
