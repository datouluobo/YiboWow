# 项目规则

## `_NonRelease` 目录规则

- `_NonRelease/` 是本项目的调试面板、原始素材、参考文档和开发辅助工作区。
- 不要把 `_NonRelease/` 视为无用目录，不要在日常清理中删除或移动其中内容。
- 后续如果新增路径、补充调试资源或保留中间参考资料，优先继续放在 `_NonRelease/` 下维护。
- 制作发行包时，`_NonRelease/` 不应打包进最终发布产物。
- 是否打包 `_NonRelease/` 只影响发行包内容，不影响仓库内保留该目录。

## 双包发布流程

- CurseForge 项目 ID 固定为 `1575919`。
- 默认使用 `http`/`https` API 连接 CurseForge，不使用 `websocket`。
- 发布前先运行 `_NonRelease/Tools/Build-CurseForgePackages.ps1`，两个安装包都输出到仓库根目录 `Builds/`，且 zip 内必须保留一层顶级目录 `YiboBeastPaths/`：
  - `*-curseforge.zip`：排除 `_NonRelease/`，用于 CurseForge 上传。
  - `*-github.zip`：保留公开文档和截图，排除 `_NonRelease/`，用于 GitHub Release。
- 打包命名固定为：`YiboBeastPaths-v<version>-curseforge.zip` 与 `YiboBeastPaths-v<version>-github.zip`。
- `Builds/` 是全仓库唯一的安装包输出目录；该目录只存放生成的 zip，不提交 Git。
- CurseForge 上传脚本使用 `_NonRelease/Tools/Publish-CurseForge.ps1`，默认从根目录 `Builds/` 选择最新的 `*-curseforge.zip`；认证令牌从参数 `-ApiToken` 或环境变量 `CURSEFORGE_API_TOKEN` 读取。
- 上传目标接口为 `https://wow.curseforge.com/api/projects/1575919/upload-file`。
