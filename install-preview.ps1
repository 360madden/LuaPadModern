# LuaPad 2.0 preview installer. Deliberately stops if RIFT is running.
# Run in PowerShell 7 or Windows PowerShell after closing RIFT normally.
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonsRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns'
$target = Join-Path $addonsRoot 'luapad'
$backupRoot = Join-Path $sourceRoot 'backups'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupRoot ("luapad-before-preview-" + $stamp)
if (Get-Process -Name rift_x64,rift -ErrorAction SilentlyContinue) {
    throw 'RIFT is running. Close the game normally before installing this preview.'
}
$required = @('main.lua','RiftAddon.toc','close.png','small_fangs.png','Inspector','LibSimpleWidgets')
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $item))) {
        throw "Missing preview source item: $item"
    }
}
if (-not (Test-Path -LiteralPath $addonsRoot)) {
    throw "AddOns folder not found: $addonsRoot"
}
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$priorMoved = $false
try {
    if (Test-Path -LiteralPath $target) {
        Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
        $priorMoved = $true
    }
    New-Item -ItemType Directory -Path $target -ErrorAction Stop | Out-Null
    foreach ($item in $required) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $item) -Destination $target -Recurse -ErrorAction Stop
    }
    Write-Host "Installed LuaPad preview. Original addon backup: $backup" -ForegroundColor Green
    Write-Host 'Start RIFT normally and enter /lp. Keep your original SavedVariables unchanged.' -ForegroundColor Cyan
}
catch {
    if (Test-Path -LiteralPath $target) {
        $failed = Join-Path $backupRoot ("failed-preview-" + $stamp)
        Move-Item -LiteralPath $target -Destination $failed -ErrorAction SilentlyContinue
    }
    if ($priorMoved -and (Test-Path -LiteralPath $backup)) {
        Move-Item -LiteralPath $backup -Destination $target -ErrorAction SilentlyContinue
    }
    throw
}
