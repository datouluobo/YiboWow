# YBP 1.8.3：Retail Core 维护接入

2026-10-28，用户批准配套Retail Core发布YBP修订版。代码与离线检查完成，客户端新增交互待验，未发布。

## 行为与边界

Retail与Mists通过现有共享Maintenance/CoreDebugAdapter登记Core业务设置；按用户要求，两端新存档默认开启维护模式，Core就绪后即登记主导航页面。已有明确关闭偏好继续保留，可通过/ybp debug打开设置并开启。共享适配器在Core门槛通过后先幂等初始化维护默认值，避免ADDON_LOADED早于PLAYER_LOGIN时漏注册默认页。复用路线校准、融合工作台、脚印管理、导出四页签及公共窗口／输入框，无独立设置壳或新增常规入口。关闭维护模式注销页面；重复登录／CORE_READY不重复登记，Core未就绪等待，缺失／API旧／能力不足只停用维护增强，路线继续独立运行。

接入要求保持API13、localization:1、basic-input:1、account-view:2、account-surface-budget:1和实际使用方法。中文／英文状态去除固定客户端名称，依赖提示改为API与能力要求，不要求Retail插件具有Mists版本号。

共享适配器无新增客户端原生API；真实身份仍由Flavor.lua提供，支持集合仅Retail／Mists。现有Maintenance目录为跨目标共享职责，本次无需新增目标原生适配模块。路线、脚印与参数仍归YBP，SavedVariables名称及业务schema不变。

既有universal维护包例外保留：默认与Mainline清单属于Retail，Mists清单属于Mists，均只加载同一份适配器。未增加TOC或XML引用，无文件迁移，保留旧文件覆盖不会增加第二适配器加载点。Interface同步本次已核实的120105／50504。新增／修改Slash注册不适用：沿用现有/ybp。

## 验证

- 真实Flavor入口分别模拟Retail／Mists：Core缺失、API旧、能力缺失、未就绪、晚就绪、重复通知、开启／关闭／重开、页面失败回滚及资源格式，共988项通过。
- 真实CoreDebugView中英文各4页签、91动作、空地图／选中宠物、不同宽度；地图跟随默认上下文模拟通过。实际按钮交互仍待客户端。
- 3份TOC加载26个Lua文件语法通过。统一构建及语言静态检查结果随发布准备补充。
- Core现有R4加载、独立存档、安装覆盖和恢复证据复用，新增YBP维护交互不能据此记为通过。

## 客户端剩余

Retail：重载后/ybp debug打开Core中的YBP设置，开启维护模式，查看四页签与导出输入，关闭／再开启，无新增相关报错；reload后设置和入口正常。Mists本次共享适配器与状态文案变化做简短回归。其它语言／IME等未验边界仍按历史记录保留，正式发行检查依据声明范围完成。

公共能力审查：CAP-002输入、CAP-004设置与页面、CAP-009语言为既有调用在Retail新增接入；CAP-001／003／007／008／010无本轮新增需求。Core运行接口无变化；离线兽栏及“已拥有”仍归后续DEV-002／005。
