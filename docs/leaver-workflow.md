# Leaver Workflow — Validated

**Test identity:** Marcus Reed — `GFT1004`
**Type:** Finance contractor (Accounts Payable Analyst)

## Provisioning (for test setup)

Marcus was provisioned as a contractor: account `marcus.reed`, OU `Contractors`, initial groups `Domain Users`, `GG-Contractors`. `VerificationPassed: True`.

## Dry Run (`-WhatIf`)

The dry run correctly previewed:

* Removal of `GG-Contractors`
* Account disablement
* Move to Disabled Users OU
* **No AD changes made**

## Real Execution

| Field | Value |
|---|---|
| Enabled | False |
| BusinessGroupsRemoved | GG-Contractors |
| Target OU | Disabled Users |
| VerificationPassed | True |

## Independent Group Verification

Post-offboarding group membership: **Domain Users only.** No remaining business or contractor groups.

## Log Review

`Leaver.log` was reviewed and documented:

**Before:** account enabled, Contractors OU, `Domain Users` + `GG-Contractors`
**WhatIf:** planned disable, planned `GG-Contractors` removal, planned move to Disabled Users, no AD changes made
**After:** `Enabled=False`, `OU=Disabled Users`, `Groups=Domain Users`, verification **PASSED**
