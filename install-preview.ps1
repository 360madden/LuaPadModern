# LuaPad 2.0 preview installer. Deliberately stops if RIFT is running.
# Run in PowerShell 7 or Windows PowerShell after closing RIFT normally.
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonsRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns'
$target = Join-Path $addonsRoot 'luapad'
$backupRoot = Join-Path $sourceRoot 'backups'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupRoot ("luapad-before-preview-" + $stamp)
$savedBackup = Join-Path $backupRoot ("LuaPad-SavedVariables-" + $stamp)
$savedRoot = Join-Path (Split-Path $addonsRoot -Parent) 'Saved'
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
if ((Test-Path -LiteralPath $backup) -or (Test-Path -LiteralPath $savedBackup)) {
    throw 'Backup timestamp collision. Wait a moment, then retry so no existing backup is overwritten.'
}
$priorMoved = $false
$previewCreated = $false
try {
    # Preserve per-account LuaPad SavedVariables before touching the installed addon.
    # If any backup copy fails, stop while the original addon still occupies $target.
    $savedCount = 0
    if (Test-Path -LiteralPath $savedRoot -PathType Container) {
        foreach ($account in @(Get-ChildItem -LiteralPath $savedRoot -Directory)) {
            $savedFile = Join-Path (Join-Path $account.FullName 'SavedVariables') 'LuaPad.lua'
            if (Test-Path -LiteralPath $savedFile -PathType Leaf) {
                $accountBackup = Join-Path $savedBackup $account.Name
                New-Item -ItemType Directory -Path $accountBackup -Force -ErrorAction Stop | Out-Null
                Copy-Item -LiteralPath $savedFile -Destination (Join-Path $accountBackup 'LuaPad.lua') -ErrorAction Stop
                $savedCount++
            }
        }
    }
    if (Test-Path -LiteralPath $target) {
        Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
        $priorMoved = $true
    }
    New-Item -ItemType Directory -Path $target -ErrorAction Stop | Out-Null
    $previewCreated = $true
    foreach ($item in $required) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $item) -Destination $target -Recurse -ErrorAction Stop
    }
    Write-Host "Installed LuaPad preview. Original addon backup: $backup" -ForegroundColor Green
    Write-Host "SavedVariables copied for $savedCount account(s) to $savedBackup" -ForegroundColor Cyan
    Write-Host 'Start RIFT normally; LuaPad Preview 18 should open automatically. Use /lp to reopen or bring it forward.' -ForegroundColor Cyan
}
catch {
    if ($previewCreated -and (Test-Path -LiteralPath $target)) {
        $failed = Join-Path $backupRoot ("failed-preview-" + $stamp)
        Move-Item -LiteralPath $target -Destination $failed -ErrorAction SilentlyContinue
    }
    if ($priorMoved -and (Test-Path -LiteralPath $backup)) {
        Move-Item -LiteralPath $backup -Destination $target -ErrorAction SilentlyContinue
    }
    throw
}
