# YiboMountsProbe

Mists Classic-only, non-release probe for native Mount Journal, tooltip-unit, aura, map, quest, achievement, instance, encounter, and faction APIs. It does not load `YiboMounts` or read its catalog/settings. Catalog coverage comparison was removed. Native samples are written only to `YiboMountsProbeDB`.

Commands: `/ymp inventory`, `/ymp sources`, `/ymp tooltip`, `/ymp status`. Sampling is manual. `sources` resolves IDs in the probe's frozen source-facts input with client APIs; it does not consult the business addon's runtime catalog. Because the configured MoP client was running during migration, the new probe Junction has not yet been installed. Install it only after the client exits.
