from pathlib import Path
import runpy

here = Path(__file__).resolve().parent
root = here.parents[1]
runpy.run_path(str(root/'_NonRelease/PerformanceAudit20261028/audit.py'), init_globals={
    'AUDIT_OUTPUT': here,
    'ADDITIONAL_TESTS': [
        '_NonRelease/MailPerformance20261029/TenLetterChainSpec.lua',
        '_NonRelease/MailPerformance20261029/ItemEventBurstSpec.lua',
        '_NonRelease/MailPerformance20261029/TransitEvidenceCacheSpec.lua',
        '_NonRelease/MailPerformance20261029/CollectionRuleRematchSpec.lua',
        '_NonRelease/MailPerformance20261029/OpenPeakSpec.lua',
        '_NonRelease/MailPerformance20261029/SearchAllocationSpec.lua',
        '_NonRelease/MailPerformance20261029/IdentityCacheSpec.lua',
        '_NonRelease/MailPerformance20261029/NotificationSignalSpec.lua',
        '_NonRelease/MailPerformance20261029/SummaryReuseSpec.lua',
        '_NonRelease/MailPerformance20261029/TransferDirectoryReuseSpec.lua',
        '_NonRelease/MailPerformance20261029/StartupArraySharingSpec.lua',
        '_NonRelease/MailPerformance20261029/NotificationPipelineSpec.lua',
        '_NonRelease/MailPerformance20261029/NativeNotificationSpec.lua',

        '_NonRelease/MailPerformance20261029/CollectionR2Spec.lua',
        '_NonRelease/MailPerformance20261029/ScanHintSpec.lua',
        '_NonRelease/MailPerformance20261029/CollectionStoreEquivalenceSpec.lua',
        '_NonRelease/MailPerformance20261029/TransientAllocationSpec.lua',
        '_NonRelease/MailPerformance20261029/TransitCopiesSpec.lua',
        '_NonRelease/MailPerformance20261029/IdentityContextSpec.lua',
        '_NonRelease/MailPerformance20261029/StartupConsumersSpec.lua',
        '_NonRelease/MailPerformance20261029/StartupMemorySpec.lua',
        '_NonRelease/MailPerformance20261029/SessionLifetimeSpec.lua',
        '_NonRelease/MailPerformance20261029/UIReferenceLifetimeSpec.lua',
        'YiboMail/_NonRelease/Tests/CollectionQueueSpec.lua',
        '_NonRelease/PerformanceAudit20261029/MailCollectionMemorySpec.lua',
        'YiboMail/_NonRelease/Tests/ReturnQueueSpec.lua',
        'YiboMail/_NonRelease/Tests/ReturnUISpec.lua',
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
