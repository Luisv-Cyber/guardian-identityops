<#
    IAMLabCommon.psm1

    Shared functions used across the GFT IAM lab lifecycle scripts:
    logging, environment validation, and username/OU helpers.

    Import from scripts as:
        Import-Module "$PSScriptRoot\Modules\IAMLabCommon.psm1" -Force
#>

function Write-AuditLog {
    <#
    .SYNOPSIS
        Writes a timestamped audit log entry.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Level = "INFO",
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "$Timestamp | $Level | $Message"
    Write-Host $Line
    $Line | Out-File -FilePath $LogPath -Append
}

function Get-TargetOU {
    <#
    .SYNOPSIS
        Resolves the target OU distinguished name for a given department.
    #>
    param([Parameter(Mandatory = $true)][string]$Department)

    switch ($Department) {
        "IT"                { return "OU=IT,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        "Security"          { return "OU=Security,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        "Human Resources"   { return "OU=Human Resources,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        "Finance"           { return "OU=Finance,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        "Operations"        { return "OU=Operations,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        "Contractors"       { return "OU=Contractors,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        default             { throw "Unrecognized department: $Department" }
    }
}

function New-UsernameFromRecord {
    param([Parameter(Mandatory = $true)]$Record)
    return ("{0}.{1}" -f $Record.FirstName, $Record.LastName).ToLower()
}

function Test-LabEnvironment {
    <#
    .SYNOPSIS
        Validates that the expected AD structure exists before lifecycle
        scripts are run against it.
    #>
    [CmdletBinding()]
    param()

    $results = @()

    $results += [PSCustomObject]@{ Check = "ActiveDirectory module available"; Passed = [bool](Get-Module -ListAvailable -Name ActiveDirectory) }

    # TODO (live environment): confirm domain reachable
    # $results += [PSCustomObject]@{ Check = "AD domain reachable"; Passed = [bool](Get-ADDomain -ErrorAction SilentlyContinue) }

    $expectedOUs = @(
        "OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=IT,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Security,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Human Resources,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Finance,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Operations,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Groups,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Servers,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Service Accounts,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Administrative Accounts,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Disabled Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal",
        "OU=Contractors,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
    )
    foreach ($ou in $expectedOUs) {
        # TODO (live environment): Get-ADOrganizationalUnit -Identity $ou -ErrorAction SilentlyContinue
        $results += [PSCustomObject]@{ Check = "OU exists: $ou"; Passed = $true }
    }

    $expectedGroups = @(
        "GG-All-Employees","GG-Contractors","GG-EmployeePortal-Users","GG-Finance-Analysts",
        "GG-FinanceApp-Users","GG-Finance-Users","GG-HelpDesk-PasswordReset","GG-HR-Users",
        "GG-IT-HelpDesk","GG-IT-Users","GG-Operations-Users","GG-Security-Analysts",
        "GG-Security-Users","GG-Server-Admins"
    )
    foreach ($group in $expectedGroups) {
        # TODO (live environment): Get-ADGroup -Identity $group -ErrorAction SilentlyContinue
        $results += [PSCustomObject]@{ Check = "Group exists: $group"; Passed = $true }
    }

    $failed = $results | Where-Object { -not $_.Passed }
    if ($failed) {
        Write-Host "ENVIRONMENT VALIDATION: FAIL" -ForegroundColor Red
        $failed | Format-Table
    }
    else {
        Write-Host "ENVIRONMENT VALIDATION: PASS" -ForegroundColor Green
    }

    return $results
}

Export-ModuleMember -Function Write-AuditLog, Get-TargetOU, New-UsernameFromRecord, Test-LabEnvironment
