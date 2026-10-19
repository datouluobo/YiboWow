# Core 系列本地化静态检查

范围：TOC 实际加载的 Lua；排除注释、非发布文件和语言资源。候选项需要人工判断，布局风险不代表已确认缺陷。

Core 中文资源 541 项；缺英文 0；未知 key 0；格式参数不一致 0；重复 key 0。

| 插件 | 发布 Lua | 硬编码候选 | Core 语言引用 |
|---|---:|---:|---:|
| YiboCurrency | 16 | 0 | 260 |

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


## 静态目录人工核对

核对稳定 ID、显示名称资源及动态 API 名称边界：

- `YiboCurrency/Catalog.lua`

## 固定尺寸布局人工复核

逐项结合英文预览检查自然宽度、换行与高度；实际客户端才可确认通过。

- `YiboCurrency/AccountPage.lua:38`
- `YiboCurrency/AccountPage.lua:193`
- `YiboCurrency/AccountPage.lua:316`
- `YiboCurrency/AccountPage.lua:318`
- `YiboCurrency/AccountPage.lua:321`
- `YiboCurrency/ArchiveProvider.lua:27`
- `YiboCurrency/Settings.lua:178`
- `YiboCurrency/Settings.lua:204`
