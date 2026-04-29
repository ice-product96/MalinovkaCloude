param(
    [string]$Output = "..\firmware\SmartShev-firmware.bin"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command idf.py -ErrorAction SilentlyContinue)) {
    throw "ESP-IDF CLI idf.py not found. Open an ESP-IDF PowerShell or install ESP-IDF first."
}

if (-not (Test-Path "CMakeLists.txt")) {
    throw "CMakeLists.txt not found. This folder currently contains firmware modules only, not a complete ESP-IDF project."
}

idf.py build

$appBins = Get-ChildItem -Path "build" -Filter "*.bin" -File |
    Where-Object { $_.Name -notin @("bootloader.bin", "partition-table.bin") }

if ($appBins.Count -eq 0) {
    throw "Application .bin was not found in build folder."
}

$appBin = $appBins | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$outputPath = Resolve-Path -Path (Split-Path -Parent $Output) -ErrorAction SilentlyContinue
if (-not $outputPath) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output) | Out-Null
}

Copy-Item -Force -Path $appBin.FullName -Destination $Output
Write-Host "Firmware binary copied to $Output"
