
# Powershell Profile file
# PS C:\Users\XXX> echo $PROFILE
# C:\Users\XXX\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# PS C:\Users\XXX>

# Use VcXserv on Windows
$env:DISPLAY="127.0.0.1:0.0"

<#
.SYNOPSIS
    Copies a local SSH public key to a remote host's authorized_keys file.

.DESCRIPTION
    This function mimics the behavior of the Linux 'ssh-copy-id' utility.
    It connects to a remote host via SSH, backs up the existing authorized_keys file,
    checks for duplicate keys, and appends the public key only if it's not already present.
    It also ensures correct permissions are set on the remote .ssh directory and authorized_keys file.

.PARAMETER Target
    The remote SSH target in the format USERNAME@IPv4 (e.g., hammad@192.168.1.42).
    This is a mandatory positional parameter.

.PARAMETER KeyType
    Optional. The filename of the public key to use (e.g., id_rsa.pub, id_ed25519.pub).
    Defaults to 'id_rsa.pub' if not specified.

.EXAMPLE
    ssh-copy-id hammad@192.168.1.42
    Copies the default id_rsa.pub key to the remote host.

.EXAMPLE
    ssh-copy-id alice@192.168.0.101 -KeyType "id_ed25519.pub"
    Copies the id_ed25519.pub key to the remote host.

.NOTES
    - Requires SSH access to the remote host.
    - Public key must exist in the user's .ssh directory.
    - Remote host must support bash-compatible shell commands.
#>
function ssh-copy-id {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [string]$KeyType = "id_rsa.pub"  # Default key type
    )

    # Validate format
    if ($Target -notmatch '^[a-zA-Z0-9._-]+@(?:\d{1,3}\.){3}\d{1,3}$') {
        Write-Host "❌ Invalid format. Use: USERNAME@X.X.X.X" -ForegroundColor Red
        return
    }

    $keyPath = "$env:USERPROFILE\.ssh\$KeyType"
    if (-not (Test-Path $keyPath)) {
        Write-Host "🔑 Public key not found at $keyPath" -ForegroundColor Yellow
        Write-Host "Available keys:" -ForegroundColor Cyan
        Get-ChildItem "$env:USERPROFILE\.ssh\" -Filter "*.pub" | ForEach-Object { Write-Host " - $_.Name" }
        return
    }

    # Read and sanitize key
    $key = Get-Content $keyPath -Raw
    $key = $key -replace "`r", ""  # Remove carriage returns

    Write-Host "📡 Connecting to $Target to install your public key..." -ForegroundColor Cyan

    try {
        # Remote shell script to check for duplicates and append if needed
        $key = Get-Content $keyPath -Raw
        $key = $key -replace "`r", "" -replace "`n", ""  # Remove CR and LF

        # Escape single quotes for Bash
$replacement = @'
'"'"'
'@ -replace "`r", ""

$keyEscaped = $key -replace "'", $replacement

$remoteCmd = @"
mkdir -p ~/.ssh

if [ -f ~/.ssh/authorized_keys ]; then
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak
fi

grep -qxF '$keyEscaped' ~/.ssh/authorized_keys 2>/dev/null
if [ `$? -ne 0 ]; then
    echo '$keyEscaped' >> ~/.ssh/authorized_keys
    echo '✅ Key added.'
else
    echo '🔁 Key already exists. Skipping.'
fi

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
"@ -replace "`r", ""

        # Debug
        # Write-Host "`n--- Remote Command ---`n$remoteCmd`n---------------------`n"

        ssh $Target $remoteCmd

        Write-Host "🎯 Operation complete." -ForegroundColor Green
    }
    catch {
        Write-Host "🚫 SSH connection failed or command error." -ForegroundColor Red
    }
}
