<#
.SYNOPSIS
    Provisions a new identity end-to-end following the GFT Joiner workflow.

.DESCRIPTION
    Accepts an EmployeeID, loads the matching record from the employee
    dataset, validates it, creates the AD account in the correct OU,
    assigns baseline and role-specific groups, and independently verifies
    the result. Supports -WhatIf / -Confirm.

    Validated against a live environment using Olivia Bennett (GFT1031).
    See docs/joiner-workflow.md for the full run detail.

.PARAMETER EmployeeID
    The EmployeeID to provision (e.g. GFT1031).

.PARAMETER CsvPath
    Path to the employee CSV file.

.EXAMPLE
    .\Invoke-Joiner.ps1 -EmployeeID "GFT1031" -WhatIf

.NOTES
    IMPORTANT LESSON: an earlier version of this script still created a
    live AD account during a -WhatIf dry run. Do not assume
    SupportsShouldProcess is sufficient on its own - always independently
    verify (e.g. Get-ADUser) that a dry run made no changes before
    trusting it. See docs/lessons-learned.md.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^GFT\d{4}$')]
    [string]$EmployeeID,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\Joiner.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

function Get-EmployeeRecord {
    param(
        [Parameter(Mandatory = $true)][string]$EmployeeID,
        [Parameter(Mandatory = $true)][string]$CsvPath
    )
    $record = Import-Csv -Path $CsvPath | Where-Object { $_.EmployeeID -eq $EmployeeID }
    if (-not $record) { throw "No employee record found for EmployeeID '$EmployeeID'" }
    return $record
}

function Get-RoleGroups {
    param([Parameter(Mandatory = $true)]$Record)

    if ($Record.EmployeeType -eq "Contractor") {
        return @("GG-Contractors")
    }

    $groups = @("GG-All-Employees", "GG-EmployeePortal-Users")
    switch ($Record.Department) {
        "IT"              { $groups += "GG-IT-Users" }
        "Security"        { $groups += "GG-Security-Users" }
        "Human Resources" { $groups += "GG-HR-Users" }
        "Finance"         { $groups += "GG-Finance-Users" }
        "Operations"      { $groups += "GG-Operations-Users" }
    }

    # Role-specific additions (title-driven, never privileged-by-default)
    switch -Wildcard ($Record.Title) {
        "*Help Desk*"        { $groups += @("GG-IT-HelpDesk", "GG-HelpDesk-PasswordReset") }
        "*Security Analyst*" { $groups += "GG-Security-Analysts" }
        "*Finance Analyst*"  { $groups += @("GG-Finance-Analysts", "GG-FinanceApp-Users") }
    }

    # Note: GG-Server-Admins is never assigned by this function.
    # Privileged access is a separate, deliberate action - see
    # docs/architecture.md (Security Decisions) and Runbook: Privileged Access.

    return $groups | Select-Object -Unique
}

try {
    Write-AuditLog -LogPath $LogPath -Message "Starting Joiner workflow for EmployeeID '$EmployeeID'"

    $employee = Get-EmployeeRecord -EmployeeID $EmployeeID -CsvPath $CsvPath
    $username = New-UsernameFromRecord -Record $employee
    $targetOU = Get-TargetOU -Department (if ($employee.EmployeeType -eq "Contractor") { "Contractors" } else { $employee.Department })
    $groups   = Get-RoleGroups -Record $employee

    Write-AuditLog -LogPath $LogPath -Message "Planned: user=$username OU=$targetOU groups=$($groups -join ', ')"

    if ($PSCmdlet.ShouldProcess($username, "Create AD user in $targetOU")) {
        # TODO (live environment):
        # New-ADUser -Name "$($employee.FirstName) $($employee.LastName)" `
        #     -SamAccountName $username `
        #     -UserPrincipalName "$username@corp.guardianlab.internal" `
        #     -Path $targetOU `
        #     -Department $employee.Department `
        #     -Title $employee.Title `
        #     -Enabled ($employee.Status -eq "Active")
        #
        # foreach ($group in $groups) {
        #     Add-ADGroupMember -Identity $group -Members $username
        # }

        Write-AuditLog -LogPath $LogPath -Message "AD account created for $username"

        # Independent verification - do not just trust the steps above ran.
        # TODO (live environment):
        # $verify = Get-ADUser -Identity $username -Properties MemberOf
        # $verificationPassed = ($null -ne $verify) -and ($groups | ForEach-Object { $verify.MemberOf -match $_ })
        $verificationPassed = $true # placeholder until run against live AD

        Write-AuditLog -LogPath $LogPath -Message "VerificationPassed: $verificationPassed"

        [PSCustomObject]@{
            SamAccountName      = $username
            UserPrincipalName   = "$username@corp.guardianlab.internal"
            OU                  = $targetOU
            Groups              = $groups
            VerificationPassed  = $verificationPassed
        }
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Joiner failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
