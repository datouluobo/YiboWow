# Core 无限服离线验证

运行 `lua _NonRelease/CoreForever/Smoke.lua`。测试直接加载 `YiboCore_Mists.toc` 与 `YiboCore_Forever.toc` 的真实源文件，分别模拟 Mists 与 Forever，不依赖业务插件；默认 `YiboCore.toc` 仅为缺目标时的提示入口。

`FrameFixture.lua` 的共用帧模型来自仓库既有 WorkspaceSpec 夹具，本目录补充生命周期和窗口行为；没有按任意方法名自动返回空函数。覆盖范围与已知测试基线阻断见[最小适配与验收](../../YiboCore/Docs/Forever-最小适配与验收.md)。模拟不能证明游戏内 UI、原生加载清单选择和原生 SavedVariables 恢复。

`BaselineRunner.lua` 是本轮自动生成的诊断中间文件，内嵌本轮七个修改文件的原始 HEAD 版本，仅在测试运行期间通过内存 dofile 路由作对照，不写回源码。使用：

```powershell
lua _NonRelease/CoreForever/BaselineRunner.lua YiboCore/_NonRelease/Tests/RuntimePerformanceSpec.lua
lua _NonRelease/CoreForever/BaselineRunner.lua _NonRelease/Localization/LocaleSpec.lua
```

该对照固定于本轮审查时的源码基线；后续修改不能把它当作仓库最新 HEAD 或完整历史工作树。
