# Core 系列本地化静态检查

范围：TOC 实际加载的 Lua；排除注释、非发布文件和语言资源。候选项需要人工判断，布局风险不代表已确认缺陷。

Core 中文资源 535 项；缺英文 0；未知 key 0；格式参数不一致 0；重复 key 0。

| 插件 | 发布 Lua | 硬编码候选 | Core 语言引用 |
|---|---:|---:|---:|
| YiboCore | 53 | 0 | 576 |
| YiboReputation | 18 | 0 | 39 |

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

- `YiboCore/Data/Domains/Professions.lua:6` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:6` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:6` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:6` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:7` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:7` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:8` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:9` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:9` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:9` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:10` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:10` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:10` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:11` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:11` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:12` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:12` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:12` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:13` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:13` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:14` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:14` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:15` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:15` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:16` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/Data/Domains/Professions.lua:16` Client-native profession aliases; stable skill-line IDs own identity.
- `YiboCore/UI/ItemPicker.lua:97` Input normalization punctuation; not displayed.
- `YiboCore/UI/ItemPicker.lua:97` Input normalization punctuation; not displayed.
- `YiboCore/UI/Theme.lua:126` Font measurement specimen; not displayed.
- `YiboCore/UI/Theme.lua:127` Font measurement specimen; not displayed.
- `YiboCore/UI/Theme.lua:147` Font measurement specimen; not displayed.
- `YiboCore/UI/Theme.lua:148` Font measurement specimen; not displayed.
- `YiboCore/UI/Theme.lua:241` Font measurement specimen; not displayed.
- `YiboCore/Util/LevelFilter.lua:9` Input normalization punctuation; not displayed.
- `YiboReputation/Bootstrap.lua:47` Bilingual upgrade prompt used only when Core.Locale is unavailable; the normal startup path uses owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/Friendship.lua:3` Native client friendship labels used only to recognize older snapshot values; rendered fallback labels use owner resources.
- `YiboReputation/ReputationCatalog.lua:4` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:5` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:6` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:7` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:8` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:10` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:11` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:12` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:13` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:15` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:16` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:17` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:18` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:19` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:21` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:21` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:22` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:26` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:27` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:28` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:29` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:30` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:32` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:32` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:38` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:38` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:38` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:39` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:39` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:39` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:40` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:40` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:41` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:41` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:41` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:41` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:42` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:43` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:43` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:43` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:115` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:115` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:115` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:115` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationCatalog.lua:115` Native client faction headers used only as metadata lookup keys; displayed catalog headings use stable localized IDs.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.
- `YiboReputation/ReputationFormat.lua:19` Native client friendship labels used only to recognize older snapshot values; rendered status labels use owner resources.

## 静态目录人工核对

核对稳定 ID、显示名称资源及动态 API 名称边界：

- `YiboCore/Data/AddonCatalog.lua`
- `YiboCore/Runtime/CurrencyCatalog.lua`
- `YiboReputation/ReputationCatalog.lua`

## 固定尺寸布局人工复核

逐项结合英文预览检查自然宽度、换行与高度；实际客户端才可确认通过。

- `YiboCore/Data/Database.lua:22`
- `YiboCore/Data/Fields/CharacterArchive.lua:25`
- `YiboCore/Data/Fields/CharacterArchive.lua:28`
- `YiboCore/Data/Fields/CharacterArchive.lua:30`
- `YiboCore/Data/Fields/CharacterArchive.lua:32`
- `YiboCore/Data/Fields/CharacterArchive.lua:34`
- `YiboCore/Data/Fields/CharacterArchive.lua:35`
- `YiboCore/Data/Fields/CharacterArchive.lua:36`
- `YiboCore/Data/Fields/CharacterArchive.lua:37`
- `YiboCore/Data/Fields/CharacterArchive.lua:38`
- `YiboCore/Data/Fields/CharacterArchive.lua:39`
- `YiboCore/Data/Fields/CharacterArchive.lua:40`
- `YiboCore/UI/AccountPages/About.lua:172`
- `YiboCore/UI/AccountPages/About.lua:179`
- `YiboCore/UI/AccountPages/About.lua:208`
- `YiboCore/UI/AccountPages/About.lua:256`
- `YiboCore/UI/AccountPages/About.lua:261`
- `YiboCore/UI/AccountPages/About.lua:286`
- `YiboCore/UI/AccountPages/About.lua:312`
- `YiboCore/UI/AccountPages/About.lua:317`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:66`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:68`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:69`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:70`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:71`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:76`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:168`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:214`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:215`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:216`
- `YiboCore/UI/AccountPages/CharacterArchive.lua:217`
- `YiboCore/UI/AccountPages/Overview.lua:67`
- `YiboCore/UI/AccountPages/Overview.lua:69`
- `YiboCore/UI/AccountPages/Overview.lua:96`
- `YiboCore/UI/AccountPages/Overview.lua:98`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:26`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:38`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:39`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:44`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:65`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:71`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:78`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:117`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:120`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:121`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:152`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:284`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:392`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:487`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:509`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:568`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:864`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:876`
- `YiboCore/UI/AccountPages/SettingsWorkbench.lua:880`
- `YiboCore/UI/AccountView.lua:879`
- `YiboCore/UI/AccountView.lua:1052`
- `YiboCore/UI/AccountView.lua:1065`
- `YiboCore/UI/AccountView.lua:1069`
- `YiboCore/UI/AccountView.lua:1077`
- `YiboCore/UI/AccountView.lua:1115`
- `YiboCore/UI/BusinessItemActions.lua:292`
- `YiboCore/UI/BusinessItemActions.lua:303`
- `YiboCore/UI/BusinessItemActions.lua:307`
- `YiboCore/UI/Entry.lua:230`
- `YiboCore/UI/Entry.lua:233`
- `YiboCore/UI/Entry.lua:468`
- `YiboCore/UI/Entry.lua:471`
- `YiboCore/UI/EntryBar.lua:14`
- `YiboCore/UI/EntryBar.lua:35`
- `YiboCore/UI/EntryBar.lua:42`
- `YiboCore/UI/IconPicker.lua:45`
- `YiboCore/UI/IconPicker.lua:81`
- `YiboCore/UI/ItemPicker.lua:180`
- `YiboCore/UI/ItemPicker.lua:182`
- `YiboCore/UI/ItemPicker.lua:273`
- `YiboCore/UI/Theme.lua:227`
- `YiboCore/UI/Theme.lua:311`
- `YiboCore/UI/Theme.lua:312`
- `YiboCore/UI/Theme.lua:530`
- `YiboCore/UI/Theme.lua:674`
- `YiboCore/UI/Theme.lua:692`
- `YiboCore/UI/Theme.lua:694`
- `YiboCore/UI/Theme.lua:721`
- `YiboCore/UI/Theme.lua:727`
- `YiboCore/UI/Theme.lua:732`
- `YiboCore/UI/Theme.lua:736`
- `YiboCore/UI/Theme.lua:855`
- `YiboCore/UI/Theme.lua:867`
- `YiboReputation/AccountMatrixView.lua:259`
- `YiboReputation/AccountMatrixView.lua:337`
- `YiboReputation/CurrentCharacterPreview.lua:22`
- `YiboReputation/CurrentCharacterPreview.lua:27`
- `YiboReputation/CurrentCharacterPreview.lua:48`
- `YiboReputation/MonitoredPreview.lua:119`
