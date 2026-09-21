# Joiner Workflow — Validated

**Test identity:** Olivia Bennett — `GFT1031`
**Department / Title:** Finance / Financial Analyst
**Employee Type:** Employee

## Dry Run (`-WhatIf`)

A `-WhatIf` test was run first, after the dry-run safety bug (see [Lessons Learned](lessons-learned.md)) had been found and corrected. The corrected dry run showed:

* Target username
* Target OU
* Expected groups
* Planned provisioning steps
* **No AD changes made**

## Real Execution

The Joiner workflow was then executed for real.

| Field | Value |
|---|---|
| SamAccountName | `olivia.bennett` |
| Original UPN | `olivia.bennett@corp.guardianlab.internal` |
| OU | `OU=Finance,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal` |
| VerificationPassed | `True` |

## Independent Group Verification

Olivia's group membership was checked independently after provisioning (not assumed from script output):

* Domain Users
* GG-All-Employees
* GG-EmployeePortal-Users
* GG-Finance-Analysts
* GG-FinanceApp-Users
* GG-Finance-Users

## Log Review

`Joiner.log` was reviewed and confirmed it captured: the `-WhatIf` preview, confirmation that no AD changes occurred during the dry run, the real account creation, the expected groups, and a passed verification step.
