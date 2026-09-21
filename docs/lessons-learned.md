# Lessons Learned

1. **Cloud hosting alone does not make an AD project a cloud IAM project.** The key differentiators demonstrated here are lifecycle automation, RBAC, auditability, least privilege, and hybrid identity preparation — not simply running AD on a VM.

2. **Never trust `-WhatIf` without independently validating it.** The original `Invoke-Joiner.ps1` implementation still created a real AD account during a dry run (`-WhatIf`). This was caught by testing against Olivia Bennett and then manually checking `Get-ADUser -Identity "olivia.bennett"` — the account existed when it should not have. The incorrectly created test account was removed, and `SupportsShouldProcess` / `$PSCmdlet.ShouldProcess()` were implemented correctly, with `-WhatIf` forwarding added across module boundaries where needed. The fix was validated by rerunning the dry run and confirming, independently, that no account was created.

3. **A Mover workflow should remove obsolete access, not just add new permissions.** Daniel Kim's HR-specific group membership (`GG-HR-Users`) was removed as part of the same operation that granted IT access (`GG-IT-Users`), rather than left in place as legacy access.

4. **Normal admin-sounding job titles should not automatically receive infrastructure privilege.** Daniel became a Junior System Administrator but did not receive `GG-Server-Admins` — privileged access has to be a deliberate, separate decision, not something inferred from a title change.

5. **Offboarding should be verifiable, not just executed.** Marcus Reed's termination was checked independently after the Leaver workflow ran: account disabled, business groups removed, correct OU placement, confirmed via a separate access audit — not just trusted because the script reported success.

6. **Authentication identities and authorization permissions are different systems.** Every test identity received its access exclusively through group membership rather than any direct permission assignment.

7. **Azure RBAC and Microsoft Entra directory roles are separate permission systems.** The dedicated Hybrid Identity Administrator account was scoped to that Entra directory role only and intentionally does not have Azure VM or subscription-level access.

8. **Hybrid identity requires intentional UPN planning before synchronization can even be meaningfully attempted.** `corp.guardianlab.internal` is not a routable/verified cloud domain, so a verified `*.onmicrosoft.com` UPN suffix had to be added to AD and applied to the pilot identity before cloud sync could proceed.
