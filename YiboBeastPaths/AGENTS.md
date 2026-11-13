# 项目规则

## `_NonRelease` 目录规则

- `_NonRelease/` 是本项目的调试面板、原始素材、参考文档和开发辅助工作区。
- 不要把 `_NonRelease/` 视为无用目录，不要在日常清理中删除或移动其中内容。
- 后续如果新增路径、补充调试资源或保留中间参考资料，优先继续放在 `_NonRelease/` 下维护。
- 制作发行包时，`_NonRelease/` 不应打包进最终发布产物。
- 是否打包 `_NonRelease/` 只影响发行包内容，不影响仓库内保留该目录。

## 双端共用包发布流程

- 用户于 2026-11-13 批准 YiboBeastPaths 1.9 继续采用 1.8.3 的双端共用包例外，仅声明 Retail 与 Mists；源码及玩家包均包含默认提示 TOC、`_Mainline` 与 `_Mists` 两份目标 TOC。目标清单负责加载对应实现，默认 TOC 仅提示缺目标。不得将其他客户端列为支持范围。

- CurseForge 项目 ID 固定为 `1575919`。
- 默认使用 `http`/`https` API 连接 CurseForge，不使用 `websocket`。
- 发布前通过统一构建器选择 `Universal`；包装输出到仓库根目录 `Builds/`，zip 内必须保留一层顶级目录 `YiboBeastPaths/`：
  - `*-curseforge.zip`：排除 `_NonRelease/`，用于 CurseForge 上传。
  - `*-github.zip`：保留公开文档和截图，排除 `_NonRelease/`，用于 GitHub Release。
- 玩家包命名为 `YiboBeastPaths-universal-v<version>-curseforge.zip`；源码包遵守统一构建器命名。
- `Builds/` 是全仓库唯一的安装包输出目录；该目录只存放生成的 zip，不提交 Git。
- 上传工具及渠道元数据须单独核验；构建验证不代表可上传或可发布。
- 上传目标接口为 `https://wow.curseforge.com/api/projects/1575919/upload-file`。
