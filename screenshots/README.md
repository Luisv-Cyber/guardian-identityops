# `> ls screenshots/`

**Status:** `[ ]` No screenshots committed yet. Filenames below are reserved and correspond to steps actually completed and independently verified during the lab session — cross-referenced in the main `README.md` and `docs/`.

**Before adding any screenshot, redact:** passwords/temp passwords, tenant IDs, subscription IDs, personal email, public IPs, secrets/tokens, and any other sensitive auth info. See `SECURITY.md`.

| # | Filename | Step |
|---|---|---|
| 16 | `16-dc01-deployment-complete.png` | DC01 VM deployment complete |
| 17 | `17-dc01-first-login.png` | First login to DC01 |
| 18 | `18-dc01-network-before-static.png` | DC01 networking before static IP |
| 19 | `19-dc01-static-private-ip.png` | Static private IP configured at NIC layer |
| 20 | `20-dns-static-ip-warning.png` | DNS static IP warning |
| 21 | `21-adds-dns-install-complete.png` | AD DS + DNS role install complete |
| 22 | `22-new-forest-configuration.png` | New forest configuration (corp.guardianlab.internal) |
| 23 | `23-dns-delegation-warning.png` | DNS delegation warning |
| 24 | `24-domain-controller-prerequisites-passed.png` | DC promotion prerequisites passed |
| 25 | `25-domain-controller-verification.png` | `Get-ADDomain` / `Get-ADForest` verification |
| 26 | `26-gft-ou-structure.png` | GFT OU hierarchy |
| 27 | `27-first-security-group.png` | First security group created |
| 28 | `28-security-groups-created.png` | Full RBAC security group set (14 groups) |
| 29 | `29-powershell-automation-prep.png` | PowerShell automation folder structure |
| 30 | `30-environment-validation-pass.png` | `Test-LabEnvironment` — PASS |
| 31 | `31-employee-source-data.png` | Sample employee source data |
| 32 | `32-joiner-whatif-validation-pass.png` | Joiner `-WhatIf` corrected dry-run validation |
| 33 | `33-joiner-group-verification.png` | Olivia Bennett group verification |
| 34 | `34-joiner-audit-log.png` | `Joiner.log` excerpt |
| 35 | `35-mover-before-daniel-hr-access.png` | Daniel Kim before-state (HR access) |
| 36 | `36-mover-whatif-daniel.png` | Mover `-WhatIf` preview for Daniel |
| 37 | `37-mover-daniel-success.png` | Mover execution result |
| 38 | `38-mover-daniel-group-verification.png` | Daniel Kim post-move group verification |
| 39 | `39-mover-audit-log.png` | `Mover.log` excerpt |
| 40 | `40-leaver-before-marcus-access.png` | Marcus Reed before-state (contractor access) |
| 41 | `41-leaver-whatif-marcus.png` | Leaver `-WhatIf` preview for Marcus |
| 42 | `42-leaver-marcus-success.png` | Leaver execution result |
| 43 | `43-leaver-marcus-access-removed.png` | Marcus Reed post-offboarding group verification |
| 44 | `44-leaver-audit-log.png` | `Leaver.log` excerpt |
| 45 | `45-access-audit-syntax.png` | `Get-AccessAudit.ps1` invocation |
| 46 | `46-access-audit-results.png` | Access audit results (0/3 mismatches) |
| 47 | `47-identity-controls-validation.png` | `Test-IdentityControls.ps1` — 7/7 PASS |
| 48 | `48-entra-tenant-overview.png` | Microsoft Entra tenant overview |
| 49 | `49-alternative-upn-suffix-added.png` | Verified UPN suffix added to AD |
| 50 | `50-olivia-upn-updated.png` | Olivia Bennett's UPN updated |
| 51 | `51-cloud-sync-agent-downloaded.png` | Cloud Sync agent installer downloaded |
| 52 | `52-cloud-sync-agent-install.png` | Cloud Sync agent installation in progress |
| 53 | `53-cloud-sync-agent-confirmation.png` | Cloud Sync agent configuration confirmation page |
| 54 | `54-cloud-sync-agent-success.png` | Cloud Sync agent configuration confirmed |

```
[i] No screenshots exist past #54 — because no further steps
    (sync execution, Conditional Access, SSO, etc.) have been done.
    See ../docs/hybrid-identity-progress.md
```
