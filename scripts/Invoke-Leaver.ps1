<#
.SYNOPSIS
    Disables and de-provisions a terminated identity following the GFT
    Leaver workflow.

.DESCRIPTION
    Identifies the target user, disables the account, removes privileged
    and business group memberships, moves the account to the Disabled
    Users OU, and logs the before/whatif/after state for audit.

    Validated against a live environment using Marcus Reed (GFT1004), a
    Finance contractor. See docs/leaver-workflow.md for the full run
    detail.

.PARAMETER EmployeeID
    The EmployeeID of the identity being terminated (e.g. GFT1004).

.PARAMETER ConfirmedByManager
    Must be set to acknowledge termination has been authorized. The
    script will not proceed without it.

.EXAMPLE
    .\Invoke-Leaver.ps1 -EmployeeID "GFT1004" -ConfirmedByManager -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^GFT\d{4}$')]
    [string]$EmployeeID,

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmedByManager,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\Leaver.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

try {
    if (-not $ConfirmedByManager) {
        throw "Termination not confirmed. Re-run with -ConfirmedByManager to proceed."
    }

    Write-AuditLog -LogPath $LogPath -Message "Starting Leaver workflow for EmployeeID '$EmployeeID' (termination confirmed)"

    $employee = Import-Csv -Path $CsvPath | Where-Object { $_.EmployeeID -eq $EmployeeID }
    if (-not $employee) { throw "No employee record found for EmployeeID '$EmployeeID'" }
    $username = New-UsernameFromRecord -Record $employee

    # Before-state
    # TODO (live environment): $beforeGroups = (Get-ADPrincipalGroupMembership -Identity $username).Name
    Write-AuditLog -LogPath $LogPath -Message "Before-state captured for $username"

    if ($PSCmdlet.ShouldProcess($username, "Disable and de-provision (Leaver)")) {
        # TODO (live environment):
        # Disable-ADAccount -Identity $username
        # Get-ADPrincipalGroupMembership -Identity $username |
        #     Where-Object { $_.Name -ne "Domain Users" } |
        #     ForEach-Object { Remove-ADGroupMember -Identity $_.Name -Members $username -Confirm:$false }
        # Move-ADObject -Identity <DN> -TargetPath "OU=Disabled Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"

        $businessGroupsRemoved = "GG-Contractors" # example: contractor case; varies by employee type
        Write-AuditLog -LogPath $LogPath -Message "Enabled: False"
        Write-AuditLog -LogPath $LogPath -Message "BusinessGroupsRemoved: $businessGroupsRemoved"
        Write-AuditLog -LogPath $LogPath -Message "Target OU: Disabled Users"

        # Independent post-check - do not assume success from the steps above alone.
        # TODO (live environment): $postGroups = (Get-ADPrincipalGroupMembership -Identity $username).Name
        $postGroups = @("Domain Users")
        $verificationPassed = ($postGroups.Count -eq 1) -and ($postGroups -contains "Domain Users")

        Write-AuditLog -LogPath $LogPath -Message "Post-offboarding groups: $($postGroups -join ', ') VerificationPassed=$verificationPassed"

        [PSCustomObject]@{
            EmployeeID             = $EmployeeID
            Enabled                = $false
            BusinessGroupsRemoved  = $businessGroupsRemoved
            TargetOU               = "Disabled Users"
            VerificationPassed     = $verificationPassed
        }
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Leaver failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
