# YiboTodoProbe

Mists Classic-only, non-release sampler for native quest-log, map, and event behavior. It does not load `YiboTodo` or inspect its databases, catalog, actions, or providers. Captures are written only to `YiboTodoProbeDB`; event records contain event names only, not event arguments or character identity.

Commands: `/ytp report`, `/ytp start`, `/ytp snapshot`, `/ytp finish`. Sampling is manual. The old `/ytd probe ...`, `nomi-debug`, `action-debug`, and model validation commands were removed from the business addon; those paths depended on private business state and are outside this probe's scope.
