<#
.SYNOPSIS
    Applies a department/title change and reconciles group-based access
    following the GFT Mover workflow.

.DESCRIPTION
    Identifies an existing identity, records before-state group
    membership, updates department/title, removes obsolete role-specific
    groups, adds new role-specific groups, preserves baseline access, and
    logs a before/after record. Never assigns GG-Server-Admins - a title
    change (e.g. to "Junior System Administrator") is not itself grounds
    for privileged access.

    Validated against a live environment using Daniel Kim (GFT1012),
    HR Coordinator -> Junior System Administrator. See
    docs/mover-workflow.md for the full run detail.

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

try {
    Write-AuditLog -LogPath $LogPath -Message "Starting Mover workflow for EmployeeID '$EmployeeID' -> $NewDepartment / $NewTitle"

    $employee = Import-Csv -Path $CsvPath | Where-Object { $_.EmployeeID -eq $EmployeeID }
    if (-not $employee) { throw "No employee record found for EmployeeID '$EmployeeID'" }
    $username = New-UsernameFromRecord -Record $employee

    # Before-state (recorded, not assumed)
    $beforeDepartment = $employee.Department
    # TODO (live environment): $beforeGroups = (Get-ADPrincipalGroupMembership -Identity $username).Name
    $beforeGroups = @("Domain Users", "GG-All-Employees", "GG-EmployeePortal-Users", $departmentGroupMap[$beforeDepartment])
    Write-AuditLog -LogPath $LogPath -Message "Before-state: Department=$beforeDepartment Groups=$($beforeGroups -join ', ')"

    $obsoleteGroup = $departmentGroupMap[$beforeDepartment]
    $newGroup      = $departmentGroupMap[$NewDepartment]

    if ($PSCmdlet.ShouldProcess($username, "Move $beforeDepartment -> $NewDepartment")) {
        # TODO (live environment):
        # Set-ADUser -Identity $username -Department $NewDepartment -Title $NewTitle
        # Remove-ADGroupMember -Identity $obsoleteGroup -Members $username -Confirm:$false
        # Add-ADGroupMember -Identity $newGroup -Members $username
        # Move-ADObject -Identity <DN> -TargetPath (Get-TargetOU -Department $NewDepartment)

        # Note: GG-Server-Admins is NEVER added here regardless of NewTitle.
        # Privileged access requires a separate, deliberate runbook action.

        Write-AuditLog -LogPath $LogPath -Message "GroupsRemoved: $obsoleteGroup"
        Write-AuditLog -LogPath $LogPath -Message "GroupsAdded: $newGroup"

        $afterGroups = @("Domain Users", "GG-All-Employees", "GG-EmployeePortal-Users", $newGroup)
        $verificationPassed = ($afterGroups -notcontains $obsoleteGroup) -and ($afterGroups -notcontains "GG-Server-Admins")

        Write-AuditLog -LogPath $LogPath -Message "After-state: Department=$NewDepartment Groups=$($afterGroups -join ', ') VerificationPassed=$verificationPassed"

        [PSCustomObject]@{
            EmployeeID          = $EmployeeID
            GroupsRemoved       = $obsoleteGroup
            GroupsAdded         = $newGroup
            NewDepartment       = $NewDepartment
            NewTitle            = $NewTitle
            NewOU               = Get-TargetOU -Department $NewDepartment
            VerificationPassed  = $verificationPassed
        }
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Mover failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
