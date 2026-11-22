@{
    # One CurseForge project, one Suite package per game target.  Suite
    # versions are independent per target; component versions are their own.
    Name = 'Yibo-Addon-Suite'
    Title = 'Yibo Addon Suite - Account QoL Addons'
    Targets = @{
        Mists = @{
            Version = '1.2.0'
            Addons = @(
                'YiboAltoBoss', 'YiboAutoOpen', 'YiboBeastPaths', 'YiboBuilds', 'YiboCore',
                'YiboCrafting', 'YiboCurrency', 'YiboLegendary', 'YiboMail', 'YiboMounts',
                'YiboQuestBlocker', 'YiboReputation', 'YiboTaskHub', 'YiboTodo', 'YiboVault'
            )
        }
        Forever = @{
            Version = '1.0.0'
            Addons = @(
                'YiboAltoBoss', 'YiboAutoOpen', 'YiboBuilds', 'YiboCore', 'YiboCrafting',
                'YiboCurrency', 'YiboMail', 'YiboReputation', 'YiboVault'
            )
        }
    }
}