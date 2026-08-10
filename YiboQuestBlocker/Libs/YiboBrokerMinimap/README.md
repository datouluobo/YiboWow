# YiboBrokerMinimap Maintenance Rules

`YiboBrokerMinimap` is a shared source module copied between these projects:

- `YiboQuestBlocker`
- `YiboAltoBoss`

This directory contains a source-copy module, not an independently installed shared library.
Each project keeps its own local copy so that either addon can run correctly when installed alone.

## Canonical Expectations

- The module name must remain `YiboBrokerMinimap`.
- The main file path must remain `Libs\YiboBrokerMinimap\YiboBrokerMinimap.lua`.
- Public function names, callback names, option keys, and config field names must stay aligned between both projects.
- Comments, version notes, and file structure should stay as consistent as practical.

## Sync Rule

Any bug fix, behavior change, refactor, or new feature applied to this module in one project must be reviewed for the sibling copy in the other project and mirrored when applicable.

Do not allow the two copies to drift into "same name, different behavior" variants.

## Editing Discipline

When changing this module:

1. Check the sibling project's `YiboBrokerMinimap` copy.
2. Apply the same change there unless the difference is explicitly intentional and documented.
3. If a difference is intentionally project-specific, document it in code comments and in the change summary.
4. Keep the adapter/business logic outside this module whenever possible.

## Scope Boundary

`YiboBrokerMinimap` should only handle shared entry concerns such as:

- `LibDataBroker` object setup
- `LibDBIcon` registration
- fallback minimap button creation
- minimap drag positioning
- click dispatch
- hover enter/leave handling
- tooltip entry behavior
- shared initialization flow

This module should not absorb addon-specific business logic such as quest rules, boss data, lockout logic, or window content generation.

## Future Upgrade Path

If more addons start using this module, it may later be promoted into a true shared library.
Until then, treat the copies in both projects as one maintained module with two mirrored source locations.
