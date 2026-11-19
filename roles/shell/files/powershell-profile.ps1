#Requires -Version 5.1
# Make $PROFILE (PowerShell 7 and Windows PowerShell 5.1) load the shared profile
# from the dotfiles repo, and allow local profile scripts to run.
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$SharedProfile)
$ErrorActionPreference = 'Stop'
$changed = @()
$Ansible.Result = @{}
$line = '. "{0}"' -f $SharedProfile
# Documents may be redirected (e.g. OneDrive), so ask Windows where it is.
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($sub in 'PowerShell', 'WindowsPowerShell') {
    $file = Join-Path $docs "$sub\Microsoft.PowerShell_profile.ps1"
    $content = if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { '' }
    if ($content -and $content.Contains($line)) { continue }
    $changed += $file
    if (-not $Ansible.CheckMode) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
        Add-Content -LiteralPath $file -Encoding UTF8 -Value @(
            '# Added by bwhitehead.workstation: load the shared profile from the dotfiles repo'
            "if (Test-Path -LiteralPath `"$SharedProfile`") { $line }")
    }
}
# Windows PowerShell 5.1 defaults to Restricted on client editions, which blocks profiles.
if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Undefined', 'Restricted', 'AllSigned') {
    $changed += 'ExecutionPolicy(CurrentUser)=RemoteSigned'
    # A Group Policy at a more specific scope makes this throw even though it applies.
    if (-not $Ansible.CheckMode) { try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force } catch { $Ansible.Result.warning = "$_" } }
}
$Ansible.Changed = $changed.Count -gt 0
$Ansible.Result.changed_items = $changed
