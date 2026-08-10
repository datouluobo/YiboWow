# Route Fusion Debug Workspace

This folder is the landing area for `1.4` route-fusion review artifacts copied from the in-game debug panel.

## Subfolders

- `Exports/`
  - Store per-pet Lua snippets copied from:
    - `脚印片段`
    - `融合片段`
    - `参数当前`
- `Snapshots/`
  - Store map-wide snapshots copied from:
    - `本图改动`
    - `参数本图`
- `Notes/`
  - Store manual validation notes, issue lists, and rollback decisions during pet-by-pet review.

## Source of Truth

- `ReferenceRoutes.lua` remains the formal reference-work layer.
- `FootprintAnchors.lua` remains the formal footprint layer.
- `ResolvedRoutes.lua` remains the computed output layer.
- Files in this folder are review artifacts only and must not be treated as the only source of truth.
