# Microsoft Entra Hybrid Identity — Progress

This document exists specifically to draw a clear, honest line between what was completed and what was not, for the cloud/hybrid portion of the project.

## Completed

* Microsoft Entra tenant accessed successfully (Microsoft Entra ID Free license observed)
* Because `corp.guardianlab.internal` is not a verified/routable cloud domain, an alternative UPN suffix using the tenant's verified `*.onmicrosoft.com` domain was added to Active Directory via Active Directory Domains and Trusts
* Olivia Bennett selected as the pilot cloud-sync identity; her UPN was changed from `olivia.bennett@corp.guardianlab.internal` to `olivia.bennett@[tenant].onmicrosoft.com`. Her legacy logon name (`CORP\olivia.bennett`) was preserved. The new UPN was confirmed via PowerShell.
* A dedicated cloud-only Entra administrator was created — display name **GFT Hybrid Identity Admin**, username pattern `gfthybridadmin@[tenant].onmicrosoft.com`, User type **Member**, assigned the **Hybrid Identity Administrator** Entra role, with MFA registered.
  * Lesson: Azure subscription roles and Microsoft Entra directory roles are separate systems — this account intentionally has no Azure VM/resource permissions.
* The Microsoft Entra Cloud Sync / provisioning agent (`AADConnectProvisioningAgentSetup.exe`) was downloaded, copied to `DC01`, and run as administrator.
  * During setup, "Connect to Active Directory domain(s)" was selected, authenticating as the dedicated Hybrid Identity Administrator.
  * A sign-in issue caused by Internet Explorer Enhanced Security Configuration blocking Microsoft authentication resources was resolved by temporarily disabling IE ESC for Administrators in Server Manager; the wizard was then restarted successfully.
  * Service account: **Create gMSA** was selected. Domain admin credentials were supplied during setup only. The configured gMSA is `corp.guardianlab.internal\provAgentgMSA`.
  * The configuration confirmation page showed: AD domain `corp.guardianlab.internal`, gMSA `corp.guardianlab.internal\provAgentgMSA`, Entra account = the dedicated GFT Hybrid Identity Admin. Configuration was confirmed.
  * IE Enhanced Security Configuration was intended to be re-enabled before ending the session. The Azure VM was then stopped/deallocated.

## Not Completed

The lab session ended **after** the provisioning agent was installed and configured, but **before** the actual Cloud Sync configuration and sync validation were completed. None of the following should be read as done:

* Cloud Sync agent health verification inside Entra
* Creation of the actual Cloud Sync configuration
* OU/group scoping for synchronization
* Successful synchronization of Olivia Bennett, Daniel Kim, or any other user/group
* Cloud sign-in validation
* Password-hash / cloud authentication validation
* Conditional Access policy deployment
* Conditional Access testing
* Cloud MFA policy testing beyond registering MFA on the admin account itself
* SSO application configuration
* SAML integration
* OIDC integration
* Azure App Service employee portal
* Managed Identity implementation
* Azure Key Vault integration
* Cloud-side Joiner/Mover/Leaver synchronization
* Cloud-side deprovisioning validation
* Access Reviews
* SCIM provisioning
* Final architecture diagram
* Final polished demo video

## Summary

| Item | Status |
|---|---|
| Entra tenant access | Complete |
| UPN suffix planning + application | Complete |
| Dedicated Hybrid Identity Administrator + MFA | Complete |
| Cloud Sync agent install/config on DC01 | Complete |
| Actual Cloud Sync configuration and execution | Not completed |
| Any synchronization validation | Not completed |
| Conditional Access, SSO, Managed Identity, Key Vault | Not completed |
