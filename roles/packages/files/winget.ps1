#Requires -Version 5.1
# Install (and optionally upgrade) winget packages by exact ID.
# Calls winget.exe by its full path: the PowerShell module (Microsoft.WinGet.Client)
# talks to winget over COM, which fails in SSH/remote sessions (0x800706BA), and the
# `winget` app alias isn't on PATH there either. The module is only used to repair
# a missing winget.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string[]]$Ids,
    [bool]$Upgrade = $false
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Ansible.Changed = $false
$result = @{ installed = @(); upgraded = @(); failed = @{}; reboot_required = $false }

# winget exit codes (signed 32-bit, as $LASTEXITCODE reports them)
$ALREADY_INSTALLED = [int]0x8A150061
$NO_UPDATE         = [int]0x8A15002B
$REBOOT_CODES      = @([int]0x8A150109, [int]0x8A15010A, 3010)

function Find-Winget {
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $found = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "Microsoft.DesktopAppInstaller_*_${arch}__8wekyb3d8bbwe" -Directory -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -split '_')[1] } -Descending |
        ForEach-Object { Join-Path $_.FullName 'winget.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $found) { $found = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source }
    $found
}

$winget = Find-Winget
if (-not $winget) {
    if ($Ansible.CheckMode) { throw 'winget is not installed' }
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
    Import-Module Microsoft.WinGet.Client
    Repair-WinGetPackageManager -Latest -Force -AllUsers | Out-Null
    $Ansible.Changed = $true
    $winget = Find-Winget
    if (-not $winget) { throw 'winget could not be installed' }
}
$result.winget = $winget
$common = @('--exact', '--accept-source-agreements', '--disable-interactivity')

function Invoke-Winget([string[]]$Arguments) {
    # PS 5.1 turns native stderr into errors; with 'Stop' that would abort the script.
    $ErrorActionPreference = 'Continue'
    $out = & $winget @Arguments 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out.Trim() }
}

foreach ($id in $Ids) {
    $listed = Invoke-Winget (@('list', '--id', $id) + $common)
    $isInstalled = $listed.Code -eq 0
    if (-not $isInstalled) {
        if ($Ansible.CheckMode) { $result.installed += $id; continue }
        $r = Invoke-Winget (@('install', '--id', $id, '--source', 'winget', '--silent', '--accept-package-agreements') + $common)
        if ($r.Code -eq $ALREADY_INSTALLED) { continue }
        $result.installed += $id
    } elseif ($Upgrade) {
        if ($Ansible.CheckMode) { continue }   # can't tell cheaply whether an update exists
        $r = Invoke-Winget (@('upgrade', '--id', $id, '--source', 'winget', '--silent', '--accept-package-agreements') + $common)
        if ($r.Code -eq $NO_UPDATE) { continue }
        $result.upgraded += $id
    } else { continue }

    if ($REBOOT_CODES -contains $r.Code) { $result.reboot_required = $true }
    elseif ($r.Code -ne 0) {
        $tail = ($r.Output -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' | '
        $result.failed[$id] = 'exit 0x{0:X8}: {1}' -f $r.Code, $tail
    }
}

$Ansible.Changed = $Ansible.Changed -or ($result.installed.Count + $result.upgraded.Count) -gt 0
$Ansible.Result = $result
if ($result.failed.Count -gt 0) {
    $Ansible.Failed = $true
    $Ansible.Result.msg = 'winget failed for: ' + (($result.failed.Keys | Sort-Object) -join ', ')
}
