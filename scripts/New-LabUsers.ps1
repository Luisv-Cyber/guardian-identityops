<#
.SYNOPSIS
    Bulk-creates the GFT lab employee dataset in Active Directory.

.DESCRIPTION
    Reads Data\employees.csv and creates a matching AD account for each
    record, applying OU placement and baseline group membership. Used to
    seed the lab environment prior to running individual JML scenarios.

    STATUS: designed, not evidenced as executed. No screenshot or log
    from the lab session shows a bulk-creation run - all three test
    identities (Olivia Bennett, Daniel Kim, Marcus Reed) were provisioned
    individually via Invoke-Joiner.ps1. This script is left as a
    -WhatIf-safe scaffold; do not read its presence in this repo as
    proof it was ever run.

.PARAMETER CsvPath
    Path to the employee CSV file.

.EXAMPLE
    .\New-LabUsers.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\New-LabUsers.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

try {
    $employees = Import-Csv -Path $CsvPath
    Write-AuditLog -LogPath $LogPath -Message "Loaded $($employees.Count) employee records from $CsvPath"

    foreach ($employee in $employees) {
        $username = New-UsernameFromRecord -Record $employee
        $dept = if ($employee.EmployeeType -eq "Contractor") { "Contractors" } else { $employee.Department }
        $targetOU = Get-TargetOU -Department $dept

        if ($PSCmdlet.ShouldProcess($username, "Create AD user in $targetOU")) {
            # TODO (live environment):
            # New-ADUser -Name "$($employee.FirstName) $($employee.LastName)" `
            #     -SamAccountName $username `
            #     -UserPrincipalName "$username@corp.guardianlab.internal" `
            #     -Path $targetOU `
            #     -Department $employee.Department `
            #     -Title $employee.Title `
            #     -Enabled ($employee.Status -eq "Active")
            Write-AuditLog -LogPath $LogPath -Message "Would create $username in $targetOU"
        }
    }

    Write-AuditLog -LogPath $LogPath -Message "Bulk user creation pass complete"
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "New-LabUsers failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
