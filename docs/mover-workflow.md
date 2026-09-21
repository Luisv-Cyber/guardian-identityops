# Mover Workflow — Validated

**Test identity:** Daniel Kim — `GFT1012`
**Change:** Human Resources / HR Coordinator → IT / Junior System Administrator

## Before State

| Field | Value |
|---|---|
| Department | Human Resources |
| Title | HR Coordinator |
| OU | Human Resources |
| Groups | Domain Users, GG-All-Employees, GG-EmployeePortal-Users, GG-HR-Users |

`Invoke-Mover.ps1`'s actual parameters were inspected before use: `-EmployeeID`, `-NewDepartment`, `-NewTitle`, `-LogPath`, `-WhatIf`, `-Confirm`.

## Dry Run (`-WhatIf`)

Run with `-EmployeeID GFT1012 -NewDepartment IT -NewTitle "Junior System Administrator"`. The dry run correctly previewed:

* Move from HR OU to IT OU
* Removal of `GG-HR-Users`
* Addition of `GG-IT-Users`
* Preservation of baseline employee access
* **No AD changes made**
* **No `GG-Server-Admins` assignment**

## Real Execution

| Field | Value |
|---|---|
| GroupsRemoved | GG-HR-Users |
| GroupsAdded | GG-IT-Users |
| New Department | IT |
| New Title | Junior System Administrator |
| New OU | OU=IT,OU=Users,OU=GFT,... |
| VerificationPassed | True |

## Independent Group Verification

Final group membership, checked independently:

* Domain Users
* GG-All-Employees
* GG-EmployeePortal-Users
* GG-IT-Users

Confirmed **absent**: `GG-HR-Users`, `GG-Server-Admins`. This validated that obsolete access was removed and that a title change did not accumulate privileged access.

## Log Review

`Mover.log` was reviewed and included the before state, the `-WhatIf` preview, the executed change, old-group removal, new-group assignment, the OU move, a passed verification, and an explicit note of no privilege accumulation.
