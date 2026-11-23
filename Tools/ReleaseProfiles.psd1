@{
    SchemaVersion = 1
    # A configured target preserves an existing package baseline; it is not client acceptance.
    Targets = @{
        Retail = @{ Slug = 'retail'; Directory = 'Retail' }
        Mists = @{ Slug = 'mists'; Directory = 'Mists' }
        TBC = @{ Slug = 'tbc'; Directory = 'TBC' }
        ClassicEra = @{ Slug = 'classic-era'; Directory = 'ClassicEra' }
        Titan = @{ Slug = 'titan'; Directory = 'Titan' }
        Forever = @{ Slug = 'forever'; Directory = 'Forever' }
    }
    LegacyBundles = @{
        YiboBeastPaths = @{
            Slug = 'universal'
            SupportedTargets = @('Retail', 'Mists')
            SourceTocs = @('YiboBeastPaths.toc', 'YiboBeastPaths_Mainline.toc', 'YiboBeastPaths_Mists.toc')
            TocTargets = @('Retail', 'Retail', 'Mists')
            Interfaces = @(120105, 120105, 50504)
            HintToc = 'YiboBeastPaths.toc'
            HintInterfaces = @(120105, 50504)
            # Every Core gate in the shared bundle must declare the same minimum Core API.
            RequiredCoreChecks = @(
                @{ File = 'Common/OfflinePetCoreGate.lua'; Pattern = 'core:CheckAPIVersion\((\d+)\)' }
                @{ File = 'Maintenance/CoreDebugAdapter.lua'; Pattern = 'core:CheckAPIVersion\((\d+)\)' }
            )
            ValidationState = '1.9.1-retail-mists-bundle-user-accepted-20261115'
        }
    }
    Addons = @{
        YiboAltoBoss = @{
            VersionFile = 'Mists/Target.lua'
            VersionPattern = '^YAB\.Version\s*=\s*"([^"]+)"'
            RequiredCoreFile = 'Mists/CoreRequirements.lua'
            RequiredCorePattern = 'Core:CheckAPIVersion\((\d+)\)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboAltoBoss_Mists.toc'
                    LoadToc = 'YiboAltoBoss.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'mists-2.8.7-multi-target-client-pending'
                }
                Forever = @{
                    SourceToc = 'YiboAltoBoss_Forever.toc'
                    LoadToc = 'YiboAltoBoss.toc'
                    VersionFile = 'Forever/Target.lua'
                    RequiredCoreFile = 'Forever/Target.lua'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.1.0-manual-targets-instance-framework-client-pending'
                }
            }
        }
        YiboAutoOpen = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Addon\.NAME, Addon\.VERSION\s*=\s*"YiboAutoOpen",\s*"([^"]+)"'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboAutoOpen_Mists.toc'
                    LoadToc = 'YiboAutoOpen.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboAutoOpen_Forever.toc'
                    LoadToc = 'YiboAutoOpen.toc'
                    VersionFile = 'Forever/Target.lua'
                    RequiredCoreFile = 'Forever/Target.lua'
                    RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
                    VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'offline-client-pending'
                }
            }
        }
        YiboBuilds = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboBuilds_Mists.toc'
                    LoadToc = 'YiboBuilds.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboBuilds_Forever.toc'
                    LoadToc = 'YiboBuilds.toc'
                    VersionFile = 'Forever/Namespace.lua'
                    VersionPattern = '^local Addon = \{ NAME = "YiboBuilds", VERSION = "([^"]+)"'
                    RequiredCoreFile = 'Forever/Bootstrap.lua'
                    RequiredCorePattern = 'core:CheckAPIVersion\((\d+)\)'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.1.20-realm-scope-client-pending-20261111'
                }
            }
        }
        YiboCore = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Core\.VERSION\s*=\s*"([^"]+)"'
            APIFile = 'Bootstrap.lua'
            APIPattern = '^Core\.API_VERSION\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @('Libs/UPSTREAM.md', 'Libs/Ace3-LICENSE.txt', 'Libs/LDB-LICENSE.txt')
            Targets = @{
                Retail = @{
                    SourceToc = 'YiboCore_Mainline.toc'
                    LoadToc = 'YiboCore.toc'
                    VersionFile = 'Retail/Target.lua'
                    Interfaces = @(120105)
                    CurseForgeFlavor = 'retail'
                    CurseForgeVersionNames = @('12.1.5')
                    LuaVersion = '5.1'
                    ValidationState = 'retail-r4-installation-recovery-verified-ybp183-settings-observed'
                }
                Mists = @{
                    SourceToc = 'YiboCore_Mists.toc'
                    LoadToc = 'YiboCore.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboCore_Forever.toc'
                    LoadToc = 'YiboCore.toc'
                    VersionFile = 'Forever/Target.lua'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.2.4-item-level-and-sub-gold-formatting'
                }
            }
        }
        YiboCrafting = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            RequiredCoreFile = 'Bootstrap.lua'
            RequiredCorePattern = 'Core:CheckAPIVersion\((\d+)\)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboCrafting_Mists.toc'
                    LoadToc = 'YiboCrafting.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboCrafting_Forever.toc'
                    LoadToc = 'YiboCrafting.toc'
                    Interfaces = @(16001)
                    VersionFile = 'Forever/Namespace.lua'
                    VersionPattern = '^local Addon=.*VERSION="([^"]+)"'
                    RequiredCoreFile = 'Forever/Bootstrap.lua'
                    RequiredCorePattern = 'core:CheckAPIVersion\((\d+)\)'
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.1.5-realm-scope-client-pending-20261111'
                }
            }
        }
        YiboCurrency = @{
            VersionFile = 'Mists/Bootstrap.lua'
            VersionPattern = '^Addon\.NAME, Addon\.VERSION\s*=\s*"YiboCurrency",\s*"([^"]+)"'
            RequiredCoreFile = 'CoreIntegration.lua'
            RequiredCorePattern = 'Core:CheckAPIVersion\((\d+)\)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboCurrency_Mists.toc'
                    LoadToc = 'YiboCurrency.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboCurrency_Forever.toc'
                    LoadToc = 'YiboCurrency.toc'
                    VersionFile = 'Forever/Namespace.lua'
                    VersionPattern = '^local Addon = \{ NAME = "YiboCurrency", VERSION = "([^"]+)"'
                    RequiredCoreFile = 'Forever/Bootstrap.lua'
                    RequiredCorePattern = 'core:CheckAPIVersion\((\d+)\)'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.1.9-realm-scope-client-pending-20261111'
                }
            }
        }
        YiboLegendary = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboLegendary.toc'
                    LoadToc = 'YiboLegendary.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboMail = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.NAME, Addon\.VERSION, Addon\.API_VERSION\s*=\s*"YiboMail",\s*"([^"]+)"'
            APIPattern = '^Addon\.NAME, Addon\.VERSION, Addon\.API_VERSION\s*=\s*"YiboMail",\s*"[^"]+",\s*(\d+)'
            APIFile = 'Namespace.lua'
            SourceVersionIncludesAPI = $true
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $true
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboMail_Mists.toc'
                    LoadToc = 'YiboMail.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'mists-1.5.0-api1-mail-transit-client-pending-20261124'
                }
                Forever = @{
                    SourceToc = 'YiboMail_Forever.toc'
                    LoadToc = 'YiboMail.toc'
                    Interfaces = @(16001)
                    VersionFile = 'Forever/Target.lua'
                    VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
                    RequiredCoreFile = 'Namespace.lua'
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.4.0-api1-mail-transit-client-pending-20261124'
                }
            }
        }
        YiboMounts = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^NS\.VERSION\s*=\s*"([^"]+)"'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboMounts.toc'
                    LoadToc = 'YiboMounts.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboQuestBlocker = @{
            VersionFile = 'YiboQuestBlocker.toc'
            VersionPattern = '^## Version:\s*([^\r\n]+)'
            RequiredCoreFile = 'CoreIntegration.lua'
            RequiredCorePattern = 'Core:CheckAPIVersion\((\d+)\)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboQuestBlocker.toc'
                    LoadToc = 'YiboQuestBlocker.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboReputation = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Addon\.NAME, Addon\.VERSION\s*=\s*"YiboReputation",\s*"([^"]+)"'
            RequiredCoreFile = 'CoreIntegration.lua'
            RequiredCorePattern = '^local REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboReputation_Mists.toc'
                    LoadToc = 'YiboReputation.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
                Forever = @{
                    SourceToc = 'YiboReputation_Forever.toc'
                    LoadToc = 'YiboReputation.toc'
                    VersionFile = 'Forever/Namespace.lua'
                    VersionPattern = '^local Addon = \{ NAME = "YiboReputation", VERSION = "([^"]+)"'
                    RequiredCoreFile = 'Forever/Bootstrap.lua'
                    RequiredCorePattern = 'core:CheckAPIVersion\((\d+)\)'
                    Interfaces = @(16001)
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.1.9-realm-scope-client-pending-20261111'
                }
            }
        }
        YiboTaskHub = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboTaskHub.toc'
                    LoadToc = 'YiboTaskHub.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboTodo = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboTodo.toc'
                    LoadToc = 'YiboTodo.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboVault = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.RELEASE_VERSION\s*=\s*"([^"]+)"'
            APIPattern = '^Addon\.API_VERSION\s*=\s*(\d+)'
            APIFile = 'Namespace.lua'
            RequiredCoreFile = 'Namespace.lua'
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $true
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboVault_Mists.toc'
                    LoadToc = 'YiboVault.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'mists-1.2.4-manual-install-client-accepted'
                }
                Forever = @{
                    SourceToc = 'YiboVault_Forever.toc'
                    LoadToc = 'YiboVault.toc'
                    Interfaces = @(16001)
                    VersionFile = 'Forever/Target.lua'
                    CurseForgeFlavor = 'forever'
                    CurseForgeVersionNames = @('1.60.1')
                    LuaVersion = '5.1'
                    ValidationState = 'forever-0.6.6-api1-mists-parity-client-pending-20261120'
                }
            }
        }
    }
}
