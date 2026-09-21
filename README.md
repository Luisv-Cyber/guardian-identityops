# Guardian Financial Technologies — Hybrid IAM Lifecycle Automation Lab

A portfolio project demonstrating identity lifecycle automation across a Windows Server Active Directory environment, with in-progress preparation for Microsoft Entra hybrid synchronization.

**Status at a glance:** Local Active Directory IAM automation and governance is **complete and validated**. Microsoft Entra hybrid synchronization is **in progress** — the Cloud Sync provisioning agent has been installed and configured, but actual synchronization has not yet been run or validated. See [Current Status](#current-status) and [Known Limitations / Remaining Work](#known-limitations--remaining-work) below for the exact line between what has been verified and what has not.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Business Problem](#business-problem)
- [Architecture](#architecture)
- [Active Directory Design](#active-directory-design)
- [RBAC / Security Group Model](#rbac--security-group-model)
- [PowerShell Automation](#powershell-automation)
- [Joiner / Mover / Leaver Validation](#joiner--mover--leaver-validation)
- [Access Auditing and Identity Control Testing](#access-auditing-and-identity-control-testing)
- [Microsoft Entra Hybrid Identity Preparation](#microsoft-entra-hybrid-identity-preparation)
- [Security Decisions](#security-decisions)
- [What I Learned](#what-i-learned)
- [Current Status](#current-status)
- [Known Limitations / Remaining Work](#known-limitations--remaining-work)
- [Evidence and Screenshots](#evidence-and-screenshots)
- [Skills Demonstrated](#skills-demonstrated)
- [Disclaimer](#disclaimer)

---

## Project Overview

Guardian Financial Technologies (GFT) is a fictional company used to model a realistic identity and access management environment. The project goes beyond a basic Active Directory lab by implementing controlled identity lifecycle management: role-based access control, PowerShell-driven Joiner/Mover/Leaver automation with safe dry-run behavior, independent verification after every change, access auditing, identity governance control testing, and preparation for Microsoft Entra hybrid identity.

## Business Problem

Manual identity administration at a growing organization tends to produce inconsistent access, stale accounts, privilege accumulation over time, and slow or incomplete offboarding — all of which create real security risk, particularly around terminated contractors retaining access. This project addresses that by enforcing group-based, least-privilege access and automating the lifecycle events (provisioning, role changes, termination) that are most often handled inconsistently by hand.

## Architecture

```
Employee Data (CSV)
        |
        v
PowerShell JML Automation (Invoke-Joiner / Invoke-Mover / Invoke-Leaver)
        |
        v
Active Directory Domain Services (corp.guardianlab.internal)
        |
        v
Group-based RBAC (Global Security Groups)
        |
        v
Access Audit + Identity Control Validation
        |
        v
Microsoft Entra Cloud Sync  <-- installed/configured, sync not yet run
        |
        v
Microsoft Entra ID (MFA / Conditional Access / SSO)  <-- not yet configured
```

**Azure infrastructure (completed):**

| Resource | Value |
|---|---|
| Resource Group | `rg-gft-identitylab` |
| Virtual Network | `vnet-gft-identity` (East US 2, `10.0.0.0/16`) |
| Server Subnet | `snet-servers` (`10.0.1.0/24`) |
| Domain Controller VM | `DC01` — Windows Server 2022 Datacenter: Azure Edition x64 Gen2, `Standard_D2als_v7` (2 vCPU / 4 GiB RAM) |
| Private IP | Static at the Azure NIC layer (Windows itself still reports DHCP Enabled = Yes — this is expected Azure behavior; the platform reserves the IP rather than requiring it hardcoded in-guest) |
| Network Security | Custom rule `Allow-RDP-MyIP` — TCP/3389 restricted to a single source IP, priority 310. The default/broad RDP allow rule was removed. |
| Cost control | Auto-shutdown configured; VM stopped/deallocated between lab sessions |

Full detail: [`docs/architecture.md`](docs/architecture.md)

## Active Directory Design

Domain controller `DC01` runs AD DS and DNS for the forest `corp.guardianlab.internal`. Verified via `Get-ADDomain`, `Get-ADForest`, and `Get-Service DNS,NTDS` (both services confirmed running).

```
corp.guardianlab.internal
└── GFT
    ├── Users
    │   ├── IT
    │   ├── Security
    │   ├── Human Resources
    │   ├── Finance
    │   └── Operations
    ├── Groups
    ├── Servers
    ├── Service Accounts
    ├── Administrative Accounts
    ├── Disabled Users
    └── Contractors
```

## RBAC / Security Group Model

All access is granted through Global Security Groups — never assigned directly to individual users.

| Group | Purpose |
|---|---|
| `GG-All-Employees` | Baseline group for every employee |
| `GG-EmployeePortal-Users` | Baseline employee application access |
| `GG-Contractors` | Baseline (and by default, only) group for contractors |
| `GG-IT-Users` | IT department access |
| `GG-IT-HelpDesk` | Help Desk role access |
| `GG-HelpDesk-PasswordReset` | Scoped password-reset delegation |
| `GG-Security-Users` | Security department access |
| `GG-Security-Analysts` | Security Analyst role access |
| `GG-HR-Users` | HR department access |
| `GG-Finance-Users` | Finance department access |
| `GG-Finance-Analysts` | Finance Analyst role access |
| `GG-FinanceApp-Users` | Finance application access |
| `GG-Operations-Users` | Operations department access |
| `GG-Server-Admins` | Privileged infrastructure access |

**Role-to-group mapping**, e.g.: a normal employee gets `GG-All-Employees` + `GG-EmployeePortal-Users`; a Finance Analyst additionally gets `GG-Finance-Users`, `GG-Finance-Analysts`, and `GG-FinanceApp-Users`; a contractor gets `GG-Contractors` **only** by default, with no employee baseline groups — any further access must be explicitly granted. Regular lifecycle automation does not assign `GG-Server-Admins` to standard accounts under any circumstance, including a title change to a systems administration role.

## PowerShell Automation

```
C:\GFT-IAM\
├── Data
├── Logs
├── Reports
└── Scripts
    ├── Get-AccessAudit.ps1
    ├── Invoke-Joiner.ps1
    ├── Invoke-Leaver.ps1
    ├── Invoke-Mover.ps1
    ├── New-LabUsers.ps1
    ├── Test-IdentityControls.ps1
    └── Modules
        └── IAMLabCommon.psm1
```

Every lifecycle script supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`) and logs to `Scripts\Logs\` (`Joiner.log`, `Mover.log`, `Leaver.log`). See [`docs/joiner-workflow.md`](docs/joiner-workflow.md), [`docs/mover-workflow.md`](docs/mover-workflow.md), and [`docs/leaver-workflow.md`](docs/leaver-workflow.md) for the full before/whatif/after detail of each validated run.

**A real bug was found and fixed during testing, not just designed around:** the initial `Invoke-Joiner.ps1` implementation still created a live AD account during a `-WhatIf` dry run. This was caught by manually verifying `Get-ADUser` after the dry run, the incorrectly created test account was removed, and `SupportsShouldProcess` / `$PSCmdlet.ShouldProcess()` were implemented correctly and re-validated. Full writeup in [What I Learned](#what-i-learned).

## Joiner / Mover / Leaver Validation

Three lifecycle scenarios were executed and independently verified against live AD state (not just script output):

| Scenario | Identity | Result |
|---|---|---|
| **Joiner** | Olivia Bennett (`GFT1031`) — new Finance Analyst | Account created in `OU=Finance`; groups: `Domain Users`, `GG-All-Employees`, `GG-EmployeePortal-Users`, `GG-Finance-Analysts`, `GG-FinanceApp-Users`, `GG-Finance-Users`. `VerificationPassed: True` |
| **Mover** | Daniel Kim (`GFT1012`) — HR Coordinator → IT, Junior System Administrator | `GG-HR-Users` removed, `GG-IT-Users` added, moved to `OU=IT`; confirmed **no** `GG-Server-Admins` assigned despite the sysadmin title. `VerificationPassed: True` |
| **Leaver** | Marcus Reed (`GFT1004`) — Finance contractor, terminated | Account disabled, `GG-Contractors` removed, moved to `OU=Disabled Users`; post-offboarding groups: `Domain Users` only. `VerificationPassed: True` |

Each scenario was run as `-WhatIf` first, the dry-run output was checked against actual AD state to confirm no changes occurred, and only then executed for real.

## Access Auditing and Identity Control Testing

`Get-AccessAudit.ps1` was run across all three test identities: **0 of 3 accounts flagged with an access mismatch.**

`Test-IdentityControls.ps1` validated seven identity governance controls — **all seven passed**:

| Control | Result |
|---|---|
| CONTROL-001 — Disabled users are not members of business groups | PASS |
| CONTROL-002 — Contractors do not have `GG-Server-Admins` | PASS |
| CONTROL-003 — FinanceApp access limited to approved Finance Analysts | PASS |
| CONTROL-004 — Help Desk users do not have server admin rights | PASS |
| CONTROL-005 — Privileged access uses separate `adm-` style accounts | PASS |
| CONTROL-006 — Disabled users are located in the Disabled Users OU | PASS |
| CONTROL-007 — Active employees have expected department groups | PASS |

**Final result: IDENTITY CONTROLS: PASS**

## Microsoft Entra Hybrid Identity Preparation

**Completed:**
* Microsoft Entra tenant accessed (Microsoft Entra ID Free license)
* Alternative verified UPN suffix (`*.onmicrosoft.com`) added to AD, since `corp.guardianlab.internal` is not a routable cloud domain
* Pilot identity (Olivia Bennett) UPN updated to the verified suffix; legacy logon name (`CORP\olivia.bennett`) preserved; new UPN confirmed via PowerShell
* Dedicated cloud-only administrator created (`GFT Hybrid Identity Admin`, Member user type, **Hybrid Identity Administrator** Entra role, MFA registered) — kept intentionally separate from Azure subscription/VM permissions
* Microsoft Entra Cloud Sync provisioning agent installed on `DC01` and configured with a group-managed service account (`corp.guardianlab.internal\provAgentgMSA`), authenticating as the dedicated Hybrid Identity Administrator

**Not completed — explicitly not claimed as working:**
* Cloud Sync configuration and agent health verification in Entra
* OU/group scoping for synchronization
* Any actual synchronization of Olivia, Daniel, or any other user/group
* Cloud sign-in or password-hash/cloud authentication validation
* Conditional Access policy deployment or testing
* Cloud MFA policy testing beyond registering MFA on the admin account
* SSO / SAML / OIDC application integration
* Azure App Service employee portal, Managed Identity, or Key Vault integration
* Cloud-side Joiner/Mover/Leaver synchronization or deprovisioning validation
* Access Reviews, SCIM provisioning
* Final architecture diagram and demo video

Full detail: [`docs/hybrid-identity-progress.md`](docs/hybrid-identity-progress.md)

## Security Decisions

* Access is granted exclusively through security groups, never direct-to-user, so a role's access is always reviewable from its group membership alone
* Contractors receive no baseline employee access by default — access is opt-in and explicit, not opt-out
* A title change to a systems administration role does not itself grant `GG-Server-Admins` — privileged access is a separate, deliberate decision
* Privileged access is modeled through separate `adm-` style accounts, not the standard user account
* The Entra hybrid administrator account was created cloud-only and scoped to a directory role, deliberately kept separate from Azure subscription-level permissions
* MFA was registered on the privileged Entra admin account before it was used for the Cloud Sync agent configuration
* `-WhatIf` dry-run behavior for destructive/creating operations was not trusted on the strength of the parameter existing — it was independently verified against live AD state after a bug was found doing exactly this
* No secrets, passwords, tenant IDs, subscription IDs, public IPs, or personal information are committed to this repository (see `SECURITY.md`)

Full detail: [`docs/architecture.md`](docs/architecture.md) and script comments in [`scripts/`](scripts/).

## What I Learned

1. **Cloud hosting alone doesn't make a project a cloud IAM project.** The differentiators here were lifecycle automation, RBAC, auditability, least privilege, and deliberate hybrid identity preparation — not just "AD running on a VM."
2. **Never trust `-WhatIf` without independently verifying it.** The first `Invoke-Joiner.ps1` implementation still created a real AD account during a dry run. It was caught by checking `Get-ADUser` after the "preview," not by trusting the script's own claimed behavior.
3. **A Mover workflow has to remove obsolete access, not just add new access.** Daniel's HR-specific group membership was removed as part of the same operation that granted IT access — not left behind as legacy permissions.
4. **A job title is not an access decision.** Daniel became a Junior System Administrator but did not receive `GG-Server-Admins` — privilege has to be assigned deliberately, never inferred from a title.
5. **Offboarding has to be verifiable, not just executed.** Marcus's termination was checked independently after the fact (disabled, correct OU, no remaining business groups) rather than trusted because the script reported success.
6. **Authentication and authorization are different systems.** Every test identity received permissions exclusively through group membership, never a direct grant.
7. **Azure RBAC and Microsoft Entra directory roles are separate permission systems.** The Hybrid Identity Administrator role didn't require, and wasn't given, any Azure VM/subscription-level access.
8. **Hybrid identity requires deliberate UPN planning before sync can even be attempted.** `corp.guardianlab.internal` isn't a routable domain, so a verified `.onmicrosoft.com` suffix had to be added and applied to the pilot user before synchronization could be meaningfully tested.

## Current Status

| Area | Status |
|---|---|
| Local AD / IAM foundation | **Complete** |
| JML automation (Joiner/Mover/Leaver) | **Complete** |
| RBAC / security group model | **Complete** |
| Access auditing | **Complete** |
| Identity control validation | **Complete** (7/7 controls passed) |
| Entra hybrid preparation (tenant, UPN, admin account, sync agent install) | **Complete** |
| Actual Entra Cloud Sync execution and validation | **Not completed** |
| Conditional Access | **Not completed** |
| SSO | **Not completed** |
| Managed Identity / Key Vault | **Not completed** |

**Overall: approximately 70–75% complete.**

## Known Limitations / Remaining Work

The following have **not** been done and are not claimed anywhere in this repository as working:

* Cloud Sync configuration itself has not been created, and no synchronization has been run
* No user or group has actually synchronized to Microsoft Entra ID yet
* No cloud sign-in, password-hash sync, or cloud authentication has been validated
* No Conditional Access policy has been deployed or tested
* No SSO / SAML / OIDC application integration exists
* No Azure App Service, Managed Identity, or Key Vault work has been done
* No cloud-side Joiner/Mover/Leaver synchronization or deprovisioning has been validated
* Access Reviews and SCIM provisioning are not implemented
* No final architecture diagram or demo video has been produced yet

## Evidence and Screenshots

Screenshot filenames are reserved in [`screenshots/README.md`](screenshots/README.md) for each verified step above. All screenshots must be sanitized (passwords, temporary passwords, tenant IDs, subscription IDs, personal email, public IP, secrets/tokens redacted) before being added — see `SECURITY.md`. No screenshots have been committed yet; the filenames document what evidence exists locally and is pending manual redaction and upload.

## Skills Demonstrated

Microsoft Azure • Windows Server 2022 • Active Directory Domain Services • DNS • Azure Virtual Networking • Network Security Groups • RDP hardening • PowerShell • ActiveDirectory PowerShell module • IAM • RBAC • Least privilege • Security groups • Joiner/Mover/Leaver automation • Provisioning and deprovisioning • Access auditing • Identity governance • Control testing • Microsoft Entra ID • UPN planning • Hybrid identity preparation • Microsoft Entra Cloud Sync agent • gMSA • MFA for administrative identities • Troubleshooting • Validation • Audit logging • Change safety with `-WhatIf` / `ShouldProcess`

## Disclaimer

This is a **simulated environment** built for educational and portfolio purposes. Guardian Financial Technologies is a fictional company. No real employee, contractor, or personal data is used. No real tenant IDs, subscription IDs, public IP addresses, passwords, or secrets are included in this repository — see `SECURITY.md`. Work described as complete above was independently verified during the lab session; work described as not completed has not been attempted or has not been validated, and is not claimed as functioning.
