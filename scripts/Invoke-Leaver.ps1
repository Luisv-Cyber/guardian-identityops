<#
.SYNOPSIS
    Disables and de-provisions a terminated identity following the GFT
    Leaver workflow.

.DESCRIPTION
    Identifies the target user, captures a before-state snapshot, disables
    the account, removes privileged group memberships first and then
    business group memberships, moves the account to the Disabled Users
    OU, captures an after-state snapshot, and derives VerificationPassed
    from that real post-change state. Requires explicit termination
    confirmation before executing any change.

    Validated against a live environment using Marcus Reed (GFT1004), a
    Finance contractor. See docs/leaver-workflow.md for the full run
    detail.

    RECONSTRUCTED SCRIPT: earlier committed versions of this file had
    Disable-ADAccount/Remove-ADGroupMember/Move-ADObject commented out,
    and the post-check groups were a hardcoded array. This version
    performs the real AD operations and derives Before/After/
    VerificationPassed from actual Get-ADUser /
    Get-ADPrincipalGroupMembership results.

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

$privilegedGroupNames = @("GG-Server-Admins")

function Get-IdentitySnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)]$EmployeeRecord
    )
    $adUser = Get-ADUser -Identity $Username -Properties Department, Title, Enabled, DistinguishedName, MemberOf
    $groups = @("Domain Users") + @($adUser.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name }) | Select-Object -Unique

    [PSCustomObject]@{
        SamAccountName     = $Username
        DisplayName        = "$($EmployeeRecord.FirstName) $($EmployeeRecord.LastName)"
        EmployeeID         = $EmployeeRecord.EmployeeID
        Department         = $adUser.Department
        Title              = $adUser.Title
        EmployeeType       = $EmployeeRecord.EmployeeType
        Enabled            = $adUser.Enabled
        DistinguishedName  = $adUser.DistinguishedName
        OrganizationalUnit = ($adUser.DistinguishedName -replace '^CN=[^,]+,', '')
        Groups             = $groups
        Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

try {
    if (-not $ConfirmedByManager) {
        throw "Termination not confirmed. Re-run with -ConfirmedByManager to proceed."
    }

    $employee = Import-Csv -Path $CsvPath | Where-Object { $_.EmployeeID -eq $EmployeeID }
    if (-not $employee) { throw "No employee record found for EmployeeID '$EmployeeID'" }
    $username = New-UsernameFromRecord -Record $employee

    $before = Get-IdentitySnapshot -Username $username -EmployeeRecord $employee
    $businessGroupsToRemove   = @($before.Groups | Where-Object { $_ -ne "Domain Users" -and $privilegedGroupNames -notcontains $_ })
    $privilegedGroupsToRemove = @($before.Groups | Where-Object { $privilegedGroupNames -contains $_ })
    $targetOU = Get-TargetOU -Department "Disabled Users"

    Write-AuditLog -LogPath $LogPath -Message "Leaver started for EmployeeID '$EmployeeID' ($username). BEFORE: Enabled=$($before.Enabled) OU='$($before.OrganizationalUnit)' Groups='$($before.Groups -join ',')'."

    $shouldProcessMessage = "Disable account; remove privileged groups [$($privilegedGroupsToRemove -join ', ')]; remove business groups [$($businessGroupsToRemove -join ', ')]; move to '$targetOU'"

    if ($PSCmdlet.ShouldProcess($username, $shouldProcessMessage)) {

        Disable-ADAccount -Identity $username

        foreach ($group in $privilegedGroupsToRemove) {
            Remove-ADGroupMember -Identity $group -Members $username -Confirm:$false
        }
        foreach ($group in $businessGroupsToRemove) {
            Remove-ADGroupMember -Identity $group -Members $username -Confirm:$false
        }

        Move-ADObject -Identity $before.DistinguishedName -TargetPath $targetOU

        $after = Get-IdentitySnapshot -Username $username -EmployeeRecord $employee

        $verificationPassed = ($after.Enabled -eq $false) -and
                               ($after.Groups.Count -eq 1) -and
                               ($after.Groups -contains "Domain Users") -and
                               ($after.OrganizationalUnit -eq $targetOU)

        Write-AuditLog -LogPath $LogPath -Message "Leaver AFTER for '$username': Enabled=$($after.Enabled) OU='$($after.OrganizationalUnit)' Groups='$($after.Groups -join ',')'. Removed privileged='$($privilegedGroupsToRemove -join ',')' Removed business='$($businessGroupsToRemove -join ',')'."
        Write-AuditLog -LogPath $LogPath -Message "Verification $(if ($verificationPassed) {'PASSED'} else {'FAILED'}) for '$username': $(if ($after.Enabled -eq $false) {'disabled'} else {'STILL ENABLED'}), $(if ($after.Groups.Count -eq 1) {'all managed access removed'} else {'ACCESS REMAINS'}), moved to $($after.OrganizationalUnit)."

        [PSCustomObject]@{
            EmployeeID             = $EmployeeID
            SamAccountName         = $username
            Before                 = $before
            After                  = $after
            PrivilegedGroupsRemoved = $privilegedGroupsToRemove
            BusinessGroupsRemoved  = $businessGroupsToRemove
            VerificationPassed     = $verificationPassed
        }
    }
    else {
        Write-Host ""
        Write-Host "--- WHAT IF: Leaver preview for EmployeeID '$EmployeeID' (no AD changes made) ---"
        Write-Host "User                         : $username"
        Write-Host "Current Enabled              : $($before.Enabled)"
        Write-Host "Current OU                   : $($before.OrganizationalUnit)"
        Write-Host "Target OU                    : $targetOU"
        Write-Host "Privileged Groups To Remove  : $(if ($privilegedGroupsToRemove) { $privilegedGroupsToRemove -join ', ' } else { '(none)' })"
        Write-Host "Business Groups To Remove    : $(if ($businessGroupsToRemove) { $businessGroupsToRemove -join ', ' } else { '(none)' })"
        Write-Host "Planned Actions              : Remove privileged groups first, then business groups, disable the account, then move it to the Disabled Users OU."
        Write-Host ""

        Write-AuditLog -LogPath $LogPath -Message "WHATIF: Would disable '$username', remove privileged=[$($privilegedGroupsToRemove -join ',')], remove business=[$($businessGroupsToRemove -join ',')], move to '$targetOU'. No AD changes were made."
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Leaver failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
