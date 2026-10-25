local Addon = _G.YiboVault
Addon.RELEASE_VERSION = "0.6.0"
Addon.VERSION = Addon.RELEASE_VERSION .. "-api" .. Addon.API_VERSION
Addon.Target = { id = "Forever", currentOnly = true, guildBankSlots = 98, savedVariable = "YiboVaultForeverDB" }
Addon.CLIENT_SUPPORTED = type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
Addon.CAPABILITIES = { ["items.query"] = 1, ["items.state"] = 1, ["items.events"] = 1,
    ["source.bags"] = 1, ["source.equipment"] = 1, ["source.bank"] = 1, ["source.mail"] = 1, ["source.auction"] = 1, ["source.guild-bank"] = 1 }
Addon.SourceClasses = { bags = "physical", equipment = "physical", bank = "physical", mail = "external", auction = "listed", ["guild-bank"] = "physical" }
