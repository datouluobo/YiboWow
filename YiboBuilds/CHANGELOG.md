# Changelog

## 1.4.2 — 2026-10-08

- Refresh worn equipment when reopening the page or opening an active equipment detail, so stale observations do not hide bag belt buckle candidates or installed tinkers.
- Preserve UTF-8 text when normalizing engineering tooltips; recognize colored and spaced Synapse Springs / Goblin Glider use descriptions, with explicit spell IDs taking priority.
- 重新打开页面或打开当前装备详情时重采穿戴装备，避免旧观测导致背包腰带扣候选缺失或已安装工程强化显示过时。
- 修复工程提示文本规整破坏中文字节的问题，兼容带颜色与空格的神经弹簧、地精滑翔器使用描述，并优先使用明确法术 ID。
- Collect only the equipment, talents or glyphs affected by an event; combine burst scopes and suppress unchanged snapshot notifications.
- Preserve the delayed equipment confirmation when glyph or talent events overlap.
- Replace the permanent model gesture label with a one-time first-open tip; require YiboCore API v10.


## 1.4.1

- Show the latest observed equipment in the account matrix when a build has not yet been confirmed.
- Reject obviously incomplete equipment captures so they cannot replace a valid saved snapshot.
- 在账号矩阵中显示尚未确认的最新装备观测，避免角色看起来全身空栏。
- 拒绝明显不完整的装备采集，防止覆盖有效快照。

## 1.4.0

- Automatically save active specialization equipment on logout, reload, and normal exit; preserve the outgoing specialization's last observed equipment when switching.
- Show item levels on equipment icons using the Vault font, outline, color, and bottom-right placement; exclude shirts and tabards.
- Support bag engineering scopes on MoP ranged weapons and apply bag enhancements through secure candidate buttons.
- Restore compatible replacement enchant candidates on already enchanted equipment and retain the native replacement confirmation.
- Place ordinary enchants nearest equipment and engineering effects farther out when both exist; place ranged weapon scopes nearest equipment.
- Fix clicking the same equipped item again to close its upgrade panel.

### 中文更新日志

- 小退、重载和正常退出时自动保存当前专精装备；切换专精时保存上一专精最近观测的装备。
- 装备图标装等统一采用物品仓库的字体、描边、淡紫色和右下角位置，衬衣与战袍除外。
- 支持 MoP 远程武器的背包工程瞄准镜，并通过候选行安全按钮直接施加背包装备增强。
- 恢复已有附魔装备的兼容覆盖候选，覆盖施加保留游戏原生确认。
- 普通附魔与工程同时存在时，普通附魔靠近装备、工程靠外；远程武器瞄准镜靠近装备。
- 修复再次点击同一装备无法关闭提升面板的问题。

## 1.3.1

- Show each character's item level beside their name in the hover equipment matrix.
- Recover the average item level from saved equipment slots when older snapshots lack an aggregate value.
- Read the equipped average item level through the available MoP Classic client API.

### 中文更新日志

- 在悬停装备矩阵的角色名后显示装等。
- 旧装备快照缺少总装等时，依据已保存的装备槽位计算。
- 兼容客户端可用的平均装等接口。

## 1.3.0

- Added a per-item equipment upgrade panel in place of the talent and glyph area.
- Added live bag gem, enchant, engineering, and profession candidates with target checks.
- Added direct gem application and equipment-targeted enhancement actions from the panel.
- Added actionable candidate cards with icons, hover feedback, and pending-gem state.
- Restored installed gem icons and refined empty socket presentation.

### 中文更新日志

- 增加单件装备提升面板，打开时替换天赋与雕文内容区。
- 按实际装备目标列出背包宝石、附魔、工程和专业候选。
- 在面板内应用宝石，并将附魔与装备增强直接指定到当前装备格。
- 为可直接使用的候选增加图标卡片、悬停反馈及宝石待应用状态。
- 恢复已镶宝石图标，调整空孔显示。

## 1.2.0

- Added equipment enhancement detection for gems, belt buckles, blacksmith sockets, enchants, and engineering effects.
- Added versioned MoP enchant and engineering catalogs with equipment tooltips.
- Fixed missing and duplicated socket rows, including blacksmith-added sockets and Sha-touched weapon sockets.
- Refined equipment and socket icon sizing, alignment, and socket requirement borders.

### 中文更新日志

- 增加宝石、腰带扣、锻造孔、附魔和工程强化的装备识别与状态显示。
- 增加 MoP 附魔和工程强化目录及装备 Tooltip。
- 修复孔位遗漏与重复显示，包括锻造额外孔和染煞武器孔。
- 调整装备与孔位图标的尺寸、对齐和孔位要求边框。

## 1.1.0

- Added persistent current/backup equipment and specialization mode switching.
- Added the character equipment matrix for comparing equipment across characters and slots.
- Added equipment quality borders, item levels, low-contrast empty slots, and changed-equipment markers.
- Added configurable equipment preview fields and adaptive matrix spacing.
- Refined the four local mode buttons and equipment tooltips.

### 中文更新日志

- 增加当前/备用装备与当前/备用专精的持久化切换。
- 增加角色装备矩阵，支持按角色和装备部位进行对比。
- 增加装备品质边框、装等、低对比度空槽和装备变更角标。
- 增加装备悬停字段配置与自适应矩阵间距。
- 优化四个模式按钮和装备 Tooltip。

## 1.0.0

- Initial MoP Classic release.
- Added account build overview, hover preview, character workbench, equipment snapshots, talents, and glyphs.
- Added automatic observation after equipment changes and saved/change status for the build-equipment action.

## 历史版本

### 1.0.0

- MoP Classic 首个版本。
- 提供账号构筑总览、悬停预览、单角色工作台、装备快照、天赋与雕文展示。
- 装备变更后自动采集观测快照，并显示构筑装备的保存与变更状态。
