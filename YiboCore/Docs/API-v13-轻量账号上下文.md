# API13：轻量账号上下文

新增能力 `account-identity-context:1`。保持 account-view:2 与已有完整账号上下文行为；业务使用新选项前须检查此能力，Core 不兼容时提示升级并停止依赖初始化，不以本地过滤／排序替代 Core。

`Core.AccountView:BuildContext(page, { identityOnly = true })` 使用已有 Characters:GetAll({identityOnly=true})，保留隐藏角色、页面准入、等级过滤、服务器范围、角色排序／自定义顺序和预览限制，仅去除 domains 等非身份载荷。页面准入回调若依赖完整域数据，不能选择本选项。返回身份对象和上下文为当前调用的独立投影，不建立持久账号数据副本。

`GetVisibleCharacters({identityOnly=true})` 同样支持身份投影；默认调用继续完整只读共享快照。自定义排序内部只读身份，BuildContext 复用已计算的范围定义，避免间接再次加载完整角色目录。默认 GetAllCached／BuildContext 的完整数据契约保持。

输入／无数据／错误与既有 AccountView 相同，数据库未就绪时不凭空生成角色。版本为最低 Core API13 + account-identity-context:1。首个消费者是 Mail 登录提醒；其它业务保持原路径，触及适用后台查询时接入。没有新增业务数据所有权、TOC 或事件。
