#Requires -Version 7
# Set Windows Terminal's default profile and font. Runs under pwsh (PowerShell 7)
# because settings.json may contain comments, which only PS7 can parse.
[CmdletBinding(SupportsShouldProcess)]
param([string]$DefaultProfile = '', [string]$FontFace = '')
$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false
$candidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json")
$file = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $file) {
    $Ansible.Result = @{ skipped = 'Windows Terminal settings.json not found. Open Windows Terminal once, then re-run.' }
    return
}

$s = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable
if (-not $s.profiles) { $s.profiles = [ordered]@{} }
if ($s.profiles -is [System.Collections.IList]) { $s.profiles = [ordered]@{ list = $s.profiles } }
if (-not $s.profiles.defaults) { $s.profiles.defaults = [ordered]@{} }
if (-not $s.profiles.defaults.font) { $s.profiles.defaults.font = [ordered]@{} }

$changes = @(); $notes = @()
if ($DefaultProfile -and $s.defaultProfile -ne $DefaultProfile) {
    # Only switch to a profile Windows Terminal knows about (it adds PowerShell 7 after first launch).
    if (@($s.profiles.list | Where-Object { $_.guid -eq $DefaultProfile }).Count -gt 0) {
        $s.defaultProfile = $DefaultProfile; $changes += 'defaultProfile'
    } else { $notes += "profile $DefaultProfile not in Windows Terminal yet; re-run after opening it once" }
}
if ($FontFace -and $s.profiles.defaults.font.face -ne $FontFace) {
    $s.profiles.defaults.font.face = $FontFace; $changes += 'font.face'
}
if ($changes) {
    $Ansible.Changed = $true
    if (-not $Ansible.CheckMode) {
        Copy-Item -LiteralPath $file -Destination "$file.bak" -Force
        $s | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $file -Encoding utf8
    }
}
$Ansible.Result = @{ file = $file; changed_settings = $changes; notes = $notes }
