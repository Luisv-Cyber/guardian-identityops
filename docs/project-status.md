# Project Status

| Area | Status |
|---|---|
| Azure infrastructure (RG, VNet, DC01 VM, NSG, auto-shutdown) | Complete |
| Active Directory / DNS on DC01 | Complete |
| OU hierarchy | Complete |
| RBAC / security group model | Complete |
| PowerShell automation (Joiner/Mover/Leaver/Audit/Controls) | Complete — code reconstructed from evidence, see below |
| Environment validation (`Test-LabEnvironment`) | Historical run: PASS. Script reconstructed since — not yet re-run |
| Joiner workflow (Olivia Bennett) | Historical run: complete, verified. Script reconstructed since — not yet re-run |
| Mover workflow (Daniel Kim) | Historical run: complete, verified. Script reconstructed since — not yet re-run |
| Leaver workflow (Marcus Reed) | Historical run: complete, verified. Script reconstructed since — not yet re-run |
| Access audit | Historical run: 0/3 mismatches. Script reconstructed since — not yet re-validated |
| Identity control testing | Historical run: 7/7 PASS. Script reconstructed since — not yet re-validated |
| Entra tenant access + UPN suffix planning | Complete |
| Pilot UPN update (Olivia) | Complete |
| Dedicated Hybrid Identity Administrator + MFA | Complete |
| Entra Cloud Sync agent install/config on DC01 | Complete |
| **Actual Cloud Sync configuration + execution** | **Not completed** |
| **Synchronization validation (any user)** | **Not completed** |
| **Cloud sign-in / password-hash validation** | **Not completed** |
| **Conditional Access** | **Not completed** |
| **SSO / SAML / OIDC** | **Not completed** |
| **Managed Identity / Key Vault** | **Not completed** |
| **Access Reviews / SCIM** | **Not completed** |
| **Final architecture diagram / demo video** | **Not completed** |

**Overall: approximately 70–75% complete.**

The local, on-premises IAM lifecycle phase (AD, RBAC, JML automation, auditing, control validation) happened and was independently verified in the lab session. The public scripts implementing that phase were later found to be scaffolds that couldn't reproduce what the screenshots showed, and have since been reconstructed from the available evidence — see [`docs/reconstruction-notes.md`](reconstruction-notes.md) for exactly what changed and what still needs a fresh lab run to re-confirm. The Microsoft Entra hybrid identity phase is prepared through agent installation and configuration but has not reached actual synchronization or any cloud-side validation.
