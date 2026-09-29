<#
.SYNOPSIS
    Produces an access audit report comparing each identity's actual
    group membership against its expected role-based access.

.DESCRIPTION
    A prior lab run of an access audit against Olivia Bennett, Daniel
    Kim, and Marcus Reed produced 0 of 3 accounts flagged with an access
    mismatch (see docs/project-status.md and screenshots/46-access-audit-results.png).
    That result is preserved here as a historical, documented finding.

    RECONSTRUCTED SCRIPT: the version of this script previously
    committed to this repository used an empty placeholder group list
    ($groups = @()) and a hardcoded $mismatch = $false, which meant it
    would report "0 mismatches" unconditionally regardless of actual AD
    state - it could not have produced the historical result on its own,
    and could not currently detect a real mismatch if one existed. This
    version queries actual AD group membership via
    Get-ADPrincipalGroupMembership and compares it against the shared
    Get-ExpectedGroups mapping (IAMLabCommon.psm1), so it is capable of
    producing both matches and mismatches. The historical "0 of 3"
    result should be treated as a lab finding from an earlier
    implementation until this reconstructed version is re-run against
    the live environment and reproduces it.

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

        $adUser = Get-ADUser -Identity $username -Properties MemberOf, Enabled, DistinguishedName -ErrorAction SilentlyContinue

        if (-not $adUser) {
            Write-AuditLog -LogPath $LogPath -Message "No AD account found for '$username' (EmployeeID $($employee.EmployeeID)) - skipping" -Level "WARN"
            continue
        }

        $actualGroups = @("Domain Users") + @($adUser.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name }) | Select-Object -Unique

        # Expected access: a disabled account should hold nothing but the
        # Domain Users baseline, regardless of its role. An active
        # account is expected to hold the baseline plus its role's
        # groups from the shared mapping.
        $expectedGroups = if ($adUser.Enabled -eq $false) {
            @("Domain Users")
        }
        else {
            @("Domain Users") + (Get-ExpectedGroups -Record $employee) | Select-Object -Unique
        }

        $missing    = @($expectedGroups | Where-Object { $actualGroups -notcontains $_ })
        $unexpected = @($actualGroups | Where-Object { $expectedGroups -notcontains $_ })
        $mismatch   = ($missing.Count -gt 0) -or ($unexpected.Count -gt 0)
        $isPrivileged = ($actualGroups | Where-Object { $privilegedGroupNames -contains $_ }).Count -gt 0

        if ($mismatch) { $mismatchCount++ }

        [PSCustomObject]@{
            Username          = $username
            EmployeeID        = $employee.EmployeeID
            DisplayName       = "$($adUser.GivenName) $($adUser.Surname)"
            Department        = $employee.Department
            Title             = $employee.Title
            EmployeeType      = $employee.EmployeeType
            Enabled           = $adUser.Enabled
            OU                = ($adUser.DistinguishedName -replace '^CN=[^,]+,', '')
            GroupMemberships  = ($actualGroups -join "; ")
            PrivilegedAccount = $isPrivileged
            Mismatch          = $mismatch
            MissingGroups     = ($missing -join "; ")
            UnexpectedGroups  = ($unexpected -join "; ")
        }
    }

    $report | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-AuditLog -LogPath $LogPath -Message "Access audit written to $OutputPath. $mismatchCount of $($report.Count) accounts flagged with a mismatch."
    Write-Host "$mismatchCount of $($report.Count) accounts flagged with an access mismatch."
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Get-AccessAudit failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
