# YiboBuilds 1.5.3 — 2026-10-31

- Refresh equipment hover borders when cached item quality becomes available, so the first preview does not remain gray until Builds is reopened.
- Re-scan the active equipment after entering the world to capture settled item links.

# YiboBuilds 1.5.1 — 2026-10-24

Mists only. Requires YiboCore 1.12.5 / API13 with character-cleanup:2.

- Offer socketable cut gems and exclude uncut crafting materials.
- Allow ordinary gems in any ordinary colored or prismatic socket; preserve meta and Sha-touched restrictions.
- Keep native socket indexes stable for empty and filled sockets, with added sockets after native sockets.
- List sockets in tooltip order in the gem panel; character equipment rails expand from each equipment icon toward the model.

## 中文更新说明

- 修复普通蓝色孔无法列出背包红色、橙色成品宝石，排除未切割原石；背包、可制作和目标检查使用同一规则。
- 多孔装备孔位固定，待应用面板与装备提示孔序一致，人偶左右装备从装备向中间排列。
- 本包用于 MoP Classic，安装目录和 SavedVariables 保持不变。GitHub 包为源码归档，玩家使用 mists 安装包。
- 用户已确认孔顺序正确。候选匹配修复及干净／覆盖安装、完整退出恢复与中英文语言模式仍待客户端复测；离线测试与打包检查不代替实机验收。
- 单体与整合包共用安装目录时请选择一个更新管理来源；交替或同时由更新工具管理的覆盖与卸载行为尚未验证。

---

# YiboBuilds 1.5.0 — 2026-10-16

Requires YiboCore 1.12.5 / API13 with character-cleanup:2.

- Integrate account language, shared character name formatting and cache cleanup.
- Fix one enchant scroll offering multiple scaled effects; resolve the actual item use spell.
- Preserve distinct scrolls, stack counts, learned enchants and installed-effect recognition.
- Validate Core capabilities before initialization; protect preview settings with copied reads and validated field IDs.

## 中文更新说明

需要配套升级 YiboCore 1.12.5 / API13（character-cleanup:2）。

- 接入统一账号语言、公共角色名与缓存清理；缺失所需Core能力时提示升级并停止初始化。
- 修复一张附魔卷轴出现多个不同数值候选：按实际使用法术显示对应附魔，保留不同卷轴、数量与已学附魔。
- 预览设置读取返回副本并校验写入字段ID。
- 用户已确认Core适配正常；2026-10-16确认重载后每张卷轴仅显示对应的一个附魔。

---

# YiboBuilds 1.4.2

## 1.4.2

- Reopening the page or opening current equipment details refreshes worn equipment, preventing stale snapshots from hiding bag belt buckle candidates and installed engineering effects.
- Fix UTF-8 engineering tooltip matching and support colored or spaced Synapse Springs and Goblin Glider descriptions.
- Limit event captures to affected equipment, talents or glyphs, merge overlapping requests, and suppress unchanged notifications.
- Replace the permanent model gesture label with a first-open tip. Requires YiboCore 1.9.0 or later (API v10, account-view v2).

### 中文更新说明

- 重开页面或打开当前装备详情时刷新穿戴信息，避免旧快照隐藏背包腰带扣候选及已安装工程强化。
- 修复工程提示中文匹配，兼容带颜色和空格的神经弹簧、地精滑翔器使用描述。
- 按事件仅采集受影响的装备、天赋或雕文，合并重叠请求，避免数据未变化时重复通知。
- 模型旋转与缩放说明改为首次打开提示。需要 YiboCore 1.9.0 或更新版本（API v10、account-view v2）。

---

## 1.4.1

- The account matrix now shows the latest observed equipment while a build is awaiting confirmation.
- Incomplete equipment captures are rejected to protect the last valid snapshot.

### 中文更新说明

- 构筑尚待确认时，账号矩阵会显示最新观测到的装备。
- 拒绝不完整的装备采集，保护最后一份有效快照。

---

## 1.4.0

- Active specialization equipment is automatically saved on logout, reload, and normal exit. Switching specializations saves the outgoing slot's last observed equipment; each slot retains its own snapshot.
- Equipment icons show item levels in the same bottom-right outlined purple style as the Vault, excluding shirts and tabards.
- Bag engineering scopes can be applied directly to MoP ranged weapons through secure candidate buttons. Compatible replacement enchants remain available on already enchanted gear, using the game's native replacement confirmation.
- Ordinary enchants appear nearest equipment when engineering effects also exist. Ranged weapon scopes appear nearest their weapon.
- Clicking the same equipment icon again closes its upgrade panel.

### 中文更新说明

- 小退、重载和正常退出时自动保存当前专精装备；切换专精时保存上一槽位最近观测的装备，各专精快照独立保留。
- 装备图标右下角按物品仓库样式显示淡紫色描边装等，衬衣和战袍除外。
- 背包工程瞄准镜可通过候选行安全按钮直接施加到 MoP 远程武器；已有附魔的装备仍显示兼容覆盖候选，并使用游戏原生覆盖确认。
- 同时存在普通附魔和工程时，普通附魔靠近装备、工程靠外；远程武器瞄准镜靠近武器。
- 再次点击同一装备图标可关闭提升面板。

---

## 1.3.1

The hover equipment matrix now shows each character's item level beside their name. Older equipment snapshots without a saved average can recover it from their item slots. Item level capture also supports the available MoP Classic client API.

### 中文更新说明

悬停装备矩阵现在会在角色名后显示装等。旧快照缺少总装等时，可依据已保存的装备槽位计算；装备采集也兼容客户端可用的平均装等接口。

---

## 1.3.0

YiboBuilds now lets the current character improve equipped items from the equipment view.

- Click an equipped item to open its upgrade panel in the talent and glyph area.
- See compatible gems and enhancements from the bag and verified profession sources.
- Select a gem, review its pending state, and apply it from the panel.
- Apply a compatible enchant or enhancement directly to the selected equipment slot.
- Recognize immediately usable candidates through icon cards, action labels, and hover feedback.
- Installed gems display their item icons; empty sockets retain their requirement-colored frames.

### 中文更新说明

YiboBuilds 现在可从装备区直接处理当前角色穿戴装备的提升。

- 点击装备打开提升面板，面板显示在原天赋与雕文区域。
- 查看来自背包和已确认专业来源的适用宝石与装备增强。
- 选中宝石后查看待应用状态，并在面板内完成镶嵌。
- 将适用附魔或增强直接施加到当前装备格。
- 可直接使用的候选显示图标卡片、操作标识和悬停反馈。
- 已镶宝石恢复物品图标，空孔保留按孔位要求着色的边框。

---

## 1.2.0

YiboBuilds now detects and displays equipment enhancements throughout the character equipment view.

- Shows socketed gems and empty sockets with borders that communicate each socket's requirement.
- Detects belt buckles, blacksmith-added sockets, enchants, and engineering effects.
- Includes versioned MoP enchant and engineering catalogs with equipment tooltips.
- Fixes missing or duplicate socket rows, including Sha-touched weapon sockets.
- Refines equipment and socket icon sizing and alignment.

## 中文更新说明

YiboBuilds 现在会在角色装备区识别并显示装备强化状态。

- 显示已镶嵌宝石和空孔，并以边框表达孔位要求。
- 识别腰带扣、锻造额外孔、附魔和工程强化。
- 加入 MoP 附魔与工程强化目录及装备 Tooltip。
- 修复孔位遗漏或重复显示，包括染煞武器孔。
- 优化装备与孔位图标的尺寸和对齐。

---

## 1.1.0

YiboBuilds improves the account-wide equipment matrix and build comparison experience.

- Added persistent current/backup equipment and specialization mode switching.
- Added the character equipment matrix for comparing equipment across characters and slots.
- Added equipment quality borders, item levels, low-contrast empty slots, and changed-equipment markers.
- Added configurable equipment preview fields and adaptive matrix spacing.
- Refined the four local mode buttons and equipment tooltips.

YiboBuilds adds an account-wide view of character builds for MoP Classic.

- View current or backup specialization builds.
- Review equipment, talents, glyphs, gems, and enchants.
- Open the character workbench from YiboCore.

## 中文发布说明

YiboBuilds 为 MoP Classic 提供账号范围的角色构筑查看。

- 查看角色当前或备用专精构筑。
- 通过角色装备矩阵按角色和装备部位进行对比。
- 查看装备、天赋、雕文、宝石和附魔。
- 通过 YiboCore 打开单角色构筑工作台。
