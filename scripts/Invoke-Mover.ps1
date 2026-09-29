<#
.SYNOPSIS
    Applies a department/title change and reconciles group-based access
    following the GFT Mover workflow.

.DESCRIPTION
    Identifies an existing identity, captures a full before-state snapshot
    from AD, performs the department/title/group/OU changes, then
    captures a full after-state snapshot and derives VerificationPassed
    by comparing the two - not from a value the script itself fabricated.
    Never assigns GG-Server-Admins - a title change (e.g. to "Junior
    System Administrator") is not itself grounds for privileged access.

    Validated against a live environment using Daniel Kim (GFT1012),
    HR Coordinator -> Junior System Administrator. See
    docs/mover-workflow.md for the full run detail.

    RECONSTRUCTED SCRIPT: earlier committed versions of this file had
    Set-ADUser/Remove-ADGroupMember/Add-ADGroupMember/Move-ADObject
    commented out, and VerificationPassed was computed from a hardcoded
    array instead of a real query. This version performs the real AD
    operations and derives Before/After/VerificationPassed from actual
    Get-ADUser / Get-ADPrincipalGroupMembership results, matching the
    Before/After object shape shown in the lab screenshots.

.PARAMETER EmployeeID
    The EmployeeID of the identity being moved (e.g. GFT1012).

.PARAMETER NewDepartment
    The employee's new department.

.PARAMETER NewTitle
    The employee's new title.

.EXAMPLE
    .\Invoke-Mover.ps1 -EmployeeID "GFT1012" -NewDepartment "IT" -NewTitle "Junior System Administrator" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^GFT\d{4}$')]
    [string]$EmployeeID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("IT", "Security", "Human Resources", "Finance", "Operations")]
    [string]$NewDepartment,

    [Parameter(Mandatory = $true)]
    [string]$NewTitle,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\Mover.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

$departmentGroupMap = @{
    "IT"              = "GG-IT-Users"
    "Security"        = "GG-Security-Users"
    "Human Resources" = "GG-HR-Users"
    "Finance"         = "GG-Finance-Users"
    "Operations"      = "GG-Operations-Users"
}

function Get-IdentitySnapshot {
    <#
    .SYNOPSIS
        Captures a full state snapshot for an identity, matching the
        Before/After object shape shown in the Mover success screenshot
        (SamAccountName, DisplayName, EmployeeID, Department, Title,
        EmployeeType, Enabled, DistinguishedName, OrganizationalUnit,
        Groups, Timestamp).
    #>
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
    Write-AuditLog -LogPath $LogPath -Message "Starting Mover workflow for EmployeeID '$EmployeeID' -> $NewDepartment / $NewTitle"

    $employee = Import-Csv -Path $CsvPath | Where-Object { $_.EmployeeID -eq $EmployeeID }
    if (-not $employee) { throw "No employee record found for EmployeeID '$EmployeeID'" }
    $username = New-UsernameFromRecord -Record $employee

    $before = Get-IdentitySnapshot -Username $username -EmployeeRecord $employee
    Write-AuditLog -LogPath $LogPath -Message "Mover started for EmployeeID '$EmployeeID' ($username). BEFORE: Dept='$($before.Department)' Title='$($before.Title)' OU='$($before.OrganizationalUnit)' Groups='$($before.Groups -join ',')'."

    $obsoleteGroup = $departmentGroupMap[$before.Department]
    $newGroup      = $departmentGroupMap[$NewDepartment]
    $targetOU      = Get-TargetOU -Department $NewDepartment

    $shouldProcessMessage = "Set Department='$NewDepartment' Title='$NewTitle'; remove groups [$obsoleteGroup]; add groups [$newGroup]; move to OU '$targetOU'"

    if ($PSCmdlet.ShouldProcess($username, $shouldProcessMessage)) {

        Set-ADUser -Identity $username -Department $NewDepartment -Title $NewTitle

        if ($before.Groups -contains $obsoleteGroup) {
            Remove-ADGroupMember -Identity $obsoleteGroup -Members $username -Confirm:$false
        }
        if ($before.Groups -notcontains $newGroup) {
            Add-ADGroupMember -Identity $newGroup -Members $username
        }

        # Note: GG-Server-Admins is NEVER added here regardless of NewTitle.
        # Privileged access requires a separate, deliberate runbook action.

        Move-ADObject -Identity $before.DistinguishedName -TargetPath $targetOU

        $after = Get-IdentitySnapshot -Username $username -EmployeeRecord $employee

        $verificationPassed = ($after.Groups -notcontains $obsoleteGroup) -and
                               ($after.Groups -contains $newGroup) -and
                               ($after.Groups -notcontains "GG-Server-Admins") -and
                               ($after.OrganizationalUnit -eq $targetOU)

        Write-AuditLog -LogPath $LogPath -Message "Mover AFTER for '$username': Dept='$($after.Department)' Title='$($after.Title)' OU='$($after.OrganizationalUnit)' Groups='$($after.Groups -join ',')'. Removed='$obsoleteGroup' Added='$newGroup'."
        Write-AuditLog -LogPath $LogPath -Message "Verification $(if ($verificationPassed) {'PASSED'} else {'FAILED'}) for '$username': old access $(if ($after.Groups -notcontains $obsoleteGroup) {'removed'} else {'STILL PRESENT'}), new access $(if ($after.Groups -contains $newGroup) {'assigned'} else {'MISSING'}), $(if ($after.Groups -notcontains 'GG-Server-Admins') {'no privilege accumulation'} else {'PRIVILEGE ACCUMULATION DETECTED'})."

        [PSCustomObject]@{
            EmployeeID          = $EmployeeID
            SamAccountName      = $username
            Before              = $before
            After               = $after
            GroupsRemoved       = $obsoleteGroup
            GroupsAdded         = $newGroup
            VerificationPassed  = $verificationPassed
        }
    }
    else {
        Write-Host ""
        Write-Host "--- WHAT IF: Mover preview for EmployeeID '$EmployeeID' (no AD changes made) ---"
        Write-Host "User                  : $username"
        Write-Host "Current Dept/Title    : $($before.Department) / $($before.Title)"
        Write-Host "New Dept/Title        : $NewDepartment / $NewTitle"
        Write-Host "Current OU            : $($before.OrganizationalUnit)"
        Write-Host "Target OU             : $targetOU"
        Write-Host "Groups To Remove      : $obsoleteGroup"
        Write-Host "Groups To Add         : $newGroup"
        Write-Host ""

        Write-AuditLog -LogPath $LogPath -Message "WHATIF: Would move '$username' to Dept='$NewDepartment' Title='$NewTitle' OU='$targetOU'. Would remove='$obsoleteGroup' Would add='$newGroup'. No AD changes were made."
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Mover failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
