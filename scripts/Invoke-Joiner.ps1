<#
.SYNOPSIS
    Provisions a new identity end-to-end following the GFT Joiner workflow.

.DESCRIPTION
    Accepts an EmployeeID, loads the matching record from the employee
    dataset, validates it, creates the AD account in the correct OU,
    assigns baseline and role-specific groups, and independently verifies
    the result by re-querying AD - not by trusting that the steps above
    ran. Supports -WhatIf / -Confirm.

    Validated against a live environment using Olivia Bennett (GFT1031).
    See docs/joiner-workflow.md for the full run detail.

    RECONSTRUCTED SCRIPT: earlier committed versions of this file had
    New-ADUser/Add-ADGroupMember commented out and VerificationPassed
    hardcoded to $true. This version performs the real AD operations and
    computes VerificationPassed from a fresh Get-ADUser query, matching
    the behavior demonstrated in the lab screenshots. The temporary
    password generator below is a reconstruction, not the original
    algorithm - see New-SecureTemporaryPassword's own notes.

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
    trusting it. See docs/lessons-learned.md. This version's dry-run
    branch performs no AD calls at all, and the real-run branch verifies
    itself via a fresh query rather than trusting its own prior steps.
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

function New-SecureTemporaryPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically random temporary password.

    .NOTES
        RECONSTRUCTED: the exact password-generation code used in the
        original lab session was not preserved anywhere in the evidence
        (screenshots only ever showed the resulting masked/redacted
        value, consistent with the "not stored or logged anywhere"
        message). This is a reasonable, secure replacement built for
        this reconstruction - it is not a recovery of the original
        implementation.
    #>
    param([int]$Length = 16)

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghijkmnpqrstuvwxyz'
    $digits  = '23456789'
    $special = '!@#$%^&*-_=+'
    $all     = $upper + $lower + $digits + $special

    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $password = -join (for ($i = 0; $i -lt $Length; $i++) { $all[$bytes[$i] % $all.Length] })

    $hasUpper   = $password -cmatch '[A-Z]'
    $hasLower   = $password -cmatch '[a-z]'
    $hasDigit   = $password -match '[0-9]'
    $hasSpecial = $password -match '[!@#\$%\^&\*\-_=\+]'

    if (-not ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial)) {
        return New-SecureTemporaryPassword -Length $Length
    }
    return $password
}

try {
    Write-AuditLog -LogPath $LogPath -Message "Starting Joiner workflow for EmployeeID '$EmployeeID'"

    $employee = Get-EmployeeRecord -EmployeeID $EmployeeID -CsvPath $CsvPath
    $username = New-UsernameFromRecord -Record $employee
    $isContractor = $employee.EmployeeType -eq "Contractor"
    $targetOU = Get-TargetOU -Department (if ($isContractor) { "Contractors" } else { $employee.Department })
    $groups   = Get-ExpectedGroups -Record $employee
    $upn      = "$username@corp.guardianlab.internal"
    $displayName = "$($employee.FirstName) $($employee.LastName)"

    $shouldProcessMessage = "Create AD user '$username' (UPN: $upn) in OU '$targetOU' and add to groups: $($groups -join ', ')"

    if ($PSCmdlet.ShouldProcess($username, $shouldProcessMessage)) {

        Write-AuditLog -LogPath $LogPath -Message "Planned: user=$username OU=$targetOU groups=$($groups -join ', ')"

        $tempPassword = New-SecureTemporaryPassword
        $securePassword = ConvertTo-SecureString $tempPassword -AsPlainText -Force

        New-ADUser -Name $displayName `
            -SamAccountName $username `
            -UserPrincipalName $upn `
            -Path $targetOU `
            -Department $employee.Department `
            -Title $employee.Title `
            -AccountPassword $securePassword `
            -ChangePasswordAtLogon $true `
            -Enabled ($employee.Status -eq "Active")

        foreach ($group in $groups) {
            Add-ADGroupMember -Identity $group -Members $username
        }

        Write-AuditLog -LogPath $LogPath -Message "Created account '$username' for EmployeeID '$EmployeeID' in OU '$targetOU' with groups: $($groups -join ', ')."

        # Password is shown to the console only - never written to the log file.
        Write-Host ""
        Write-Host "IMPORTANT: Record and securely hand off the temporary password now. It is not stored or logged anywhere." -ForegroundColor Yellow
        Write-Host "TemporaryPassword: $tempPassword" -ForegroundColor Yellow
        Write-Host ""

        # Independent verification - re-query AD rather than trusting the steps above.
        $verify = Get-ADUser -Identity $username -Properties MemberOf, DistinguishedName, Enabled
        $actualGroups = @($verify.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })
        $ouMatches = $verify.DistinguishedName -like "*$targetOU"
        $allGroupsPresent = ($groups | Where-Object { $actualGroups -notcontains $_ }).Count -eq 0
        $verificationPassed = ($null -ne $verify) -and $ouMatches -and $allGroupsPresent

        Write-AuditLog -LogPath $LogPath -Message "Verification $(if ($verificationPassed) {'PASSED'} else {'FAILED'}) for '$username': user exists, OU $(if ($ouMatches) {'correct'} else {'MISMATCH'}), groups $(if ($allGroupsPresent) {'correct'} else {'MISMATCH'})."

        [PSCustomObject]@{
            EmployeeID          = $EmployeeID
            SamAccountName      = $username
            UserPrincipalName   = $upn
            DisplayName         = $displayName
            OrganizationalUnit  = $targetOU
            AssignedGroups      = $actualGroups
            TemporaryPassword   = $tempPassword
            VerificationPassed  = $verificationPassed
        }
    }
    else {
        # -WhatIf / declined -Confirm: no AD calls made at all.
        Write-Host ""
        Write-Host "--- WHAT IF: Joiner preview for EmployeeID '$EmployeeID' (no AD changes made) ---"
        Write-Host "Employee Name         : $displayName"
        Write-Host "Generated Username    : $username"
        Write-Host "UPN                   : $upn"
        Write-Host "Target OU             : $targetOU"
        Write-Host "Expected Groups       : $($groups -join ', ')"
        Write-Host "Planned Actions       : Create the AD user, set a temporary password requiring change at next logon, and add the account to the groups listed above."
        Write-Host ""

        Write-AuditLog -LogPath $LogPath -Message "WHATIF: Would create account '$username' for EmployeeID '$EmployeeID' in OU '$targetOU' with groups: $($groups -join ', '). No AD changes were made."
    }
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Invoke-Joiner failed for '$EmployeeID': $($_.Exception.Message)" -Level "ERROR"
    throw
}
