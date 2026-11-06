"""Main and settings page switching, retaining previous Core performance checks."""
from pathlib import Path
import runpy

here = Path(__file__).resolve().parent
runpy.run_path(str(here / 'verify_ui.py'), init_globals={
    'VERIFICATION_OUTPUT': here / 'Switching',
    'EXTRA_TESTS': [
        '_NonRelease/CorePerformance20261029/DeferredWorkSpec.lua',
        '_NonRelease/CoreSurfaceR1/Spec.lua',
        'YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua',
        '_NonRelease/TaskGoalIntegration/ItemActionSettingsSpec.lua',
        '_NonRelease/CorePerformance20261029/SettingsIdentitySpec.lua',
        '_NonRelease/CorePerformance20261029/NormalizationSpec.lua',
        '_NonRelease/CorePerformance20261029/DropdownWorkSpec.lua',
        '_NonRelease/CorePerformance20261029/PageSwitchSpec.lua',
    ],
})
