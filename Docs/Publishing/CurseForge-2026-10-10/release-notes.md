# 当前发布版功能概览 / Release overviews

状态：待发布草稿。每段仅对应列明的已发布版本，可用于当前文件缺失的 Changelog。这里只补可确认的功能概览；已有精确修复日志的版本优先使用原日志，不据此编造历史发布日期或改写旧文件对应版本。

## YiboAltoBoss · 2.5.1

### English

- Account-wide progress for Sha of Anger, Galleon, Nalak, Oondasta, the Four Celestials, and Ordos.
- Raid and dungeon lockouts grouped by expansion, with encounter details and configurable pinned instances.
- Seasonal boss tracking during supported holiday windows, including Coren Direbrew during Brewfest.
- Warbringer observations, custom NPC targets, and normal-dungeon entry history.
- Account page and optional entry hover previews through YiboCore.

### 中文

- 跨角色查看怒之煞、炮舰、纳拉克、乌达斯塔、四天神和斡耳朵斯进度。
- 按资料片查看团队与五人副本锁定、首领详情，并固定常看的副本。
- 在支持的节日开放期追踪节日首领，包括美酒节的科林·烈酒。
- 记录战争使者观察、自定义 NPC 目标及普通五人副本进入次数。
- 通过 YiboCore 统一账号页和可选入口悬停预览查看。

发布范围说明：观察与刷新信息是记录，不保证实际刷新时间。四天神合并为一个周常条目；节日内容仅在适用活动窗口出现。

## YiboAutoOpen · 1.2.2

### English

- Scan existing inventory on login and process allowlisted containers in sequence.
- Add or remove containers using item IDs, links, or names.
- Pause during combat, casting, looting, sensitive interfaces, or insufficient free bag space.
- Retry handling lets other items proceed when one container fails.
- Optional Core settings include a source allowlist for moving native binding-confirmation dialogs near the cursor.

### 中文

- 登录时扫描已有物品，按队列开启允许目录中的容器。
- 按物品 ID、链接或名称添加和删除目录项。
- 战斗、施法、拾取、敏感界面或背包空位不足时暂停。
- 单个容器失败时先处理其它物品，按项重试与隔离。
- 可选 Core 设置支持来源白名单，将原生绑定确认框移至鼠标附近。

发布范围说明：绑定确认仍需玩家亲自点击；插件不修改自动拾取设置、不选择奖励。深渊蚌等在 MoP 客户端要求手动开启的物品会跳过。

## YiboBeastPaths · 1.6

### English

- World-map route overlays and nearby route segments on the minimap.
- Start markers and tooltips with pet and footprint information.
- Ten pets: Stompy, Patrannache, Portent, Bristlespine, Bloodtooth, Hexapos, Rockhide the Immovable, Savage, Glimmer, and Bombyx.
- Toggle routes from the map button or slash command.

### 中文

- 世界地图覆盖路线，小地图显示附近局部路段。
- 提供起点标记，以及宠物和脚印信息提示。
- 收录重蹄、帕特兰纳克、噩兆、刺脊、血牙、赫克萨波斯、洛克海德、萨维奇、微光之蛾和邦比。
- 通过地图按钮或命令切换路线显示。

发布范围说明：路线用于搜索参考，不检测宠物实时位置，也不保证刷新。正式服与 MoP Classic 使用各自客户端入口；可选 MoP 路线维护工具才需要 Core。

## YiboBuilds · 1.4.2

### English

- Account overview of current and backup specialization snapshots.
- A character workbench with equipment model, talents, and glyphs.
- Separate equipment snapshots for each talent slot.
- Equipment enhancement panels with available gem, enchant, engineering, and profession candidates.
- Current-character gem socketing and supported enhancement actions, plus account hover previews.

### 中文

- 账号总览展示当前及备用专精快照。
- 单角色工作台展示装备人偶、天赋与雕文。
- 按天赋槽位分别保存装备快照。
- 装备提升面板列出可用的宝石、附魔、工程及专业候选。
- 支持当前角色镶嵌与适用增强操作，并提供账号悬停预览。

发布范围说明：离线角色显示已保存快照；装备操作仅适用于当前角色，并受实际物品、专业及游戏交互条件限制。

## YiboCore · 1.9.0-api10

### English

- A shared window for installed Yibo business pages.
- Character directory, realm scope, filtering, and sorting.
- One settings workspace for Core and supported Yibo addons.
- A default Core Broker/minimap entry and configurable optional addon entries.
- Shared account previews and public infrastructure used by Yibo addons.

### 中文

- 为已安装的 Yibo 业务插件承载统一账号页面。
- 统一角色目录、服务器范围、过滤与排序。
- Core 与支持的 Yibo 插件共用设置工作台。
- 默认 Core Broker/小地图入口，以及可配置的业务插件入口。
- 统一账号悬停预览与系列插件使用的公共基础设施。

发布范围说明：Core 提供框架；首领、邮件、物品、配方等业务能力由各自插件提供。各角色资料随实际登录和游戏操作更新。

## YiboCrafting · 1.0.0

### English

- Record confirmed learned recipes from your own profession window.
- Browse recipes across characters or organize them by profession.
- Search recorded recipes and products by name or ID when available.
- Use character, category, and state filters to narrow the list.
- Inspect recipe details and recorded character learning states in YiboCore.

### 中文

- 从本人专业窗口记录已确认学会的配方。
- 按账号配方矩阵或专业分类浏览。
- 按已记录配方、产物名称或可用 ID 搜索。
- 通过角色、分类与状态筛选缩小范围。
- 在 Core 页面查看配方详情和角色已记录的学习状态。

发布范围说明：此发布版只确认已记录的已学配方；缺少记录表示待确认，不代表已经证实未学。不承诺完整配方目录或跨插件制造查询服务。

## YiboCurrency · 0.9.1

### English

- An account matrix of gold, registered currencies, archaeology fragments, and item tokens.
- Support for registered seasonal tokens.
- Add custom item tokens using inventory drag-and-drop or item input.
- Separate main-page visibility and monitored hover projects.
- Optional YiboVault integration adds recorded personal inventory locations for item-token counts.

### 中文

- 以账号矩阵查看金币、收录货币、考古碎片及物品代币。
- 支持已收录的节日代币。
- 通过背包拖放或物品输入添加自定义物品代币。
- 主页面显示与悬停监控项目分别配置。
- 可选接入 YiboVault，为物品代币统计补充已记录的个人库存来源。

发布范围说明：离线余额为快照；库存来源覆盖不完整时保留标记，不表示已经统计完整银行。YiboVault 为可选增强。

## YiboLegendary · 2.1.0

### English

- Legendary cloak chapters, quests, objectives, reputation requirements, and next steps.
- Collection routes for Thunderfury, Sulfuras, Thori'dal, and the Warglaives of Azzinoth.
- Supported checkpoints for Val'anyr, Shadowmourne, Dragonwrath, and Fangs of the Father.
- Character eligibility, observed items, and route details in an account overview.
- Compact previews through the Core-managed entry.

### 中文

- 传说披风章节、任务、目标、声望门槛与下一步提示。
- 收录风剑、萨弗拉斯、索利达尔和埃辛诺斯战刃收集路线。
- 收录瓦兰奈尔、影之哀伤、巨龙之怒和龙父之牙的适用检查点。
- 在账号视图核对角色适用条件、观测物品与路线详情。
- 通过 Core 管理的入口查看紧凑预览。

发布范围说明：披风提供详细任务线追踪，各武器路线的检查点覆盖不同；历史获得可能需要明确证据。埃提耶什等仅目录占位的条目不属于已实现获取路线。

## YiboMail · 1.2.2-api1

### English

- Mail and attachment views with search, filters, sorting, and collection queues.
- Grouped attachment items and collectable gold, with COD confirmation retained.
- An address book for saved contacts, account characters, recent recipients, friends, and guild members.
- Configurable recipient shortcut slots and item/category sending rules with exclusions.
- Account mailbox browsing, overview, history, expiry reminders, and hover summaries.

### 中文

- 邮件与附件视图提供搜索、筛选、排序和收取队列。
- 汇总附件物品和可收金币，COD 保留原生付款确认。
- 通讯录包含常用、账号角色、最近邮寄、好友与公会成员。
- 可配置快捷寄件格，以及按物品或分类匹配、带排除规则的寄件。
- 账号邮箱浏览、总览、历史、到期提醒与悬停摘要。

发布范围说明：寄件和收取需要当前角色打开邮箱。离线邮件为最近成功快照，大量邮件可能仅能扫描可见部分；到期提醒依据已记录的估算时间。

## YiboMounts · 0.8.5

### English

- Mount source information in player and target aura tooltips.
- Mouseover-unit, Mount Journal, and supported chat-link tooltips.
- Source details for bosses, dungeons, vendors, quests, achievements, and events.
- Available difficulty, price, reputation, class, and faction requirements.
- Chinese and English source information; optional Core settings.

### 中文

- 玩家及目标坐骑 Buff 提示显示来源。
- 支持鼠标指向单位、坐骑面板和适用聊天链接。
- 来源涵盖首领、副本、商人、任务、成就与活动。
- 按已有资料补充难度、价格、声望、职业与阵营条件。
- 中英双语来源信息，可选接入 Core 设置。

发布范围说明：覆盖范围取决于已收录来源资料。当前版本提供来源提示；完整收藏规划尚不在此发布范围。基础提示无需 Core。

## YiboQuestBlocker · 3.0.2

### English

- Account-wide and per-character quest blocklists.
- Add quests from the current quest list or by quest ID.
- Decline, abandon, and pause modes with a fallback abandonment queue.
- A quest-by-character management matrix and matching hover preview.
- Filters for quest type, completed quests, and character levels.

### 中文

- 账号共享与角色独立任务屏蔽列表。
- 从当前任务列表或按任务 ID 添加规则。
- 提供拒绝、放弃与暂停模式，以及兜底放弃队列。
- 任务与角色矩阵管理，并提供同数据悬停预览。
- 按任务类型、完成状态和角色等级筛选。

发布范围说明：自动接任务兼容性取决于具体插件。适配包含 !Pig、NDui QuickQuest；使用拒绝模式时关闭 Questie 或 Leatrix Plus 的自动接取。部分放弃操作仍受游戏限制。

## YiboReputation · 1.5.2

### English

- Browse the current character's reputation tree.
- Compare saved reputation observations across characters.
- Monitor up to ten selected reputations in the account matrix.
- Display friendship progress alongside supported reputation data.
- Use matching account and hover views through YiboCore.

### 中文

- 浏览当前角色声望树。
- 跨角色比较已保存的声望观测。
- 在账号矩阵监控最多十项所选声望。
- 展示适用友好度与声望数据。
- 通过 Core 账号页和同数据悬停视图查看。

发布范围说明：离线进度反映最近保存的观测。插件展示进度，不自动刷取声望。

## YiboTodo · 1.1.2

### English

- Profession cooldown groups such as Living Steel, Jard's Energy Source, Imperial Silk, and Celestial Cloth.
- Farm-operation observations and Nomi daily progress.
- Supported cooking, fishing, and jewelcrafting dailies, including selected older-expansion activities.
- Nat Pagle fish turn-ins, Blingtron 4000, and supported Darkmoon Faire activities.
- Configurable monitoring projects, compact previews, and available item or profession click actions.

### 中文

- 追踪活化钢、贾德的特制能量源、帝王丝绸、神纹布等专业冷却组。
- 记录农场操作观测与诺米日常进度。
- 支持已收录烹饪、钓鱼与珠宝日常，包含部分旧资料片项目。
- 追踪纳特三鱼交付、布林顿 4000 及已收录暗月活动。
- 可配置监控项目、紧凑预览，以及适用的物品和专业点击操作。

发布范围说明：未观测或过期状态保留待确认。冷却就绪不证明材料齐全；农场进度基于已支持的操作观测，并非完整实时作物扫描。

## YiboVault · 1.1.1-api1

### English

- Snapshots of bags, equipment, personal banks, mail attachments, and your own auction listings.
- Guild-bank browsing by guild and tab.
- Search recorded items by name or item ID.
- Recorded capacity and free-slot summaries for supported storage locations.
- Item tooltips show recorded account counts and storage locations.
- Optional YiboMail snapshots and item-token data for YiboCurrency.

### 中文

- 保存背包、装备、个人银行、邮件附件及本人拍卖上架快照。
- 按公会与页签浏览公会银行。
- 按物品名称或 ID 搜索已记录物品。
- 显示适用仓储位置已采集的容量与空位摘要。
- 物品提示展示已记录账号数量与存放位置。
- 可选使用 YiboMail 邮箱快照，并供 YiboCurrency 查询物品代币数据。

发布范围说明：展示的是库存快照，不是实时访问离线角色。未知来源保持未知，部分可见邮件保留部分扫描标记；公会库存与拍卖上架区别于个人持有。
