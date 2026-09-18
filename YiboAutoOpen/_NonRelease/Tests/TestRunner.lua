local specs = {
    "BagEligibilitySpec.lua",
    "BindConfirmAssistSpec.lua",
    "BagSpaceReadinessSpec.lua",
    "CatalogSpec.lua",
    "CommandsSpec.lua",
    "DeferredEligibilitySpec.lua",
    "ItemResolverSpec.lua",
    "MigrationSpec.lua",
    "NoContainerSafetySpec.lua",
    "QueueScanIsolationSpec.lua",
    "RetryBackoffSpec.lua",
    "QueueSpec.lua",
    "StartupLifecycleSpec.lua",
}

for _, name in ipairs(specs) do dofile("YiboAutoOpen/_NonRelease/Tests/" .. name) end
print("All YiboAutoOpen specs passed")
