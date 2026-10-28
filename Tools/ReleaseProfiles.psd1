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
            ValidationState = 'existing-maintenance-multi-toc-baseline'
        }
    }
    Addons = @{
        YiboAltoBoss = @{
            VersionFile = 'YiboAltoBoss.toc'
            VersionPattern = '^## Version:\s*([^\r\n]+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboAltoBoss.toc'
                    LoadToc = 'YiboAltoBoss.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
                    SourceToc = 'YiboAutoOpen.toc'
                    LoadToc = 'YiboAutoOpen.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
                    SourceToc = 'YiboBuilds.toc'
                    LoadToc = 'YiboBuilds.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
                    ValidationState = 'development-entry-verified-not-release-ready'
                }
            }
        }
        YiboCrafting = @{
            VersionFile = 'Namespace.lua'
            VersionPattern = '^Addon\.VERSION\s*=\s*"([^"]+)"'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboCrafting.toc'
                    LoadToc = 'YiboCrafting.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
        YiboCurrency = @{
            VersionFile = 'Bootstrap.lua'
            VersionPattern = '^Addon\.NAME, Addon\.VERSION\s*=\s*"YiboCurrency",\s*"([^"]+)"'
            RequiredCoreFile = 'CoreIntegration.lua'
            RequiredCorePattern = 'Core:CheckAPIVersion\((\d+)\)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboCurrency.toc'
                    LoadToc = 'YiboCurrency.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
            SourceVersionIncludesAPI = $true
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $true
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboMail.toc'
                    LoadToc = 'YiboMail.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
                    SourceToc = 'YiboReputation.toc'
                    LoadToc = 'YiboReputation.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'existing-mists-baseline'
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
            RequiredCorePattern = '^Addon\.REQUIRED_CORE_API\s*=\s*(\d+)'
            VersionIncludesAPI = $true
            ResourceDirectories = @('Media')
            ExtraFiles = @()
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboVault.toc'
                    LoadToc = 'YiboVault.toc'
                    Interfaces = @(50504)
                    CurseForgeFlavor = 'mists'
                    CurseForgeVersionNames = @('5.5.4')
                    LuaVersion = '5.1'
                    ValidationState = 'mists-1.2.4-manual-install-client-accepted'
                }
            }
        }
    }
}
