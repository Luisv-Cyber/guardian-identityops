# Reconstruction Notes

This document exists so the public repository never blurs together five different things that are easy to conflate:

| Category | Meaning |
|---|---|
| **Historical lab evidence** | What actually happened in the real Azure/AD lab session — captured in screenshots, logs quoted in docs, and the narrative in `walkthrough/`. This did happen, regardless of what the public code currently does. |
| **Current public implementation** | What the scripts committed to this repo can actually do, unmodified, right now. |
| **Reconstructed implementation** | Public code that was rewritten from evidence after the fact, because the original code behind a screenshot was not preserved. Reconstructed code is functionally intended to reproduce the evidenced behavior, but it is not a recovery of the original source. |
| **Re-validated result** | A reconstructed script has been re-run against the lab environment and independently reproduced a result that was previously only historical. |
| **In progress / not done** | Self-explanatory — not claimed as working. |

## Why this document exists

An earlier pass at this repository committed PowerShell "skeletons" — scripts with commented-out AD calls, hardcoded `$verificationPassed = $true`, an empty `$groups = @()` placeholder, and every identity control returning `$true` unconditionally — while the README and docs described those same scripts as "validated against a live environment." Screenshots from the actual lab session showed real AD operations, real output schemas, and (for the control validation) an `Offenders` column implying real per-control queries. The scaffolded code could not have produced that evidence. That gap has now been closed by rewriting the affected scripts from the evidence — see the table below for exactly what changed and what remains unverified.

## Per-script status

| Script | Status | Notes |
|---|---|---|
| `Invoke-Joiner.ps1` | **Reconstructed** | Real `New-ADUser`/`Add-ADGroupMember` calls, verification from a fresh `Get-ADUser` query, output schema matched to the evidenced fields (`EmployeeID, SamAccountName, UserPrincipalName, DisplayName, OrganizationalUnit, AssignedGroups, TemporaryPassword, VerificationPassed`). The temporary-password generator is a new, secure implementation — the original algorithm was never preserved in any evidence, only its masked/redacted output. **Not yet re-run** against the live environment since reconstruction. |
| `Invoke-Mover.ps1` | **Reconstructed** | Real `Set-ADUser`/`Remove-ADGroupMember`/`Add-ADGroupMember`/`Move-ADObject`, with full `Before`/`After` state snapshots matching the evidenced object shape. **Not yet re-run.** |
| `Invoke-Leaver.ps1` | **Reconstructed** | Real `Disable-ADAccount`/`Remove-ADGroupMember`/`Move-ADObject`, `PrivilegedGroupsRemoved`/`BusinessGroupsRemoved` preserved as separate fields. **Not yet re-run.** |
| `Get-AccessAudit.ps1` | **Reconstructed** | Real `Get-ADPrincipalGroupMembership` query compared against the shared `Get-ExpectedGroups` mapping; can now produce a genuine mismatch, not just "0 mismatches" by construction. The historical **0 of 3 accounts flagged** result stands as a documented finding from the lab session, produced by whatever implementation actually ran at the time (not this scaffold) — it is **not currently re-validated** against this reconstructed version. |
| `Test-IdentityControls.ps1` | **Reconstructed** | Each of the seven controls now runs a real AD query and returns an `Offenders` array instead of an unconditional `$true`. The exact original query syntax behind each control was not recoverable from evidence, so each is implemented using the most direct standard cmdlet consistent with that control's documented plain-English definition. The historical **7/7 PASS** result stands as a documented finding from the lab session — it is **not currently re-validated** against this reconstructed version. A logic bug was also found and fixed during reconstruction: the FAIL branch was assigning the boolean `$false` instead of the string `"FAIL"` to the result field. |
| `IAMLabCommon.psm1` — `Test-LabEnvironment` | **Reconstructed** | Now performs real `Get-ADOrganizationalUnit`/`Get-ADGroup`/`Get-ADDomain` queries and prints a per-check line for every check (not only on failure), reproducing the dot-leader format shown in the evidenced screenshot. |
| `IAMLabCommon.psm1` — `Get-ExpectedGroups` | **New, extracted** | Not itself a reconstruction of lost code — this is the same role-mapping logic that already existed only inside `Invoke-Joiner.ps1`, pulled into the shared module so Joiner, Mover, Access Audit, and Identity Controls can't silently drift into contradicting each other. |
| `New-LabUsers.ps1` | **Designed, not evidenced as executed** | No screenshot or log shows a bulk-creation run. Left as-is; do not read its presence as proof it was ever run in the lab. |

## What "historical" results mean going forward

The **3 lifecycle scenarios** (Joiner/Mover/Leaver), the **0 of 3 access mismatches**, and the **7/7 identity controls** results are all real findings from the lab session — the screenshots are not fabricated and are not in question. What changed is only the relationship between those results and the code in this repository:

- Before this reconstruction: the public code for Access Audit and Identity Controls **could not have produced** those results under any AD state — they were guaranteed outcomes, not test results.
- After this reconstruction: the public code **can now produce a genuine PASS or FAIL** depending on actual AD state, but it has not yet been run again against the lab to confirm it reproduces the historical numbers.

Until that re-run happens, treat "0 mismatches" and "7/7 PASS" as **historical, not currently reproducible** — see the quantitative claims table in the main README and `docs/project-status.md`.
