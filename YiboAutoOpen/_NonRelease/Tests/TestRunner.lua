local specs = {
    "BagEligibilitySpec.lua",
    "BindConfirmAssistSpec.lua",
    "BagSpaceReadinessSpec.lua",
    "CatalogSpec.lua",
    "ContainerOutcomeSpec.lua",
    "CommandsSpec.lua",
    "DeferredEligibilitySpec.lua",
    "ItemResolverSpec.lua",
    "MigrationSpec.lua",
    "NoContainerSafetySpec.lua",
    "QueueScanIsolationSpec.lua",
    "QueueFairnessSpec.lua",
    "RetryBackoffSpec.lua",
    "QueueSpec.lua",
    "StartupLifecycleSpec.lua",
    "SensitiveReconcileSpec.lua",
}

for _, name in ipairs(specs) do dofile("YiboAutoOpen/_NonRelease/Tests/" .. name) end
print("All YiboAutoOpen specs passed")
