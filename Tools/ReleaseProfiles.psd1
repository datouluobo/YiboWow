@{
    SchemaVersion = 1
    # Product identifiers are stable. Their presence does not declare client support.
    Targets = @{
        Retail = @{ Slug = 'retail'; Directory = 'Retail' }
        Mists = @{ Slug = 'mists'; Directory = 'Mists' }
        TBC = @{ Slug = 'tbc'; Directory = 'TBC' }
        ClassicEra = @{ Slug = 'classic-era'; Directory = 'ClassicEra' }
        Titan = @{ Slug = 'titan'; Directory = 'Titan' }
        Forever = @{ Slug = 'forever'; Directory = 'Forever' }
    }
    Addons = @{
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
            APIPattern = '^Core\.API_VERSION\s*=\s*(\d+)'
            VersionIncludesAPI = $false
            ResourceDirectories = @('Media')
            ExtraFiles = @('Libs/UPSTREAM.md', 'Libs/Ace3-LICENSE.txt', 'Libs/LDB-LICENSE.txt')
            Targets = @{
                Mists = @{
                    SourceToc = 'YiboCore.toc'
                    LoadToc = 'YiboCore.toc'
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
                    ValidationState = 'existing-mists-baseline'
                }
            }
        }
    }
}
