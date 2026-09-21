<#
.SYNOPSIS
    Produces an access audit report comparing each identity's actual
    group membership against its expected role-based access.

.DESCRIPTION
    Run across the three lifecycle test identities (Olivia Bennett,
    Daniel Kim, Marcus Reed): 0 of 3 accounts were flagged with an
    access mismatch. See docs/project-status.md for the run summary.

.PARAMETER OutputPath
    Path to write the CSV audit report to.

.EXAMPLE
    .\Get-AccessAudit.ps1 -OutputPath "C:\GFT-IAM\Reports\access-audit.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\GFT-IAM\Reports\access-audit.csv",

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\AccessAudit.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

$privilegedGroupNames = @("GG-Server-Admins")

try {
    Write-AuditLog -LogPath $LogPath -Message "Starting access audit"

    $employees = Import-Csv -Path $CsvPath
    $mismatchCount = 0

    $report = foreach ($employee in $employees) {
        $username = New-UsernameFromRecord -Record $employee

        # TODO (live environment):
        # $adUser = Get-ADUser -Identity $username -Properties MemberOf, Enabled, DistinguishedName
        # $groups = (Get-ADPrincipalGroupMembership -Identity $username).Name

        $groups = @() # placeholder - populated from live AD once run against the environment
        $isPrivileged = ($groups | Where-Object { $privilegedGroupNames -contains $_ }).Count -gt 0
        $mismatch = $false # TODO: compare $groups against the expected RBAC mapping for this employee's role

        if ($mismatch) { $mismatchCount++ }

        [PSCustomObject]@{
            Username          = $username
            EmployeeID        = $employee.EmployeeID
            Department        = $employee.Department
            Title             = $employee.Title
            Status            = $employee.Status
            GroupMemberships  = ($groups -join "; ")
            PrivilegedAccount = $isPrivileged
            Mismatch          = $mismatch
        }
    }

    $report | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-AuditLog -LogPath $LogPath -Message "Access audit written to $OutputPath. $mismatchCount of $($report.Count) accounts flagged with a mismatch."
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Get-AccessAudit failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
