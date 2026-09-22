# YiboAltoBoss：副本锁定与历史统计实施方案

> 状态：已确认方案
>
> 目标：在 `YiboAltoBoss` 内增加独立的“副本锁定”页面，同时记录副本与 Boss 的本地历史次数，并复用 YiboCore 的账号视图、角色目录、入口、悬停预览和统一设置工作台。

## 一、产品边界

`YiboAltoBoss` 由两个业务页面组成：

```text
YiboAltoBoss
├── Boss
│   ├── 世界 Boss
│   ├── 节日 Boss
│   ├── Warbringer
│   └── 自定义目标
└── 副本锁定
    ├── 团队副本与英雄副本锁定
    ├── 副本内 Boss 进度
    ├── 普通五人本爆本计数
    └── 副本与 Boss 历史次数
```

两个页面共用：

- YiboCore 统一窗口壳和页面生命周期；
- 角色目录、服务器范围、角色筛选与排序；
- 主窗口与悬停预览的入口生命周期；
- Core 统一设置工作台；
- 角色缓存删除与数据清理流程。

两个页面不共用矩阵字段。Boss 页面继续表达 Boss 观察与击杀；副本页面表达副本锁定、难度、Boss 进度和计时。

两个页面共用窗口壳，但不共用窗口尺寸。YiboCore 按页面与视图模式保存尺寸：Boss 的“角色为行”“角色为列”和副本页分别拥有独立宽高；切换页面时使用目标页面的尺寸，页面内容变化时仍受屏幕安全边界和统一分页规则约束。

本方案暂不定义与 `YiboTodo` 的联动接口、自动生成待办规则或跨插件任务聚合规则。

## 二、副本类型模型

副本数据必须先按规则类型分流，再进入页面和统计逻辑。

| 类型 | 副本锁定 | 普通本爆本计数 | 历史统计 |
|---|---|---|---|
| 普通五人本 | 不作为周常锁定展示 | 计入 | 新副本 ID 记一次刷本 |
| 英雄五人本 | 角色每日进度/掉落锁定 | 不计入 | 锁定与 Boss 击杀分开记录 |
| 随机英雄本 | 使用随机本自身规则 | 不计入 | 不并入手动英雄本锁定 |
| 挑战模式 | 独立实例记录 | 不计入 | 使用独立挑战记录 |
| 团队副本 | 周常锁定 | 不计入 | 副本锁定与 Boss 击杀分开记录 |

随机地下城不写入普通副本锁定矩阵。普通五人本的爆本计数也不与英雄本、随机英雄本或挑战模式共享。

## 三、数据来源与 API

副本锁定读取参考 `BGLite - 夜月扩展包` 的 `RoleOverview.lua` 实现，采用暴雪副本锁定 API：

```lua
GetNumSavedInstances()
GetSavedInstanceInfo(index)
GetSavedInstanceEncounterInfo(index, encounterIndex)
RequestRaidInfo()
GetInstanceInfo()
GetServerTime()
```

`GetSavedInstanceInfo` 需要保存以下字段：

- 副本名称；
- 锁定 ID；
- 剩余重置秒数；
- 难度 ID与难度名称；
- `locked`；
- 副本类型与最大人数；
- Boss 总数；
- 副本内 Boss 进度；
- 实例 ID。

`GetSavedInstanceEncounterInfo` 用于读取每个 Boss 的名称和击杀状态。

当前副本识别使用 `GetInstanceInfo()`。普通五人本爆本计数使用当前实例 ID，不使用进入次数或重置动作本身作为计数依据。

## 四、普通五人本爆本计数

### 4.1 规则

爆本计数的作用域为：

```text
同一 WoW 子账号 + 同一服务器
```

规则如下：

- 滚动时间窗口为 60 分钟；
- 窗口内最多记录 5 个全新的普通五人本实例 ID；
- 第 6 个全新实例 ID 触发普通五人本进入限制；
- 重置动作本身不计数；
- 角色出本、执行重置后，只有第一个角色进入并生成新实例 ID 时才计数；
- 反复进入同一个实例 ID 不计数；
- 同一子账号同一服务器下的角色共享记录；
- 跨服务器和不同 WoW 子账号使用不同记录；
- 达到上限后，所有普通五人本都会受到限制；
- 最早记录满 60 分钟后释放名额；
- 小退不会清除计数记录；客户端重载/重启后不恢复本地滚动计数，避免把未观测期间的数据伪装成完整记录。

SavedVariables 已按 WoW 子账号隔离；运行时计数再按服务器键分桶即可。计数不写入 SavedVariables：

```lua
runtimeThrottleByRealm = {
    [realmKey] = {
        entries = {
            {
                instanceKey = "instance-id:difficulty-id",
                instanceID = 12345,
                instanceName = "青龙寺",
                difficultyID = 1,
                createdAt = 1710000000,
            },
        },
    },
}
```

### 4.2 识别流程

1. 在 `PLAYER_ENTERING_WORLD`、`RAID_INSTANCE_WELCOME` 或区域切换后读取 `GetInstanceInfo()`；
2. 判断当前实例是否属于普通五人本；
3. 使用实例 ID、难度和副本类型组成稳定的 `instanceKey`；
4. 删除超过 3600 秒的旧记录；
5. 当前实例 ID 已存在时不新增记录；
6. 当前实例 ID 未存在时新增一条记录；
7. 当记录数量达到 5 时，在副本页显示限制状态；
8. 当前插件没有覆盖到完整窗口时，显示“本地记录可能不完整”。

计数记录只存在当前客户端运行期；历史刷本次数仍写入角色统计。插件重载后从零开始重新观测，不宣称能够恢复插件未运行期间已经产生的实例 ID。

### 4.3 设置

纳入 YiboCore 的 `YiboAltoBoss` 设置页业务分区：

```text
普通五人本每小时新副本 ID 上限：5
```

默认值为 `5`。60 分钟滚动窗口属于规则常量，不作为普通用户设置项。

## 五、数据模型

继续保留现有世界 Boss 数据，同时增加副本专用数据域：

```lua
YiboAltoBossDB.characters[charKey] = {
    kills = {},
    phases = {},
    lootLockouts = {},

    instanceLockouts = {},
    encounters = {},
    statistics = {
        bosses = {},
        instances = {},
    },
}
```

### 5.1 副本锁定

```lua
instanceLockouts[instanceKey] = {
    instanceID = 12345,
    name = "某副本",
    difficultyID = 3,
    difficultyName = "英雄",
    resetAt = 1710000000,
    resetSeconds = 604800,
    bossCount = 4,
    defeatedCount = 3,
    observedAt = 1710000000,
    source = "saved-instance",
}
```

### 5.2 Boss 进度

```lua
encounters[instanceKey][encounterKey] = {
    name = "某 Boss",
    killed = true,
    difficultyID = 3,
    killedAt = 1710000000,
    source = "encounter-end",
}
```

### 5.3 历史次数

```lua
statistics.bosses[bossKey] = {
    totalKills = 12,
    firstKillAt = 1710000000,
    lastKillAt = 1711000000,
}

statistics.instances[instanceKey] = {
    totalRuns = 84,
    firstRunAt = 1710000000,
    lastRunAt = 1711000000,
}
```

统计次数是本地累计数据：

- Boss 击杀：`ENCOUNTER_END` 成功事件为主要来源；
- `BOSS_KILL` 可作为兼容补充，但必须与 `ENCOUNTER_END` 去重；
- 副本刷本：按确认生成的新实例 ID 记录一次；
- 同一个实例 ID 重复进入不增加刷本次数；
- 记录需保存跨登录累计值。

## 六、页面设计

### 6.1 Boss 页面

保持现有角色行/Boss 列矩阵。

主单元格只显示：

```text
已击杀
未击杀
未确认
```

当前周状态使用文字、颜色和状态图形共同表达；历史击杀次数不挤进矩阵单元格，放入 Tooltip。

Tooltip 展示：

- 当前周击杀状态；
- 历史击杀次数；
- 首次击杀时间；
- 最近击杀时间；
- 数据来源；
- 相关副本和难度。

### 6.2 副本锁定页面

采用角色行、副本列：

```text
角色              副本 A       副本 B       副本 C
角色甲             未锁定       3/4 Boss     已完成
角色乙             1/4 Boss     未扫描       未锁定
```

主单元格只显示当前最重要状态：

- `未锁定`；
- `3/4`；
- `已完成`；
- `未扫描`；
- `数据过期`。

普通五人本爆本计数放在副本页顶栏或底栏，不占副本列：

```text
普通本：3/5 · 最早名额 42:18 后释放
```

达到上限时显示：

```text
普通本：5/5 · 当前服务器暂时无法生成新的普通副本
```

副本单元格 Tooltip 展示：

- 副本名称与难度；
- 当前锁定状态；
- Boss 明细与击杀名单；
- 重置时间；
- 历史刷本次数；
- 最近一次实例记录；
- 最后观测时间；
- 数据来源。

## 七、悬停预览

主窗口始终根据完整副本目录显示全部副本矩阵。

悬停预览使用两类副本列的并集：

```text
固定副本列 + 当前有效锁定副本列
```

规则：

- 用户固定的副本始终显示；
- 任意符合准入条件的角色存在有效锁定时，临时增加该副本列；
- 临时列只存在于当前悬停快照；
- 周常重置或锁定消失后，临时列自动消失；
- 临时列不写入固定设置；
- 无业务快照或不满足插件准入条件的角色不参与悬停内容；
- Tooltip 继续复用主页面相同的状态判断和格式化逻辑。

普通五人本爆本计数不在悬停矩阵中按角色重复展开，统一显示当前服务器共享的计数摘要，并在 Tooltip 中提供实例记录详情。

## 八、刷新事件

副本锁定模块至少处理：

```text
PLAYER_LOGIN
PLAYER_ENTERING_WORLD
RAID_INSTANCE_WELCOME
UPDATE_INSTANCE_INFO
ZONE_CHANGED_NEW_AREA
ENCOUNTER_END
BOSS_KILL
CHAT_MSG_SYSTEM
```

推荐流程：

- 登录后调用 `RequestRaidInfo()`，等待 `UPDATE_INSTANCE_INFO` 再读取锁定；
- 进入副本后读取当前实例 ID，判断是否为新的普通五人本 ID；
- 成功击杀 Boss 后延迟刷新副本锁定信息，并写入历史击杀次数；
- 收到 `INSTANCE_SAVED` 系统消息后请求副本信息；
- 周常重置后删除过期锁定，但不删除历史统计；
- 所有数据变化统一通知 `YiboCore.AccountView:NotifyPageChanged`。

## 九、设置与缓存

业务设置只放在 YiboCore 统一设置工作台的 `YiboAltoBoss` 页面：

### 业务设置

- 普通五人本每小时新副本 ID 上限；
- 副本页面默认显示的副本类型；
- 副本页固定悬停副本。

### 数据与缓存

- 当前客户端运行期的服务器普通本爆本记录；
- 副本锁定缓存；
- Boss 历史击杀统计；
- 副本历史刷本统计。

删除缓存必须放在 `数据与缓存` 分区末尾，并使用确认框。可以分别清理：

- 当前服务器爆本计数；
- 当前角色副本锁定缓存；
- 副本与 Boss 历史次数；
- 全部 YiboAltoBoss 数据。

## 十、实施阶段

### 阶段一：锁定读取

- 新增副本定义与副本类型分类；
- 实现 `SavedInstance` 扫描；
- 保存团队副本、英雄副本和 Boss 进度；
- 建立副本页最小矩阵；
- 接入登录、进入副本和 `UPDATE_INSTANCE_INFO` 刷新。

### 阶段二：历史统计

- 增加 Boss 击杀去重；
- 增加副本实例 ID 与刷本次数统计；
- 在 Boss Tooltip 显示历史击杀次数；
- 在 Tooltip 中显示完整统计详情。

### 阶段三：普通本爆本计数

- 实现服务器范围滚动记录；
- 只记录首次进入生成的新普通本实例 ID；
- 增加默认值为 5 的设置项；
- 增加顶栏/底栏计数摘要和释放倒计时；
- 处理跨角色共享、跨服务器隔离和运行期记录。

### 阶段四：悬停与设置

- 增加固定副本列配置；
- 增加有效锁定临时列；
- 完成副本页 Tooltip；
- 将缓存删除和统计清理纳入 Core 设置工作台；
- 完成页面高度、列宽和角色分页适配。

## 十一、验收标准

- Boss 页和副本锁定页是两个独立页面；
- 副本页采用角色行、副本列；
- 主窗口只显示最小状态，详细信息进入 Tooltip；
- 普通五人本只在生成新实例 ID 时计数；
- 重置动作本身不计数；
- 同一子账号同一服务器的角色共享 5 次/小时记录；
- 跨服务器和不同 WoW 子账号互相隔离；
- 英雄本、随机英雄本和挑战模式不占用普通本爆本额度；
- 副本锁定数据能正确显示 Boss 总数、已击杀数和重置时间；
- Boss 历史击杀次数可按角色和账号视图汇总；
- 副本历史刷本次数可在 Tooltip 中查看；
- 重载后爆本计数重新从零观测；历史刷本与 Boss 次数不会被清空；
- 未观测完整窗口时明确标记数据不完整；
- 悬停固定副本和临时锁定副本符合 Core 角色准入规则；
- 设置、字段、悬停列和缓存清理全部由 YiboCore 统一工作台承载。
