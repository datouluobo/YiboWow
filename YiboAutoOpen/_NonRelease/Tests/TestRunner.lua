local specs = {
    "BagEligibilitySpec.lua",
    "BagSpaceReadinessSpec.lua",
    "CatalogSpec.lua",
    "DeferredEligibilitySpec.lua",
    "ItemResolverSpec.lua",
    "MigrationSpec.lua",
    "NoContainerSafetySpec.lua",
    "QueueScanIsolationSpec.lua",
    "QueueSpec.lua",
    "StartupLifecycleSpec.lua",
}

for _, name in ipairs(specs) do dofile("YiboAutoOpen/_NonRelease/Tests/" .. name) end
print("All YiboAutoOpen specs passed")
