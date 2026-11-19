#Requires -Version 5.1
# Stow-like linker for Windows: for every file in each package folder, create a
# symbolic link at the same relative path under $Target. Existing real files are
# moved to $BackupDir first; links pointing elsewhere are replaced.
# Needs admin rights or Developer Mode (for symlinks).
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string[]]$Packages,
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$BackupDir
)
$ErrorActionPreference = 'Stop'
$linked = @(); $backedUp = @(); $missing = @()

foreach ($pkg in $Packages) {
    $root = Join-Path $Source $pkg
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { $missing += $pkg; continue }
    $rootFull = (Get-Item -LiteralPath $root).FullName.TrimEnd('\')
    foreach ($file in Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force) {
        $rel = $file.FullName.Substring($rootFull.Length + 1)
        $dest = Join-Path $Target $rel
        $item = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -eq 'SymbolicLink') {
            if ([string](@($item.Target)[0]) -eq $file.FullName) { continue }   # already correct
            if (-not $Ansible.CheckMode) { $item.Delete() }
        } elseif ($item) {
            $backedUp += $rel
            if (-not $Ansible.CheckMode) {
                $bak = Join-Path $BackupDir $rel
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bak) | Out-Null
                Move-Item -LiteralPath $dest -Destination $bak
            }
        }
        $linked += $rel
        if (-not $Ansible.CheckMode) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            New-Item -ItemType SymbolicLink -Path $dest -Target $file.FullName | Out-Null
        }
    }
}

$Ansible.Changed = $linked.Count -gt 0
$Ansible.Result = @{ linked = $linked; backed_up = $backedUp; missing_packages = $missing }
if ($backedUp.Count -gt 0) { $Ansible.Result.backup_dir = $BackupDir }
