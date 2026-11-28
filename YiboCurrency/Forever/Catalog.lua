local Addon = _G.YiboCurrency

Addon.Catalog = {
    { id = "money", titleKey = "CURRENCY.GOLD_61F608", source = "money", preservePreviewLabel = true,
        icon = "Interface\\MoneyFrame\\UI-GoldIcon", totalAllowed = true, verified = "implemented" },
}

-- Forever 1.60.1.71139 CurrencyTypes. Balances come from the client.
Addon.NativeCatalog = {
    [515] = { titleKey = "CURRENCY.DARKMOON_PRIZE_TICKET_7C7C77", icon = 134481 },
    [1792] = { titleKey = "CURRENCY.HONOR_POINTS_112BA6" },
    [3402] = { titleKey = "FOREVER.CURRENCY_MERCHANTS_FAVOR", icon = 135725 },
    [3468] = { titleKey = "FOREVER.CURRENCY_RANK_POINTS", icon = 2022762 },
    [3469] = { titleKey = "FOREVER.CURRENCY_TARNISHED_UNDERMINE_REAL", icon = 133799 },
}
