# YiboMail 规则寄实施验收记录

日期：2026-10-08。版本：1.2.0-api1。

状态：代码已实施；Lua 5.1 自动验证通过；目标客户端验收待完成。

### 2026-10-08 服务器与阵营隔离

- 规则在账号内保存，按收件人服务器与阵营隔离；服务器比较复用地址规范化与忽略空白的键，同服务器阵营未知时仍保留冲突保护。
- 自动回归覆盖同物品／分类跨服务器保存、同服冲突、服务器与阵营切换、跨服未知阵营不占位、快捷拖放不改写另一服务器的规则、跨服已跳过条目隐藏，以及发送前服务器复核。
- 9 项 Mail 自动验证通过，TOC 中 22 个 Lua 文件语法检查通过。客户端仍需在两台服务器、两种阵营分别打开规则寄，核对仅显示适用目标；管理页应保留全部规则，并能按服务器名搜索。BOA 由发件箱手动处理。

## 自动验证

2026-10-08 规则管理列表：右侧采用 Core 纵向滚动区域，所有收件人及规则共享同一滚动内容；搜索位于顶部，收件人及规则数量固定在滚动区域外的底部。滚动条仅在内容超出时出现，无滚动条时释放右侧占位。展开／折叠及文字换行更新内容高度，编辑时定位收件人。RuleSendUISpec 覆盖展开全部条目、折叠与搜索后滚动条消失、恢复展开后滚动条出现、长文字换行、动态占位释放及统计底部锚点。

本次 Core 公共能力核对：列表使用 Core UITheme 的文本、按钮、颜色及 `CreateScrollFrame`／`SetContentHeight`，滚动条显隐、鼠标滚轮和动态占位由 Core 处理；设置窗口继续由 Core 工作台承载。行高测量、折叠状态、滚动内容与统计文本属于 Mail 业务布局。新增调用复用既有 UITheme 滚动能力，最低 Core 要求沿用当前 Bootstrap 检查；未改变台账中已列公共契约的接入状态。

从仓库根目录执行：

```powershell
lua YiboMail/_NonRelease/Tests/RuleSendSpec.lua
lua YiboMail/_NonRelease/Tests/RuleSendUISpec.lua
lua YiboMail/_NonRelease/Tests/InboxReleaseSpec.lua
lua YiboMail/_NonRelease/Tests/RecipientUISpec.lua
lua YiboMail/_NonRelease/Tests/RecipientsSpec.lua
lua YiboMail/_NonRelease/Tests/NativeInboxSpec.lua
lua YiboMail/_NonRelease/Tests/WorkspaceSpec.lua
lua YiboMail/_NonRelease/Tests/MailRuntimeSpec.lua
lua YiboMail/_NonRelease/Tests/MailAPIConsumerSpec.lua
```

RuleSendSpec 使用真实规则模型、Compose 与发送控制器，覆盖数据保留与一次迁移、分类和指定物品优先级、排除不回落、运行时收件人冲突、跳过恢复、同收件人合装与超容量下一封、主按钮和快捷联系人状态共享、等待期间重复点击与切换阻止、草稿指纹、失败和超时不重试、现有历史单次写入。

RuleSendUISpec 复用原生帧模拟环境，加载真实 Core 主题、输入、滚动、ItemPicker 和 Mail 新 UI，覆盖第三标签与原生发送按钮显隐、设置三标签、物品选择与保存、未保存修改保护、指定规则定位、窄宽度编辑、通讯录选择只修改规则草稿，以及两种拖放语义、拖放实际数量、单次发送尝试与装填回退。

其它七组验证覆盖现有收件队列、账号工作区、邮件快照与公共 API、通讯录和发布 TOC，确认功能扩展没有改变这些既有行为。全部正式 Lua 文件完成 Lua 5.1 语法检查。

模拟结果不能确认游戏内尺寸、客户端保护限制、附件归还或原生邮件事件顺序。

2026-10-07 补充：RuleSendUISpec 覆盖同收件人多规则合并、已装填与剩余物品汇总、首行名称与数量、右上角整组跳过／恢复、物品全宽换行、滚动条出现及消失后的条目宽度、顶行收件人框与发件箱共用位置及尺寸、附件第二行空位的管理入口、整行寄送状态、两页附件位于金额／状态下方及切页一致性。RuleSendSpec 覆盖批量跳过先归还已装填附件、恢复原数量及发送期间停止整批操作。目标客户端仍需核对实际尺寸与装填／撤下／发送后的名称更新。

标签恢复补充：`settings.inbox.tab` 保存四个业务标签的稳定标识，与原生 `page` 分开。RuleSendUISpec 覆盖四页关闭重开、运行状态重置、首次安装与 OnShow 延迟恢复、恢复前关闭邮箱、原生临时页不覆盖选择，以及旧／非法记录和规则页不可用的回退。规则寄恢复时重新扫描；关闭邮箱继续清除临时跳过和装填状态。游戏内核对从规则寄关闭后重开，以及 `/reload` 后首次打开邮箱。

## 游戏内验收

TOC 增加了文件，完整退出客户端并重新进入，启用当前 YiboCore 与 YiboMail。

1. 核对“收件箱／附件箱／发件箱／规则寄”切换，顶行收件人框位置和尺寸一致，规则寄管理入口位于附件第二行右侧空位；发件箱金额设置与规则寄状态均位于附件上方，两页附件及发送按钮位置一致。检查同收件人合并、右上角整组跳过／恢复与滚动条显隐时的条目宽度。检查正常与较小屏幕、不同 UI 缩放及长规则列表。
2. Core 设置打开 YiboMail，检查“业务设置／规则管理／数据与缓存”；新建、编辑、搜索、筛选、角色适用范围与启停。邮箱管理及冲突处理能直接选中标签、定位规则；未保存时确认保护有效。
3. 使用少量测试物品验证游戏分类与子分类，分类排除、指定物品例外、规则收件人为当前角色时跳过。信息未加载时显示待识别。分类不凭名称猜测。
4. 点击规则装填；主按钮再次点击发送；快捷联系人同样执行两次点击。交替使用两个入口，并在装填／发送期间快速连点，确保没有重复调用或误发给上一位联系人。
5. 同收件人多规则合装与超过单封容量分封。每次发送确认后仍需下一次点击装填；没有快捷格的收件人可从默认范围处理。核对预览与实际附件数量一致。
6. 临时跳过、恢复、装填后跳过、切换目标、修改背包、修改规则或实际附件；已有主题、正文、金额、COD 或附件草稿受到保护。关闭重开邮箱清除会话跳过，不清除规则。
7. 制造失败、确认提示、战斗、邮箱关闭及收件队列占用，确保停在当前状态并显示原因；发送结果延迟时等待，超时后不自动重试。
8. 在规则寄页拖物品到快捷联系人，确认新规则与已有规则改地址；取消后物品仍在背包。发件箱拖入一组物品，核对数量、收件人、只尝试一次发送。客户端拒绝直接发送时，草稿仍可检查并手动发送。
9. 现有历史核对规则寄、普通发件和快捷拖放的实际收件人、附件与结果，每次操作只有一条记录；成功为已发送／在途，不自动宣称送达。

## API 核对来源

客户端 API 兼容路径参考 Blizzard UI/API 文档镜像的 [ItemDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) 与 [MailFrame.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua)。这些参考来自 live 分支，不能替代 Interface 50504 的运行时核对；实现同时探测全局与 C_Item 分类函数，并复用当前客户端原生发送处理器。

## 0.11.1 小退保护错误修复（待游戏内复测）

用户报告登录后点击小退出现 ADDON_ACTION_FORBIDDEN，归因插件为 YiboMail，函数为 UNKNOWN，堆栈终止于 GameMenuFrame 的菜单回调。该堆栈没有包含首次污染位置，不能据此宣称已定位唯一原因。

代码核对发现：规则寄初始化使用了原生 MailFrameTab3 命名和 CharacterFrameTabButtonTemplate，调用 PanelTemplates_SetNumTabs／SetTab 写入 MailFrame.numTabs／selectedTab，并在登录期间初始化邮箱界面。现已改为插件私有主题按钮，保持第三标签入口，但不注册到原生标签表；邮箱界面推迟到实际打开时初始化。规则页打开、浏览页恢复和 Compose 原生页切换通过存在时的 securecallfunction 分派原生处理函数。该分派不绕过客户端保护限制。

参考源为 classic 分支的 [SharedUIPanelTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.lua) 和 [GameMenuFrame.lua](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_GameMenu/Shared/GameMenuFrame.lua)。原生标签字段写入是已确认的代码行为；它与本次小退失败的因果关系仍须客户端复测。

RuleSendUISpec 新增断言：隐藏邮箱时重复安装请求只注册一次打开回调、不创建规则界面；规则标签不使用原生命名／模板，也不调用原生标签注册／选择函数；原生页切换使用 securecallfunction。RuleSendUISpec、RuleSendSpec、NativeInboxSpec、InboxReleaseSpec 和 RecipientUISpec 五组回归通过，正式 Lua 文件语法检查通过。

复测流程：完整退出并重启客户端加载 0.11.1；先登录后直接小退，再登录并打开邮箱、切换三标签后关闭邮箱并小退，最后打开规则管理及通讯录后关闭并小退。需分别确认是否还出现新的保护错误；普通模拟帧不能证明客户端没有 taint。
