# `> ls screenshots/`

**Status:** 24 of 39 reserved screenshots are committed below. Five more were captured but are held back because they exposed a password, tenant ID, subscription ID, or public IP — those are marked "Pending redaction." The rest have not been captured/named yet. All committed screenshots correspond to steps actually completed and independently verified during the lab session — cross-referenced in the main `README.md` and `docs/`.

**Before adding any screenshot, redact:** passwords/temp passwords, tenant IDs, subscription IDs, personal email, public IPs, secrets/tokens, and any other sensitive auth info. See `SECURITY.md`.

| # | Filename | Step | Status |
|---|---|---|---|
| 16 | `16-dc01-deployment-complete.png` | DC01 VM deployment complete | Not captured |
| 17 | `17-dc01-first-login.png` | First login to DC01 | Not captured |
| 18 | `18-dc01-network-before-static.png` | DC01 networking before static IP | Not captured |
| 19 | `19-dc01-static-private-ip.png` | Static private IP configured at NIC layer | Pending redaction (public IP visible) |
| 20 | `20-dns-static-ip-warning.png` | DNS static IP warning | Not captured |
| 21 | `21-adds-dns-install-complete.png` | AD DS + DNS role install complete | Not captured |
| 22 | `22-new-forest-configuration.png` | New forest configuration (corp.guardianlab.internal) | Not captured |
| 23 | `23-dns-delegation-warning.png` | DNS delegation warning | Not captured |
| 24 | [`24-domain-controller-prerequisites-passed.png`](24-domain-controller-prerequisites-passed.png) | DC promotion prerequisites passed | ✅ Committed |
| 25 | `25-domain-controller-verification.png` | `Get-ADDomain` / `Get-ADForest` verification | Not captured |
| 26 | `26-gft-ou-structure.png` | GFT OU hierarchy | Not captured |
| 27 | `27-first-security-group.png` | First security group created | Not captured |
| 28 | [`28-security-groups-created.png`](28-security-groups-created.png) | Full RBAC security group set (14 groups) | ✅ Committed |
| 29 | `29-powershell-automation-prep.png` | PowerShell automation folder structure | Not captured |
| 30 | [`30-environment-validation-pass.png`](30-environment-validation-pass.png) | `Test-LabEnvironment` — PASS | ✅ Committed |
| 31 | [`31-employee-source-data.png`](31-employee-source-data.png) | Sample employee source data | ✅ Committed |
| 32 | [`32-joiner-whatif-validation-pass.png`](32-joiner-whatif-validation-pass.png) | Joiner `-WhatIf` corrected dry-run validation | ✅ Committed |
| 33 | [`33-joiner-group-verification.png`](33-joiner-group-verification.png) | Olivia Bennett group verification | ✅ Committed |
| 34 | [`34-joiner-audit-log.png`](34-joiner-audit-log.png) | `Joiner.log` excerpt | ✅ Committed |
| 35 | [`35-mover-before-daniel-hr-access.png`](35-mover-before-daniel-hr-access.png) | Daniel Kim before-state (HR access) | ✅ Committed |
| 36 | [`36-mover-whatif-daniel.png`](36-mover-whatif-daniel.png) | Mover `-WhatIf` preview for Daniel | ✅ Committed |
| 37 | [`37-mover-daniel-success.png`](37-mover-daniel-success.png) | Mover execution result | ✅ Committed |
| 38 | [`38-mover-daniel-group-verification.png`](38-mover-daniel-group-verification.png) | Daniel Kim post-move group verification | ✅ Committed |
| 39 | [`39-mover-audit-log.png`](39-mover-audit-log.png) | `Mover.log` excerpt | ✅ Committed |
| 40 | [`40-leaver-before-marcus-access.png`](40-leaver-before-marcus-access.png) | Marcus Reed before-state (contractor access) | ✅ Committed |
| 41 | [`41-leaver-whatif-marcus.png`](41-leaver-whatif-marcus.png) | Leaver `-WhatIf` preview for Marcus | ✅ Committed |
| 42 | `42-leaver-marcus-success.png` | Leaver execution result | Pending redaction (public IP visible) |
| 43 | [`43-leaver-marcus-access-removed.png`](43-leaver-marcus-access-removed.png) | Marcus Reed post-offboarding group verification | ✅ Committed |
| 44 | [`44-leaver-audit-log.png`](44-leaver-audit-log.png) | `Leaver.log` excerpt | ✅ Committed |
| 45 | [`45-access-audit-syntax.png`](45-access-audit-syntax.png) | `Get-AccessAudit.ps1` invocation | ✅ Committed |
| 46 | [`46-access-audit-results.png`](46-access-audit-results.png) | Access audit results (0/3 mismatches) | ✅ Committed |
| 47 | [`47-identity-controls-validation.png`](47-identity-controls-validation.png) | `Test-IdentityControls.ps1` — 7/7 PASS | ✅ Committed |
| 48 | `48-entra-tenant-overview.png` | Microsoft Entra tenant overview | Not captured |
| 49 | `49-alternative-upn-suffix-added.png` | Verified UPN suffix added to AD | Not captured |
| 50 | `50-olivia-upn-updated.png` | Olivia Bennett's UPN updated | Pending redaction (tenant name visible) |
| 51 | [`51-cloud-sync-agent-downloaded.png`](51-cloud-sync-agent-downloaded.png) | Cloud Sync agent installer downloaded | ✅ Committed |
| 52 | [`52-cloud-sync-agent-install.png`](52-cloud-sync-agent-install.png) | Cloud Sync agent installation in progress | ✅ Committed |
| 53 | `53-cloud-sync-agent-confirmation.png` | Cloud Sync agent configuration confirmation page | Pending redaction (tenant name visible) |
| 54 | `54-cloud-sync-agent-success.png` | Cloud Sync agent configuration confirmed | Not captured |

```
[i] No screenshots exist past #54 — because no further steps
    (sync execution, Conditional Access, SSO, etc.) have been done.
    See ../docs/hybrid-identity-progress.md
```
