# Core R1-01／02 离线回归

日期：2026-10-27。当前为离线测试工具，没有游戏TOC，不部署到客户端。

- `lua _NonRelease/CoreStartupR1/Spec.lua`：真实Mists／Forever清单、内存合成存档，验证启动幂等、目标、异常存档、失败保留与重试。
- `pwsh -NoProfile -File _NonRelease/CoreStartupR1/PlanSpec.ps1`：两端统一构建ValidateOnly与保留旧文件的虚拟源码引用图，不生成安装包。
- `Results.json`：固定本次运行文件摘要和检查结果；R0原基线保持不变。

实际状态与待验范围见[实施验收记录](../../YiboCore/Docs/R1-01-02-启动与存档预检实施验收.md)。所有存档样本均在内存，不读取或修改玩家WTF。离线恢复／虚拟源码覆盖不等于游戏落盘或最终安装包覆盖通过。
