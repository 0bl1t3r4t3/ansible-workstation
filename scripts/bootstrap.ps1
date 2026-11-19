#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Prepare a Windows PC to be configured by the workstation playbook running in WSL.

.DESCRIPTION
  1. Installs and starts the OpenSSH Server, with PowerShell as its shell and key-only logins.
     Windows 11 (22H2+): sshd listens on localhost only and WSL uses mirrored networking.
     Windows 10: sshd only accepts connections from the WSL network (172.16.0.0/12).
  2. Creates an SSH key for Ansible and authorizes it for this (administrator) account.
  3. Installs WSL with a Linux distribution (a reboot may be needed).
  Then, inside WSL, run scripts/bootstrap-wsl.sh.

.EXAMPLE
  # In an elevated PowerShell:
  irm https://raw.githubusercontent.com/0bl1t3r4t3/ansible-workstation/main/scripts/bootstrap.ps1 -OutFile bootstrap.ps1
  powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
#>
[CmdletBinding()]
param(
    [string]$Distribution = 'Ubuntu',
    [switch]$SkipWsl,        # e.g. WSL already set up, or CI
    [switch]$AllowRemote     # also accept SSH from the local network (to run Ansible from another machine)
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

$build = [Environment]::OSVersion.Version.Build
$mirrored = $build -ge 22621   # Windows 11 22H2: WSL mirrored networking

# --- 1. OpenSSH Server -------------------------------------------------------
Step 'OpenSSH Server'
$cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -First 1
if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd   # first start generates host keys and sshd_config

New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force `
    -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null

$config = "$env:ProgramData\ssh\sshd_config"
$text = Get-Content -LiteralPath $config -Raw
$settings = [ordered]@{ PasswordAuthentication = 'no'; PubkeyAuthentication = 'yes' }
if ($mirrored -and -not $AllowRemote) { $settings.ListenAddress = '127.0.0.1' }
foreach ($key in $settings.Keys) {
    $line = "$key $($settings[$key])"
    if ($text -match "(?m)^\s*#?\s*$key\s+.*$") { $text = $text -replace "(?m)^\s*#?\s*$key\s+.*$", $line }
    else { $text = "$line`r`n$text" }
}
Set-Content -LiteralPath $config -Value $text -Encoding ascii
Restart-Service sshd

$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $rule) {
    $rule = New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
if (-not $mirrored -and -not $AllowRemote) {
    # Windows 10: WSL reaches Windows through a NAT network in 172.16.0.0/12.
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -RemoteAddress '172.16.0.0/12'
}

# --- 2. SSH key for Ansible --------------------------------------------------
Step 'SSH key for Ansible'
$sshDir = Join-Path $env:USERPROFILE '.ssh'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$key = Join-Path $sshDir 'ansible_workstation_ed25519'
if (-not (Test-Path -LiteralPath $key)) {
    # One argument string so the empty passphrase survives on PowerShell 5.1 and 7.
    Start-Process -FilePath ssh-keygen.exe -Wait -NoNewWindow `
        -ArgumentList "-q -t ed25519 -N `"`" -C ansible-workstation@$env:COMPUTERNAME -f `"$key`""
}
$pub = (Get-Content -LiteralPath "$key.pub" -Raw).Trim()
# Administrators' keys must live here, with only SYSTEM and Administrators allowed.
$auth = "$env:ProgramData\ssh\administrators_authorized_keys"
$existing = if (Test-Path -LiteralPath $auth) { Get-Content -LiteralPath $auth } else { @() }
if ($existing -notcontains $pub) { Add-Content -LiteralPath $auth -Value $pub -Encoding ascii }
icacls.exe $auth /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null

# --- 3. WSL -------------------------------------------------------------------
if (-not $SkipWsl) {
    Step "WSL ($Distribution)"
    if ($mirrored) {
        $wslconfig = Join-Path $env:USERPROFILE '.wslconfig'
        if (-not (Test-Path -LiteralPath $wslconfig)) {
            Set-Content -LiteralPath $wslconfig -Encoding ascii -Value @(
                '# Managed by bwhitehead.workstation (wsl role). Apply with: wsl --shutdown'
                '[wsl2]'
                'networkingMode=mirrored')
        }
    }
    $env:WSL_UTF8 = '1'
    $installed = @(& wsl.exe --list --quiet 2>$null) | ForEach-Object { $_.Trim() }
    if ($LASTEXITCODE -ne 0 -or $installed -notcontains $Distribution) {
        & wsl.exe --install --distribution $Distribution --no-launch
    }
}

Write-Host ''
Write-Host 'Next:' -ForegroundColor Green
if (-not $SkipWsl) {
    Write-Host "  1. Reboot if WSL was just installed, then open '$Distribution' from the Start menu and create your Linux user."
}
Write-Host '  2. In WSL run:'
Write-Host '       curl -fsSL https://raw.githubusercontent.com/0bl1t3r4t3/ansible-workstation/main/scripts/bootstrap-wsl.sh | bash'
