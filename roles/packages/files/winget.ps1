#Requires -Version 5.1
# Install (and optionally upgrade) winget packages by exact ID.
# Uses the Microsoft.WinGet.Client module, which works in non-interactive
# sessions (SSH) where the winget CLI can be unreliable.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string[]]$Ids,
    [bool]$Upgrade = $false
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Ansible.Changed = $false
$result = @{ installed = @(); upgraded = @(); failed = @{}; reboot_required = $false }

if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
    if ($Ansible.CheckMode) {
        $result.installed = $Ids
        $result.note = 'Microsoft.WinGet.Client is not installed yet; assuming every package is missing'
        $Ansible.Changed = $true
        $Ansible.Result = $result
        return
    }
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
    $Ansible.Changed = $true
}
Import-Module Microsoft.WinGet.Client

# Bootstrap or repair winget itself (missing on Windows Server and some fresh installs)
try { $null = Get-WinGetVersion } catch {
    if ($Ansible.CheckMode) { throw "winget is not working: $_" }
    Repair-WinGetPackageManager -Latest -Force | Out-Null
    $Ansible.Changed = $true
}

$installedById = @{}   # case-insensitive
foreach ($p in Get-WinGetPackage) { if ($p.Id) { $installedById[$p.Id] = $p } }

foreach ($id in $Ids) {
    $current = $installedById[$id]
    if (-not $current) {
        $result.installed += $id
        if ($Ansible.CheckMode) { continue }
        $r = Install-WinGetPackage -Id $id -MatchOption Equals -Source winget -Mode Silent
    } elseif ($Upgrade -and $current.IsUpdateAvailable) {
        $result.upgraded += $id
        if ($Ansible.CheckMode) { continue }
        $r = Update-WinGetPackage -Id $id -MatchOption Equals -Source winget -Mode Silent
    } else { continue }

    if ($r.Status -ne 'Ok') {
        $result.failed[$id] = '{0} (installer exit {1}) {2}' -f $r.Status, $r.InstallerErrorCode, $r.ExtendedErrorCode
    }
    if ($r.RebootRequired) { $result.reboot_required = $true }
}

$Ansible.Changed = $Ansible.Changed -or ($result.installed.Count + $result.upgraded.Count) -gt 0
$Ansible.Result = $result
if ($result.failed.Count -gt 0) {
    $Ansible.Failed = $true
    $Ansible.Result.msg = 'winget failed for: ' + (($result.failed.Keys | Sort-Object) -join ', ')
}
