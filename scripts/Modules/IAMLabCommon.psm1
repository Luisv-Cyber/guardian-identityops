<#
    IAMLabCommon.psm1

    Shared functions used across the GFT IAM lab lifecycle scripts:
    logging, environment validation, username/OU helpers, and the single
    shared expected-access (role-to-group) mapping used by Invoke-Joiner,
    Invoke-Mover, Get-AccessAudit, and Test-IdentityControls.

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
        "Disabled Users"    { return "OU=Disabled Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal" }
        default             { throw "Unrecognized department: $Department" }
    }
}

function New-UsernameFromRecord {
    param([Parameter(Mandatory = $true)]$Record)
    return ("{0}.{1}" -f $Record.FirstName, $Record.LastName).ToLower()
}

function Get-ExpectedGroups {
    <#
    .SYNOPSIS
        Single source of truth for role-based expected group membership.

    .DESCRIPTION
        Extracted from the role-mapping logic originally embedded only in
        Invoke-Joiner.ps1 (as Get-RoleGroups). Pulled into the shared
        module so Invoke-Joiner, Invoke-Mover, Get-AccessAudit, and
        Test-IdentityControls all evaluate access the same way instead of
        each carrying its own copy that could silently drift apart.

        Does NOT include the "Domain Users" baseline - callers that need
        it (e.g. Get-AccessAudit) add it themselves, since not every
        caller wants it (e.g. Invoke-Joiner adds it via AD's own default
        behavior, not this list).

        GG-Server-Admins is intentionally never returned by this function.
        Privileged access is a separate, deliberate action - see
        docs/architecture.md (Security Decisions) and the Privileged
        Access Assignment runbook concept referenced there.
    #>
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

    switch -Wildcard ($Record.Title) {
        "*Help Desk*"        { $groups += @("GG-IT-HelpDesk", "GG-HelpDesk-PasswordReset") }
        "*Security Analyst*" { $groups += "GG-Security-Analysts" }
        "*Finance Analyst*"  { $groups += @("GG-Finance-Analysts", "GG-FinanceApp-Users") }
    }

    return $groups | Select-Object -Unique
}

function Write-CheckLine {
    <#
    .SYNOPSIS
        Prints one environment-validation check in the dot-leader format
        evidenced in screenshots/30-environment-validation-pass.png (a
        single line per check, e.g. "Domain OU.......PASS", printed for
        every check regardless of pass/fail - not only on failure).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][bool]$Passed
    )
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $dotCount = [Math]::Max(3, 40 - $Label.Length)
    $dots = "." * $dotCount
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "$Label$dots$status" -ForegroundColor $color
}

function Test-LabEnvironment {
    <#
    .SYNOPSIS
        Validates that the expected AD structure exists before lifecycle
        scripts are run against it.

    .DESCRIPTION
        RECONSTRUCTED: earlier committed versions of this function
        hardcoded every check to Passed = $true without querying AD.
        This version performs the actual queries. Reproduces the
        per-check dot-leader output format shown in
        screenshots/30-environment-validation-pass.png, printed for
        every check (not only failures), and returns an overall boolean
        so a bare call at the prompt prints True/False the same way the
        evidenced runs did.
    #>
    [CmdletBinding()]
    param()

    $allPassed = $true

    $adModuleOk = [bool](Get-Module -ListAvailable -Name ActiveDirectory)
    Write-CheckLine -Label "ActiveDirectory module" -Passed $adModuleOk
    if (-not $adModuleOk) { $allPassed = $false }

    $domainOk = $false
    try { $domainOk = [bool](Get-ADDomain -ErrorAction Stop) } catch { $domainOk = $false }
    Write-CheckLine -Label "Domain" -Passed $domainOk
    if (-not $domainOk) { $allPassed = $false }

    $expectedOUs = [ordered]@{
        "GFT OU"                     = "OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Users OU"                   = "OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "IT OU"                      = "OU=IT,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Security OU"                = "OU=Security,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Human Resources OU"         = "OU=Human Resources,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Finance OU"                 = "OU=Finance,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Operations OU"              = "OU=Operations,OU=Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Groups OU"                  = "OU=Groups,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Servers OU"                 = "OU=Servers,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Service Accounts OU"        = "OU=Service Accounts,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Administrative Accounts OU" = "OU=Administrative Accounts,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Disabled Users OU"          = "OU=Disabled Users,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
        "Contractors OU"             = "OU=Contractors,OU=GFT,DC=corp,DC=guardianlab,DC=internal"
    }
    foreach ($label in $expectedOUs.Keys) {
        $exists = $false
        try { $exists = [bool](Get-ADOrganizationalUnit -Identity $expectedOUs[$label] -ErrorAction Stop) } catch { $exists = $false }
        Write-CheckLine -Label $label -Passed $exists
        if (-not $exists) { $allPassed = $false }
    }

    $expectedGroups = @(
        "GG-All-Employees","GG-EmployeePortal-Users","GG-IT-Users","GG-IT-HelpDesk",
        "GG-HelpDesk-PasswordReset","GG-Security-Users","GG-Security-Analysts","GG-HR-Users",
        "GG-Finance-Users","GG-Finance-Analysts","GG-FinanceApp-Users","GG-Operations-Users",
        "GG-Contractors","GG-Server-Admins"
    )
    foreach ($group in $expectedGroups) {
        $exists = $false
        try { $exists = [bool](Get-ADGroup -Identity $group -ErrorAction Stop) } catch { $exists = $false }
        Write-CheckLine -Label $group -Passed $exists
        if (-not $exists) { $allPassed = $false }
    }

    Write-Host ""
    if ($allPassed) {
        Write-Host "ENVIRONMENT VALIDATION: PASS" -ForegroundColor Green
    }
    else {
        Write-Host "ENVIRONMENT VALIDATION: FAIL" -ForegroundColor Red
    }

    return $allPassed
}

Export-ModuleMember -Function Write-AuditLog, Get-TargetOU, New-UsernameFromRecord, Get-ExpectedGroups, Write-CheckLine, Test-LabEnvironment
