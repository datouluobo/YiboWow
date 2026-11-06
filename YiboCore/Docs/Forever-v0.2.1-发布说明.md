# YiboCore Forever 0.2.1 / API13

2026-11-05。适用客户端：无限服1.60.1，Interface16001。

## 本版功能

- 原生完整双名、GUID角色目录、角色身份/位置和专业档案。
- 统一账号窗口、角色档案与设置工作台。
- Core小地图/Broker入口、可选内置信息条与账号悬停预览。
- 短名、排序、角色过滤、主表/悬停等级过滤及窗口偏好。
- 跟随客户端、手动中文和English；英文档案与完整导航自适应。

## 安装与使用

将玩家包中的`YiboCore`目录安装至无限客户端`Interface/AddOns/`。安装后启用YiboCore，使用`/yco`打开主窗口，`/yco settings`打开设置。

已有无限服安装可退出游戏后覆盖同名代码目录。保留WTF及SavedVariables；本版继续使用`YiboCoreForeverDB`，schema11和角色GUID保持。默认仅Core统一入口显示；按需在设置中启用独立入口或内置信息条。业务页面由相应Forever业务插件提供，按各自发行说明安装。

## 版本与数据

Forever版本0.2.1，公开API13。与已验0.2.0候选相比，运行Lua仅调整Forever版本标识；姓名、窗口、入口和保存行为沿用本轮用户确认的字节。Mists和Retail版本分别维护。

## English

First Forever release for client 1.60.1 / Interface16001. Includes complete two-part character names, a GUID-based roster, identity/location and profession profiles, a shared account window and settings workspace, managed minimap/Broker entries and preview tooltips, character preferences, persistent level filters and Chinese/English UI.

Install the ZIP's `YiboCore` folder in the Forever client's `Interface/AddOns` directory. Use `/yco` or `/yco settings`. Existing Forever installations can be updated by closing the game and overlaying the code folder while retaining WTF/SavedVariables. This release keeps `YiboCoreForeverDB`, schema11 and character GUIDs. Install supported business features from their respective Forever releases. Public API remains 13.

