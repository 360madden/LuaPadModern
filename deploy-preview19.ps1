# LuaPadModern Preview 19 guarded two-file hot-copy.
# Dry-run by default. Use -Apply to back up the exact Preview 18 originals
# and copy Preview 19. This NEVER focuses, reloads or closes RIFT.
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad'
$backupParent = Join-Path $repo 'backups'
$expected = [ordered]@{
    'main.lua' = @{
        Before = '37f2fbe4558e4deb06387ae78dc268d73e648d0558438f9703caac230ee4fd9d'
        After  = 'd28a5d84ba2e6b66f1926b0fd9868f2755a2d221ace4781582426d81ba9cd156'
    }
    'RiftAddon.toc' = @{
        Before = '0beb6c831fab4547e1f006ec6c31e49249e93481142b97445a6f105aaa34a70a'
        After  = 'a70d7ed30db3c008f4ad65bab00a4d87268bf6ddc0d9cf5f50c49ea1a3fe685b'
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
        throw "Unexpected Preview 19 source hash ($name): $gotSource"
    }
    if ($gotInstalled -eq $expected[$name].After) {
        $alreadyUpdated++
    } elseif ($gotInstalled -ne $expected[$name].Before) {
        throw "Installed file changed from Preview 18 ($name): $gotInstalled. No changes made."
    }
    Write-Host "$name source=$gotSource installed=$gotInstalled"
}
if ($alreadyUpdated -eq $expected.Count) {
    Write-Host 'Preview 19 already installed; no files changed.' -ForegroundColor Green
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
$backup = Join-Path $backupParent ("luapad-preview19-before-hotcopy-" + $timestamp)
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
    Write-Host 'PREVIEW 19 HOT-COPY SUCCESS: both installed hashes match the repository.' -ForegroundColor Green
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
