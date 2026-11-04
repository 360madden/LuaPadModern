# LuaPadModern Preview 18 guarded two-file hot-copy.
# Dry-run by default. Use -Apply to back up the exact Preview 17 originals
# and copy Preview 18. This NEVER focuses, reloads or closes RIFT.
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad'
$backupParent = Join-Path $repo 'backups'
$expected = [ordered]@{
    'main.lua' = @{
        Before = 'd4af7af2938901812c80e4ba57bc870d46f06e0f6e0f8397d922828b962098be'
        After  = '37f2fbe4558e4deb06387ae78dc268d73e648d0558438f9703caac230ee4fd9d'
    }
    'RiftAddon.toc' = @{
        Before = '3a7f739103f7ac9837427285573313312be4931c960fb42dde5c929c9c53b562'
        After  = '0beb6c831fab4547e1f006ec6c31e49249e93481142b97445a6f105aaa34a70a'
    }
}
function Get-ExactHash([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "File missing: $path"
    }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

$alreadyUpdated = 0
foreach ($name in @($expected.Keys)) {
    $source = Join-Path $repo $name
    $target = Join-Path $addonRoot $name
    $gotSource = Get-ExactHash $source
    $gotInstalled = Get-ExactHash $target
    if ($gotSource -ne $expected[$name].After) {
        throw "Unexpected Preview 18 source hash ($name): $gotSource"
    }
    if ($gotInstalled -eq $expected[$name].After) {
        $alreadyUpdated++
    } elseif ($gotInstalled -ne $expected[$name].Before) {
        throw "Installed file changed from Preview 17 ($name): $gotInstalled. No changes made."
    }
    Write-Host "$name source=$gotSource installed=$gotInstalled"
}
if ($alreadyUpdated -eq $expected.Count) {
    Write-Host 'Preview 18 already installed; no files changed.' -ForegroundColor Green
    return
}
if ($alreadyUpdated -ne 0) {
    throw 'Installed files are a mixture of versions; manual recovery is required. No changes made.'
}
if (-not $Apply) {
    Write-Host 'DRY RUN PASS. Use -Apply for a guarded, backed-up two-file copy.' -ForegroundColor Cyan
    return
}
if (-not (Test-Path -LiteralPath $backupParent -PathType Container)) {
    throw "Backup parent missing: $backupParent"
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupParent ("luapad-preview18-before-hotcopy-" + $timestamp)
if (Test-Path -LiteralPath $backup) {
    throw "Backup already exists: $backup"
}
New-Item -ItemType Directory -Path $backup -ErrorAction Stop | Out-Null
$changed = @()
try {
    foreach ($name in @($expected.Keys)) {
        $original = Join-Path $addonRoot $name
        $copy = Join-Path $backup $name
        if ((Get-ExactHash $original) -ne $expected[$name].Before) {
            throw "Installed file changed during backup preflight: $name"
        }
        Copy-Item -LiteralPath $original -Destination $copy -ErrorAction Stop
        if ((Get-ExactHash $copy) -ne $expected[$name].Before) {
            throw "Backup hash mismatch: $name"
        }
    }
    # Recheck all originals after both backups and before any copy.
    foreach ($name in @($expected.Keys)) {
        if ((Get-ExactHash (Join-Path $addonRoot $name)) -ne $expected[$name].Before) {
            throw "Installed file changed during copy preflight: $name"
        }
    }
    foreach ($name in @($expected.Keys)) {
        $destination = Join-Path $addonRoot $name
        Copy-Item -LiteralPath (Join-Path $repo $name) -Destination $destination -Force -ErrorAction Stop
        $changed += $name
        if ((Get-ExactHash $destination) -ne $expected[$name].After) {
            throw "Post-copy hash mismatch: $name"
        }
    }
    Write-Host 'PREVIEW 18 HOT-COPY SUCCESS: both installed hashes match the repository.' -ForegroundColor Green
    Write-Host "Rollback backup: $backup" -ForegroundColor Cyan
    Write-Host 'RIFT was not focused, reloaded or restarted. Updated Lua loads on next authorized /reloadui or normal launch.' -ForegroundColor Cyan
} catch {
    Write-Warning ("Copy failure: " + $_.Exception.Message)
    foreach ($name in $changed) {
        $destination = Join-Path $addonRoot $name
        try {
            # Only reverse files that still match the bytes this command wrote.
            if ((Get-ExactHash $destination) -eq $expected[$name].After) {
                Copy-Item -LiteralPath (Join-Path $backup $name) -Destination $destination -Force -ErrorAction Stop
                Write-Warning "Restored $name from backup"
            } else {
                Write-Warning "Preserved unexpected state for manual recovery: $name"
            }
        } catch {
            Write-Warning "Automatic recovery failed for $name. Backup preserved at $backup"
        }
    }
    throw
}
