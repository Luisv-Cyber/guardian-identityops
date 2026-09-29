<#
.SYNOPSIS
    Validates identity governance controls (CONTROL-001 through
    CONTROL-007) against the live GFT environment.

.DESCRIPTION
    A prior lab run of this control set produced IDENTITY CONTROLS: PASS
    (7/7), shown in screenshots/47-identity-controls-validation.png with
    an Offenders column that was empty ({}) for every control - implying
    each control evaluated real AD state and found nothing, rather than
    passing unconditionally. That result is preserved here as a
    historical, documented finding.

    RECONSTRUCTED SCRIPT: the version of this script previously
    committed to this repository had every Test-ControlXXX function
    return $true unconditionally, with no AD query at all - it could not
    have produced the evidenced Offenders column, and could not
    currently detect a real control violation if one existed. This
    version queries AD directly for each control and builds a real
    Offenders array. The screenshots do not reveal the exact original
    query syntax behind each control, so each one below is implemented
    using the most direct, standard cmdlet consistent with that
    control's documented plain-English definition - this is a
    reconstruction of the intended check, not a recovery of the
    original code. Re-run this against the live environment before
    treating "7/7 PASS" as a currently-reproducible result.

.EXAMPLE
    .\Test-IdentityControls.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = "C:\GFT-IAM\Data\employees.csv",

    [string]$LogPath = "C:\GFT-IAM\Scripts\Logs\IdentityControls.log"
)

Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force

function Test-Control001-DisabledUsersNotInBusinessGroups {
    <# Disabled users should hold no GG-* business group membership. #>
    $offenders = @()
    $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties MemberOf
    foreach ($u in $disabledUsers) {
        $groups = @($u.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })
        if ($groups | Where-Object { $_ -like "GG-*" }) { $offenders += $u.SamAccountName }
    }
    return $offenders
}

function Test-Control002-ContractorsNoServerAdmins {
    <# No member of GG-Contractors should also be a member of GG-Server-Admins. #>
    $contractors = @(Get-ADGroupMember -Identity "GG-Contractors" -ErrorAction SilentlyContinue)
    $admins      = @(Get-ADGroupMember -Identity "GG-Server-Admins" -ErrorAction SilentlyContinue)
    return @($contractors | Where-Object { $admins.SamAccountName -contains $_.SamAccountName } | Select-Object -ExpandProperty SamAccountName)
}

function Test-Control003-FinanceAppLimitedToApprovedAnalysts {
    <# Everyone in GG-FinanceApp-Users must also be in GG-Finance-Analysts. #>
    $financeApp = @(Get-ADGroupMember -Identity "GG-FinanceApp-Users" -ErrorAction SilentlyContinue)
    $analysts   = @(Get-ADGroupMember -Identity "GG-Finance-Analysts" -ErrorAction SilentlyContinue)
    return @($financeApp | Where-Object { $analysts.SamAccountName -notcontains $_.SamAccountName } | Select-Object -ExpandProperty SamAccountName)
}

function Test-Control004-HelpDeskNoServerAdmin {
    <# No member of GG-IT-HelpDesk should also be a member of GG-Server-Admins. #>
    $helpdesk = @(Get-ADGroupMember -Identity "GG-IT-HelpDesk" -ErrorAction SilentlyContinue)
    $admins   = @(Get-ADGroupMember -Identity "GG-Server-Admins" -ErrorAction SilentlyContinue)
    return @($helpdesk | Where-Object { $admins.SamAccountName -contains $_.SamAccountName } | Select-Object -ExpandProperty SamAccountName)
}

function Test-Control005-PrivilegedAccountsUseAdmPrefix {
    <# Every member of GG-Server-Admins should be an adm- style account. #>
    $admins = @(Get-ADGroupMember -Identity "GG-Server-Admins" -ErrorAction SilentlyContinue)
    return @($admins | Where-Object { $_.SamAccountName -notlike "adm-*" } | Select-Object -ExpandProperty SamAccountName)
}

function Test-Control006-DisabledUsersInDisabledOU {
    <# Every disabled account must be located under OU=Disabled Users. #>
    $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties DistinguishedName
    $expectedOU = Get-TargetOU -Department "Disabled Users"
    return @($disabledUsers | Where-Object { $_.DistinguishedName -notlike "*$expectedOU" } | Select-Object -ExpandProperty SamAccountName)
}

function Test-Control007-ActiveEmployeesHaveExpectedDeptGroups {
    <# Every active employee should hold their department's expected group(s). #>
    param([Parameter(Mandatory = $true)][string]$CsvPath)

    $offenders = @()
    $activeEmployees = Import-Csv -Path $CsvPath | Where-Object { $_.Status -eq "Active" -and $_.EmployeeType -eq "Employee" }
    foreach ($record in $activeEmployees) {
        $username = New-UsernameFromRecord -Record $record
        $adUser = Get-ADUser -Identity $username -Properties MemberOf -ErrorAction SilentlyContinue
        if (-not $adUser) { continue }
        $groups = @($adUser.MemberOf | ForEach-Object { (Get-ADGroup -Identity $_).Name })
        $expected = Get-ExpectedGroups -Record $record
        $missing = @($expected | Where-Object { $groups -notcontains $_ })
        if ($missing.Count -gt 0) { $offenders += $username }
    }
    return $offenders
}

try {
    Write-AuditLog -LogPath $LogPath -Message "Starting identity control validation"

    $controlChecks = [ordered]@{
        "CONTROL-001" = @{ Description = "Disabled users are not members of business groups";        Offenders = (Test-Control001-DisabledUsersNotInBusinessGroups) }
        "CONTROL-002" = @{ Description = "Contractors do not have GG-Server-Admins";                 Offenders = (Test-Control002-ContractorsNoServerAdmins) }
        "CONTROL-003" = @{ Description = "FinanceApp access only belongs to approved Finance Analyst identities"; Offenders = (Test-Control003-FinanceAppLimitedToApprovedAnalysts) }
        "CONTROL-004" = @{ Description = "Help Desk users do not have server admin rights";          Offenders = (Test-Control004-HelpDeskNoServerAdmin) }
        "CONTROL-005" = @{ Description = "Privileged access uses separate adm- style accounts";      Offenders = (Test-Control005-PrivilegedAccountsUseAdmPrefix) }
        "CONTROL-006" = @{ Description = "Disabled users are located in the Disabled Users OU";      Offenders = (Test-Control006-DisabledUsersInDisabledOU) }
        "CONTROL-007" = @{ Description = "Active employees have expected department groups";         Offenders = (Test-Control007-ActiveEmployeesHaveExpectedDeptGroups -CsvPath $CsvPath) }
    }

    $allPassed = $true
    $summary = foreach ($key in $controlChecks.Keys) {
        $control = $controlChecks[$key]
        if ($control.Offenders.Count -eq 0) {
            $result = "PASS"
        }
        else {
            $result = "FAIL"
            $allPassed = $false
        }

        Write-Host "$key`: $($control.Description)"
        Write-Host "  Result: $result"
        Write-Host ""
        Write-AuditLog -LogPath $LogPath -Message "$key ($($control.Description)): $result. Offenders: $(if ($control.Offenders.Count -gt 0) { $control.Offenders -join ', ' } else { 'none' })"

        [PSCustomObject]@{
            Control     = $key
            Description = $control.Description
            Result      = $result
            Offenders   = $control.Offenders
        }
    }

    $overall = if ($allPassed) { "PASS" } else { "FAIL" }
    Write-Host "IDENTITY CONTROLS: $overall ($($($summary | Where-Object {$_.Result -eq 'PASS'}).Count) / $($summary.Count))" -ForegroundColor $(if ($allPassed) { "Green" } else { "Red" })
    Write-AuditLog -LogPath $LogPath -Message "IDENTITY CONTROLS: $overall"

    $summary | Format-Table Control, Description, Result, @{Label="Offenders";Expression={ if ($_.Offenders.Count -gt 0) { $_.Offenders -join ', ' } else { '{}' } }}
}
catch {
    Write-AuditLog -LogPath $LogPath -Message "Test-IdentityControls failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
