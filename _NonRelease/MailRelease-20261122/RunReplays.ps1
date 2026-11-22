# Run all package-root replays for the Mail/Vault API14 release check. Writes a transcript next to this script.
$ErrorActionPreference = 'Continue'
Set-Location 'D:\Development\YiboWow'
$lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe'
$M = '_NonRelease/MailRelease-20261122'; $V = '_NonRelease/VaultRelease-20261122'
$core = "YiboCore:Forever=$M/Core-Forever/YiboCore YiboCore:Mists=$M/Core-Mists/YiboCore"
$cases = @(
  @('Mail Smoke clean',            "$M/RunOnPackages.lua _NonRelease/MailForever/Smoke.lua $core YiboMail:Forever=$M/Clean-Forever/YiboMail YiboMail:Mists=$M/Clean-Mists/YiboMail YiboVault:Forever=$V/Clean-Forever/YiboVault"),
  @('Mail Smoke overlay',          "$M/RunOnPackages.lua _NonRelease/MailForever/Smoke.lua $core YiboMail:Forever=$M/Overlay-Forever/YiboMail YiboMail:Mists=$M/Overlay-Mists/YiboMail YiboVault:Forever=$V/Overlay-Forever/YiboVault"),
  @('Mail Smoke overlay(old start)', "$M/RunOnPackages.lua _NonRelease/MailForever/Smoke.lua $core YiboMail:Forever=$M/Overlay-Forever-from-0.1.5/YiboMail YiboMail:Mists=$M/Overlay-Mists-from-1.3.4/YiboMail YiboVault:Forever=$V/Overlay-Forever-from-0.6.4/YiboVault"),
  @('Vault Smoke clean',           "$M/RunOnPackages.lua _NonRelease/VaultForever/Smoke.lua $core YiboVault:Forever=$V/Clean-Forever/YiboVault YiboVault:Mists=$V/Clean-Mists/YiboVault"),
  @('Vault Smoke overlay',         "$M/RunOnPackages.lua _NonRelease/VaultForever/Smoke.lua $core YiboVault:Forever=$V/Overlay-Forever/YiboVault YiboVault:Mists=$V/Overlay-Mists/YiboVault"),
  @('Vault Smoke overlay(0.6.4)',  "$M/RunOnPackages.lua _NonRelease/VaultForever/Smoke.lua $core YiboVault:Forever=$V/Overlay-Forever-from-0.6.4/YiboVault YiboVault:Mists=$V/Overlay-Mists/YiboVault"),
  # PackageAcceptance: clean + old-package save/overlay/reload; Core redirected to published package
  @('Mail Acceptance Mists clean',   "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Clean-Mists/YiboMail Mists - $V/Clean-Mists/YiboVault"),
  @('Mail Acceptance Forever clean', "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Clean-Forever/YiboMail Forever - $V/Clean-Forever/YiboVault"),
  @('Mail Acceptance Mists 1.3.5->1.4.0 overlay', "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Overlay-Mists/YiboMail Mists $M/Baseline-Mists/YiboMail $V/Overlay-Mists/YiboVault"),
  @('Mail Acceptance Mists 1.3.4->1.4.0 overlay', "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Overlay-Mists-from-1.3.4/YiboMail Mists $M/Baseline-Mists-from-1.3.4/YiboMail $V/Overlay-Mists/YiboVault"),
  @('Mail Acceptance Forever 0.2.0->0.3.0 overlay', "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Overlay-Forever/YiboMail Forever $M/Baseline-Forever/YiboMail $V/Overlay-Forever/YiboVault"),
  @('Mail Acceptance Forever 0.1.5->0.3.0 overlay', "$M/RunOnPackages.lua _NonRelease/MailForever/PackageAcceptance.lua $core -- $M/Overlay-Forever-from-0.1.5/YiboMail Forever $M/Baseline-Forever-from-0.1.5/YiboMail $V/Overlay-Forever/YiboVault"),
  @('Mail ReleaseChecks', "$M/ReleaseChecks.lua"),
  @('Vault ReleaseChecks', "$V/ReleaseChecks.lua")
)
$transcript = @(); $pass = 0; $fail = 0
foreach ($c in $cases) {
  $out = cmd /c "`"$lua`" $($c[1]) 2>&1"
  $code = $LASTEXITCODE
  if ($code -eq 0) { $pass++ } else { $fail++ }
  $transcript += "### $($c[0]) => exit $code"; $transcript += $out
}
$transcript += "== replay cases pass=$pass fail=$fail"
$transcript | Set-Content "$M/Replay-Transcript.txt" -Encoding UTF8
$transcript | Where-Object { $_ -match '^###|PASS|passed|FAIL|Error|error|==|checks' }
