# YiboMounts 1.0.1 package verification

Date: 2026-10-25. Target: Mists. Client tests pending.

Passed: runtime bytes match exact commit source; one Mists TOC; adapter loaded once; all TOC references exist; SavedVariables identity unchanged.
Passed: clean extraction and 1.0.0 overlay preserving old files have identical loaded Lua files.
Old residual files: (none)

YiboMounts-mists-v1.0.1-curseforge.zip SHA256 c634a8f01cf091e18de643db98a62f80d8b49cf999a1b5b2f2bd6d7889e3366d
YiboMounts-mists-v1.0.1-src.632fa339e6de-github.zip SHA256 08129e0eea94ad98e33a65d75f7018f79400b16c0af10b8c5917c1908d5a2e58
YiboMounts-v1.0.0-curseforge.zip SHA256 55f38977054ba5fa84647ad070587fa1b7dbafceb0c94164fae14d7b9ca4c466

Pending: real client harmful/helpful auras, links/journal/unit hover, initialization counts, settings reload and full exit/restart. No channel upload performed.

Packaged Lua regression passed for both clean and 1.0.0 overlay installations. Bootstrap/client lifecycle remains pending.
Commit: 187c4e56e2c74fada26a97ce42cc665d40391497
