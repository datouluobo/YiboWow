from pathlib import Path
import runpy

here = Path(__file__).resolve().parent
root = here.parents[1]
runpy.run_path(str(root/'_NonRelease/PerformanceAudit20261028/audit.py'), init_globals={
    'AUDIT_OUTPUT': here,
    'ADDITIONAL_TESTS': [
        '_NonRelease/PerformanceAudit20261029/HistoryRetentionSpec.lua',
        '_NonRelease/PerformanceAudit20261029/MailDeadlinesSpec.lua',
        '_NonRelease/PerformanceAudit20261029/MailCacheStampsSpec.lua',
        '_NonRelease/PerformanceAudit20261029/RouteRotationSpec.lua',
        'YiboMail/_NonRelease/Tests/RuleSendSpec.lua',
        'YiboMail/_NonRelease/Tests/RuleSendUISpec.lua',
        '_NonRelease/MailForever/Smoke.lua',
        '_NonRelease/VaultForever/Smoke.lua',
    ],
})
