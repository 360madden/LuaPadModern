# Restore the LuaPad directory saved by install-preview.ps1.
# Never runs while RIFT is open. Moves the preview aside; does not delete files.
[CmdletBinding()]
param([string]$BackupPath)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonsRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns'
$target = Join-Path $addonsRoot 'luapad'
$backupRoot = Join-Path $sourceRoot 'backups'
if (Get-Process -Name rift_x64,rift -ErrorAction SilentlyContinue) {
    throw 'RIFT is running. Exit normally before restoring the previous LuaPad.'
}
if (-not (Test-Path -LiteralPath $addonsRoot -PathType Container)) {
    throw "AddOns folder missing: $addonsRoot"
}
if (-not $BackupPath) {
    $candidates = @(Get-ChildItem -LiteralPath $backupRoot -Directory -Filter 'luapad-before-preview-*' -ErrorAction SilentlyContinue)
    if ($candidates.Count -ne 1) {
        throw "Found $($candidates.Count) original backups. Supply -BackupPath with the exact backup folder to restore."
    }
    $BackupPath = $candidates[0].FullName
}
$backupFull = [IO.Path]::GetFullPath($BackupPath)
$rootFull = [IO.Path]::GetFullPath($backupRoot).TrimEnd('\') + '\'
if (-not $backupFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'BackupPath must be inside this project backups folder.'
}
if (-not (Test-Path -LiteralPath (Join-Path $backupFull 'RiftAddon.toc') -PathType Leaf)) {
    throw 'Selected backup has no RiftAddon.toc; refusing to restore.'
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$previewArchive = Join-Path $backupRoot ("luapad-preview-removed-" + $stamp)
$previewMoved = $false
try {
    if (Test-Path -LiteralPath $target) {
        Move-Item -LiteralPath $target -Destination $previewArchive -ErrorAction Stop
        $previewMoved = $true
    }
    Move-Item -LiteralPath $backupFull -Destination $target -ErrorAction Stop
    Write-Host "Restored original LuaPad from $backupFull" -ForegroundColor Green
    if ($previewMoved) { Write-Host "Previous preview retained at $previewArchive" -ForegroundColor Cyan }
}
catch {
    if ($previewMoved -and -not (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $previewArchive)) {
        Move-Item -LiteralPath $previewArchive -Destination $target -ErrorAction SilentlyContinue
    }
    throw
}
