# 2026-11-17 第一批 Forever 改动的 Mists 补发审计

范围：2026-11-16 第一批 Builds、Crafting、Currency、Mail、Reputation、Vault。比较基线为 `aab4df3` 与实际旧 Mists ZIP，当前源码包含 `5e253ac`。旧 Mists 包分别为 Builds 1.5.3、Crafting 1.2.4、Currency 1.1.2、Mail 1.3.4-api1、Reputation 1.7.3、Vault 1.2.5-api1。当前构建规则把目标源码清单映射为玩家包默认清单；旧包不是当前目标源码的重建结果。

| 插件 | Mists 改前/旧包 | 当前 Mists 源码与包 | 结论与证据边界 |
|---|---|---|---|
| YiboBuilds | 旧 `YiboBuilds.toc` 是完整 50504 业务链；旧包 1.5.3。 | 根 TOC 现为双目标提示；`YiboBuilds_Mists.toc` 保留 Mists 清单，包内映射为默认 TOC。Forever 天赋文件不进入 Mists 包。 | **补发 1.5.4。** 清单与包内容变更要求补发。11/16旧图只证明旧加载字节行为，不证明新包来源或覆盖。 |
| YiboCrafting | 旧默认 TOC 直接加载专业业务链；旧包 1.2.4。 | 根 TOC 转提示；新 Mists 清单恢复 Mists 文件并映射为包默认 TOC。Forever 页面分目标。 | **补发 1.2.5。** 目标清单及包内容变化。旧图仅作行为基线。 |
| YiboCurrency | 旧默认 TOC 加载根 `Catalog.lua`；旧包 1.1.2。 | 目录迁至 `Mists/Catalog.lua`，新增 Common Catalog/Native 模块并修改共享采集/存储加载职责；Forever 使用独立策略。Mists TOC 明确加载目标文件。 | **补发 1.1.3。** 明确的 Mists 代码和加载链迁移。旧截图不能证明新动态目录加载。 |
| YiboMail | 旧默认 TOC 是 Mists 业务链；旧包 1.3.4-api1。 | 根 TOC 转提示并新增 Mists 清单映射。Forever Target、页面和扫描变化不进入 Mists 包。 | **补发 1.3.5-api1。** 清单/包内容变化。旧邮件图只证明旧字节。 |
| YiboReputation | 旧默认 TOC 加载 Mists 业务链；旧包 1.7.3。 | 根 TOC 转提示，新增 Mists/Forever 独立清单；Mists 当前包从 Mists TOC 构建，Forever 目录不进入包。 | **补发 1.7.4。** 默认清单和目标加载图变化。旧声望图为旧字节基线。 |
| YiboVault | 旧默认 TOC 加载 Mists 业务/查询链；旧包 1.2.5-api1。 | 根 TOC 转提示并新增 Mists 清单；Forever Target/页面/采集器独立。 | **补发 1.2.6-api1。** 即使主要业务 diff 是 Forever 专属，Mists 包的默认清单已改变。旧物品总览图不证明新加载链或覆盖。 |

六包均由统一构建器从当前目标源码生成。目标 Interface 为 50504，包内使用插件同名默认 TOC；已核对版本、依赖、静态引用并确认没有 Forever 文件。

| 目标包 | ZIP SHA256 | 包内文件数 |
|---|---|---:|
| `YiboBuilds-mists-v1.5.4-curseforge.zip` | `CE7BA996F4233236BD86CE93809255B9AF6FB6AE54A8E17EE9D13BED336B42C5` | 31 |
| `YiboCrafting-mists-v1.2.5-curseforge.zip` | `17614AD2997F6045327C23FAC7C652DCEF8BF1BCD403AFD9232CAF8B51C729F8` | 22 |
| `YiboCurrency-mists-v1.1.3-curseforge.zip` | `5EC62FAF716580C02DE26963DAC4747D0569D3DA099865474B682CAA394F5E52` | 27 |
| `YiboMail-mists-v1.3.5-api1-curseforge.zip` | `8D1E6DD769A6F47655F315FF625475208F8997FAABD8D39EC4095D9DD04EF38B` | 40 |
| `YiboReputation-mists-v1.7.4-curseforge.zip` | `1EC710A8331FA51F904AC06DF6E88EE98AA98F4D75734289AB76CEE4C0E234E0` | 28 |
| `YiboVault-mists-v1.2.6-api1-curseforge.zip` | `FADE239BDC6C7424BADAA2F3094EFBECB0329E463448BCE98D1A3FEEB2E08000` | 34 |

11/16的15张图可复用为旧 Mists 行为基线，但目标加载字节及包内容与新包不同，不能外推为新包实机通过。当前未安装、上传或覆盖客户端；新加载来源、一次初始化、旧包残留 TOC/XML、存档恢复、重载和完整退出启动均待验。旧文件覆盖兼容及新 Mists 包实机状态不宣称通过。此次只构建，不发布上传、不覆盖客户端。
