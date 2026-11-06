# LuaPadModern Preview 21 guarded two-file hot-copy.
# Dry-run by default. Use -Apply to back up the exact Preview 20 originals
# and copy Preview 21. This NEVER focuses, reloads or closes RIFT.
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = 'C:\Users\mrkoo\OneDrive\Documents\RIFT\Interface\AddOns\luapad'
$backupParent = Join-Path $repo 'backups'
$expected = [ordered]@{
    'main.lua' = @{
        Before = '34bf8d962c700862f655d5c60c58e5a76a01ca8c3c26eb4299e55a38ed5f6e59'
        After  = '3a94c7909e91913c79a1c89d41a5d6ec3098275a9f845d3afb9fde0323fb3e97'
    }
    'RiftAddon.toc' = @{
        Before = 'b3caba8124274cb744f693f727726edc5cbb3ff38733158eae511bed90a4d11b'
        After  = 'f136c3feaeea88264342eae8931b32adf0390e47f86007cc8b10fdcda84cc3dd'
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
        throw "Unexpected Preview 21 source hash ($name): $gotSource"
    }
    if ($gotInstalled -eq $expected[$name].After) {
        $alreadyUpdated++
    } elseif ($gotInstalled -ne $expected[$name].Before) {
        throw "Installed file changed from Preview 20 ($name): $gotInstalled. No changes made."
    }
    Write-Host "$name source=$gotSource installed=$gotInstalled"
}
if ($alreadyUpdated -eq $expected.Count) {
    Write-Host 'Preview 21 already installed; no files changed.' -ForegroundColor Green
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
$backup = Join-Path $backupParent ("luapad-preview21-before-hotcopy-" + $timestamp)
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
    Write-Host 'PREVIEW 21 HOT-COPY SUCCESS: both installed hashes match the repository.' -ForegroundColor Green
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
