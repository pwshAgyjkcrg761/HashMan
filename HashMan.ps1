# ==============================================================================
# SCRIPT: HashMan.ps1
# VERSION: 2026.06.25__15.33.12
# TARGET: PowerShell 7.6.3 LTS
#
# Copyright (C) 2026 pwshAgyjkcrg761
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# ==============================================================================
# <PROTECTED>
# ==============================================================================
# AI INSTRUCTIONS v2026.06.24__06.54.45 : 
#
# 1. MESSAGE STAMP: 
#    - Every response containing code MUST begin with a standalone version stamp.
#    - Use CHICAGO TIME (Central Time), 24-hour clock.
#    - Format: YYYY.MM.DD__HH.MM.SS.
#    - CRITICAL: Use the time provided in the prompt or at https://www.timeanddate.com/worldclock/usa/chicago. Ensure minutes are exact.
#
# 2. VERSION SNIPPET PROHIBITION:
#    - DO NOT provide code snippets, anchors, or steps to update the script's internal VERSION comment or $scriptVersion variable. 
#    - The user handles internal file versioning manually based on the Message Stamp.
#
# 3. SCRIPT OUTPUT (SURGICAL FIXES ONLY):
#    - Provide minimal, highly targeted, surgical edits. Do not rewrite large blocks or entire functions.
#    - Always use a codebox with a copy button.
#    - Multiple modifications MUST be presented strictly ONE step at a time. Wait for user confirmation before proceeding to the next step. 
#    - DO NOT modify or refactor any code inside <PROTECTED> tags.
#
# 4. VERBATIM ANCHOR PROTOCOL (FOR NOTEPAD++):
#    - To facilitate "Find" in Notepad++, always structure edits with:
#      - "Verbatim Anchor (Before)" - The exact lines of existing code immediately before the change.
#      - "Verbatim Anchor (After)" - The exact lines of existing code immediately after the change.
#      - "Snippet to REPLACE" - The exact code block to be deleted.
#      - "What to PASTE in its place" - The new code block to be inserted.
#    - Do not summarize, truncate, or refactor the existing code used as an anchor.
#    - Match spaces, comments, and symbols exactly as they appear in the file.
#
# 5. CONTENT PRESERVATION:
#    - Do not remove, modify, or strip out telemetry data or DevDebug information from any provided code.
# ==============================================================================
# </PROTECTED>

param(
    # Global Debugging Param
    [alias("Dev", "DevD", "DBG", "DDBG")]
    [switch]$DevDebug,
    
    [alias("h", "help")]
    [switch]$Manual
)

# --- GLOBAL VERSION DEFINITION ---
$scriptVersion = "2026.06.25__15.33.12"

# -------------------------------------------------------------------------
# DEPENDENCIES & ENFORCEMENT
# -------------------------------------------------------------------------
if ($PSVersionTable.PSVersion -lt [version]"7.6.0") {
    Write-Host "ERROR: Running on version $($PSVersionTable.PSVersion). This script requires at least 7.6.0." -ForegroundColor DarkRed
    Read-Host "Press Enter to exit"; exit
}

try { Add-Type -AssemblyName System.Windows.Forms } catch { }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ClearLine = [char]27 + "[K" 
$HomeCursor = [char]27 + "[H"
function Get-DependencyPaths {
    return @{ corz = "C:\Program Files\corz\checksum\checksum.exe" }
}
# -------------------------------------------------------------------------
# CONFIGURATION & STATE FILES
# -------------------------------------------------------------------------
$settingsFile = Join-Path $PSScriptRoot "HashMan_root.txt"
$internalDir = Join-Path $PSScriptRoot "HashMan_internal"
if (-not (Test-Path $internalDir)) { [void](New-Item -ItemType Directory -Path $internalDir -Force) }
$cacheFileTree = Join-Path $internalDir "HashMan_cache.json"
$sessionFile = Join-Path $internalDir "HashMan_session.json"

function Normalize-Path {
    param([string]$p)
    if ([string]::IsNullOrWhiteSpace($p)) { return "" }
    return $p.Replace('/', '\').Trim().Trim('"').TrimEnd('\')
}

if (Test-Path $settingsFile) {
    $collectionRoot = Normalize-Path (Get-Content $settingsFile -Raw)
} else {
    $collectionRoot = "" 
}

# --- DEPENDENCY CHECK ---
$tools = Get-DependencyPaths
$corzPath = $tools.corz
$flags = "v2sqi"

$missingTools = New-Object System.Collections.Generic.List[string]
if ([string]::IsNullOrWhiteSpace($corzPath) -or -not (Test-Path -LiteralPath $corzPath)) { 
    [void]$missingTools.Add("checksum.exe (corz checksum)") 
}

if ($missingTools.Count -gt 0) {
    Write-Host "`n [!] ERROR: The following dependencies are missing:" -ForegroundColor DarkRed
    $missingTools | ForEach-Object { Write-Host "     -> $_" -ForegroundColor DarkYellow }
    
    Write-Host "`n [TIP] If you recently installed corz checksum or modified your System PATH," -ForegroundColor Cyan
    Write-Host "       please reboot your computer to ensure the changes are applied." -ForegroundColor Cyan
    Write-Host "`n Please install corz checksum to proceed." -ForegroundColor Gray
    Read-Host "Press Enter to exit"; exit
}

if ($DevDebug) {
    Write-Host "`n [DevDebug-Main] Tool Discovery:" -ForegroundColor DarkYellow
    Write-Host "  -> corz:        $corzPath`n" -ForegroundColor Gray
    Start-Sleep -Seconds 2
} 

# -------------------------------------------------------------------------
# GLOBAL STATE
# -------------------------------------------------------------------------
$GlobalVerifyQueue = New-Object "System.Collections.Generic.Dictionary[string,PSCustomObject]"
$GlobalDeleteQueue = New-Object "System.Collections.Generic.Dictionary[string,PSCustomObject]"
$ExpandedFolders = New-Object "System.Collections.Generic.HashSet[string]"
$ContentCacheStore = @{} 
$FileScanCache = @()     
$mainCursor = 0
$Global:LastDrillCursors = @{}
$Global:RangeStartIdx = $null 
$Global:GlobalQuit = $false

if (Test-Path $sessionFile) {
    try {
        $state = Get-Content $sessionFile -Raw | ConvertFrom-Json
        if ($DevDebug) { Write-Host "[DevDebug-Load] Session file found. Restoring cursors/expanded folders..." -ForegroundColor DarkYellow; Read-Host "Press Enter to continue..." }
        $mainCursor = $state.LastCursor
        if ($state.Expanded) {
            foreach ($folder in $state.Expanded) { 
                [void]$ExpandedFolders.Add($folder.ToLower()) 
            }
        }
        if ($state.DrillCursors) {
            foreach ($prop in $state.DrillCursors.psobject.Properties) {
                $Global:LastDrillCursors[$prop.Name] = $prop.Value
            }
        }
    } catch { 
        $mainCursor = 0 
    }
}

if ($collectionRoot -and $ExpandedFolders.Count -eq 0) { 
    [void]$ExpandedFolders.Add((Normalize-Path $collectionRoot).ToLower()) 
}

function Save-SessionState {
    $state = @{
        LastCursor   = $Global:mainCursor
        Expanded     = @($ExpandedFolders)
        DrillCursors = $Global:LastDrillCursors
    }
    $state | ConvertTo-Json -Depth 5 | Out-File $sessionFile -Encoding utf8
}

function Sync-FileCache {
    param([bool]$Force = $false)
    if (-not $Force -and (Test-Path $cacheFileTree)) {
        $Global:FileScanCache = Get-Content $cacheFileTree -Raw | ConvertFrom-Json
        return
    }
    if ([string]::IsNullOrWhiteSpace($collectionRoot)) { return }
    Write-Host ">> Scanning NAS...$ClearLine" -ForegroundColor DarkYellow
    if ($DevDebug) { $timer = [System.Diagnostics.Stopwatch]::StartNew() }
    $files = Get-ChildItem -LiteralPath $collectionRoot -Filter "*.hash" -Recurse -ErrorAction SilentlyContinue | 
             Select-Object Name, FullName, DirectoryName
    $Global:FileScanCache = $files
    $files | ConvertTo-Json -Depth 5 | Out-File $cacheFileTree -Encoding utf8
    if ($DevDebug) {
        $timer.Stop()
        Write-Host "[DevDebug-Scan] Scan completed in $($timer.Elapsed.TotalSeconds.ToString('F2'))s. Found $($files.Count) items." -ForegroundColor DarkYellow
        Read-Host "Press Enter to continue..."
    }
}

function Show-HashManManual {
    param($scriptVersion)

    $global:altColorToggle = $true  

    $PrintManualBlock = {
        param(
            [string]$FlagLine,
            [string[]]$DescLines,
            [string]$ForceDescColor = $null
        )
        Write-Host $FlagLine -ForegroundColor DarkGreen
        $currentColor = if ($ForceDescColor) { $ForceDescColor } else { 
            if ($global:altColorToggle) { "DarkCyan" } else { "DarkMagenta" } 
        }
        foreach ($line in $DescLines) { Write-Host $line -ForegroundColor $currentColor }
        if (-not $ForceDescColor) { $global:altColorToggle = -not $global:altColorToggle }
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " HashMan.ps1 $scriptVersion" -ForegroundColor DarkMagenta
    Write-Host " MANUAL & USAGE GUIDE" -ForegroundColor DarkMagenta
    Write-Host " Copyright (C) 2026 pwshAgyjkcrg761`n" -ForegroundColor DarkCyan
    
    " This program is free software: you can redistribute it and/or",
    " modify it under the terms of the GNU General Public License as",
    " published by the Free Software Foundation, either version 3 of",
    " the License, or (at your option) any later version." | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`n OVERVIEW:" -ForegroundColor DarkYellow
    "  A high-speed TUI (Terminal User Interface) for managing .hash files.",
    "  Navigate complex directory structures, queue file verifications via",
    "  corz checksum, and perform surgical line-item or full-file deletions.",
    "",
    "  The interface supports tree-view navigation, global searching, and",
    "  multi-item range selection within hash containers.`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    
    Write-Host " DEPENDENCIES:" -ForegroundColor DarkYellow
    "  • corz checksum: Required for verification tasks. Must be installed", 
    "    to C:\Program Files\corz\checksum\checksum.exe`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    
    Write-Host "`n NAVIGATION & CONTROLS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  [Arrows / PgUp / PgDn / Home / End]" @(
    "      Standard movement within the tree and drill-down views.`n"
)
    &$PrintManualBlock "  [Right-Arrow / Enter]" @(
    "      Main: Expand folder or 'Drill' into a .hash file to see entries.",
    "      Drill: Toggle file for verification.`n"
)
    &$PrintManualBlock "  [Left-Arrow]" @(
    "      Main: Collapse folder or clear current search filter.",
    "      Drill: Return to the main tree view.`n"
)
    &$PrintManualBlock "  [Spacebar]" @(
    "      Toggle the highlighted folder, file, or entry for verification.`n"
)
    &$PrintManualBlock "  [Delete]" @(
    "      Toggle the highlighted file or entry for the Delete Queue.`n"
)

    Write-Host "`n ACTION SHORTCUTS (Alt Keys):`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  [Alt+V] Verify" @(
    "      Executes the verification process for all items in the Verify Queue.`n"
)
    &$PrintManualBlock "  [Alt+X] Delete" @(
    "      Opens the Delete Task Summary to confirm removal of queued items.`n"
)
    &$PrintManualBlock "  [Alt+S] Range Select" @(
    "      (Drill View Only) Sets a starting anchor. Move the cursor and press",
    "      Alt+S again to queue all entries between the anchor and cursor.`n"
)
    &$PrintManualBlock "  [Alt+Del] Recursive" @(
    "      (Main View Only) Toggles all .hash files within the selected folder",
    "      and its subfolders for the Delete Queue.`n"
)
    &$PrintManualBlock "  [Alt+C] Clear" @(
    "      Clears the current search filter and resets any active range anchors.`n"
)

    Write-Host "`n PARAMETERS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -DevDebug | -Dev | -DBG" @(
    "      Enables internal performance timers, payload count reporting,",
    "      and real-time key-code logging for troubleshooting.`n"
)
    &$PrintManualBlock "  -Manual | -h | -help" @(
    "      Displays this manual.`n"
)
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Press any key to exit..." -ForegroundColor DarkYellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

function Get-HashEntries {
    param($hashFile)
    $key = if ($hashFile.FullName) { $hashFile.FullName } else { $hashFile.SourceHash }
    if ($ContentCacheStore.ContainsKey($key)) { return $ContentCacheStore[$key] }
    
    $results = New-Object System.Collections.Generic.List[PSCustomObject]
    if (-not (Test-Path -LiteralPath $key)) { return @() }
    
    $reader = New-Object System.IO.StreamReader($key, [System.Text.Encoding]::UTF8)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            $line = $line.Trim()
            if ($line -and $line -notlike "#*" -and $line -match '^\S+\s+\*?(?<name>.*)$') {
                $rawName = $Matches.name.Trim()
                $results.Add([PSCustomObject]@{
                    FileName = $rawName; 
                    ParentDir = (Split-Path $key -Parent); 
                    SourceHash = $key;
                    Signature = ($key + "|" + $rawName).ToLower().Trim(); 
                    IsFileEntry = $true; 
                    Depth = 1
                })
            }
        }
    } finally { 
        $reader.Close() 
    }
    $ContentCacheStore[$key] = $results | Sort-Object FileName
    return $ContentCacheStore[$key]
}

function Build-TreeList {
    param([string]$CurrentPath, [int]$Depth)
    if ([string]::IsNullOrWhiteSpace($CurrentPath)) { return @() }
    
    $VisibleList = New-Object System.Collections.Generic.List[PSObject]
    $normCurrent = (Normalize-Path $CurrentPath).ToLower()
    $isExpanded = $ExpandedFolders.Contains($normCurrent)
    $folderName = if ($Depth -eq 0) { "ROOT" } else { Split-Path $CurrentPath -Leaf }
    $icon = if ($isExpanded) { "[-]" } else { "[+]" }

    $VisibleList.Add([PSCustomObject]@{ IsFolder = $true; Path = $CurrentPath; FileName = "$icon $folderName"; Depth = $Depth })

    if ($isExpanded) {
        $filesHere = $Global:FileScanCache | Where-Object { (Normalize-Path $_.DirectoryName).ToLower() -eq $normCurrent } | Sort-Object Name
        foreach ($f in $filesHere) {
            $VisibleList.Add([PSCustomObject]@{ 
                IsFolder = $false; 
                IsFile = $true; 
                FileName = $f.Name; 
                FullName = $f.FullName; 
                DirectoryName = $f.DirectoryName; 
                Depth = $Depth + 1 
            })
        }
        
        $prefix = $normCurrent + "\"
        $subDirs = $Global:FileScanCache | ForEach-Object { (Normalize-Path $_.DirectoryName).ToLower() } | 
                   Where-Object { $_ -ne $normCurrent -and $_.StartsWith($prefix) } | 
                   ForEach-Object { 
                       $rel = $_.Substring($prefix.Length); 
                       $topSub = ($rel -split '\\')[0]; 
                       Join-Path $CurrentPath $topSub 
                   } | 
                   Select-Object -Unique | Sort-Object
        
        foreach ($sf in $subDirs) {
            $subItems = Build-TreeList -CurrentPath $sf -Depth ($Depth + 1)
            foreach ($item in $subItems) { $VisibleList.Add($item) }
        }
    }
    return $VisibleList
}

function Get-BlackSelection {
    param($Items, $Title, $StartingIndex = 0, $Notification = "", $IsDrillView = $false, $HashPath = "")
    $filter = ""; 
    $cursor = $StartingIndex; 
    $pageSize = [Console]::WindowHeight - 18
    $statusMsg = $Notification; 
    $statusExpiry = if ($Notification) { (Get-Date).AddSeconds(3) } else { [DateTime]::MinValue }
    $anchorSig = $null
    $debugKey = ""    
    [Console]::CursorVisible = $false

    [Console]::Clear()

    while ($true) {
        if ($statusMsg -and (Get-Date) -gt $statusExpiry) { $statusMsg = "" }
        
        if ($filter -and -not $IsDrillView) {
            $filtered = $Global:FileScanCache | Where-Object { $_.Name -like "*$filter*" } | ForEach-Object {
                [PSCustomObject]@{ IsFolder = $false; IsFile = $true; FileName = $_.Name; FullName = $_.FullName; DirectoryName = $_.DirectoryName; Depth = 0 }
            }
            $displayTitle = "GLOBAL SEARCH RESULTS"
        } else {
            $filtered = if ($filter) { $Items | Where-Object { $_.FileName -like "*$filter*" } } else { $Items }
            $displayTitle = $Title
        }

        if ($cursor -ge $filtered.Count) { $cursor = [Math]::Max(0, $filtered.Count - 1) }
        
        if ($IsDrillView -and $HashPath) { $Global:LastDrillCursors[$HashPath] = $cursor }
        elseif (-not $IsDrillView -and -not $filter) { $Global:mainCursor = $cursor }

        $vH = 0; $vF = 0
        foreach ($v in $GlobalVerifyQueue.Values) { if ($v.IsFile) { $vH++; $vF += (Get-HashEntries -hashFile $v).Count } else { $vF++ } }
        $dH = 0; $dF = 0
        foreach ($d in $GlobalDeleteQueue.Values) { if ($d.IsFile) { $dH++; $dF += (Get-HashEntries -hashFile $d).Count } else { $dF++ } }

        Write-Host -NoNewline $HomeCursor

        Write-Host "--- $displayTitle (v$scriptVersion) ---$ClearLine" -ForegroundColor DarkCyan
        Write-Host "ROOT: $collectionRoot$ClearLine" -ForegroundColor DarkGray
        Write-Host "QUEUE: Verify: $($vH) .hash(es), $($vF) line(s) | Delete: $($dH) .hash(es), $($dF) line(s)$ClearLine" -ForegroundColor DarkGreen
        Write-Host "CACHE: $($Global:FileScanCache.Count) .hash files tracked$ClearLine" -ForegroundColor DarkGray
        Write-Host "FILTER: [$filter]$ClearLine" -ForegroundColor DarkYellow
        if ($DevDebug) { Write-Host "DEBUG KEY: $debugKey$ClearLine" -ForegroundColor DarkMagenta }
        Write-Host (("-" * ([Console]::WindowWidth - 1)) + $ClearLine) -ForegroundColor DarkGray
        
        Write-Host "[Arrows/PgUp/PgDn/Home/End] Nav | [Left] Back | [Space] Toggle Verify$ClearLine" -ForegroundColor DarkGray
        Write-Host "[Del] Toggle Delete | [Alt+C] Clear Filter/Range | [Alt+R] Full Rescan$ClearLine" -ForegroundColor DarkGray
        
        if ($IsDrillView) { 
            $rangeText = if ($null -eq $Global:RangeStartIdx) { "RANGE START" } else { "END RANGE" }
            Write-Host "[Alt+S] $rangeText | [Alt+D] DESELECT ALL | [Alt+V] VERIFY | [Alt+X] DELETE$ClearLine" -ForegroundColor DarkYellow 
        }
        else { 
            Write-Host -NoNewline "[Alt+K] Collapse All | [Alt+P] ROOT | [Alt+V] VERIFY | [Alt+X] DELETE" -ForegroundColor DarkGray
            
            if ($filtered.Count -gt 0 -and $filtered[$cursor].IsFile) {
                $curDir = (Normalize-Path $filtered[$cursor].DirectoryName).ToLower()
                if ($curDir -ne (Normalize-Path $collectionRoot).ToLower()) {
                    Write-Host -NoNewline " | [Alt+Del] Recursive Hash Toggle" -ForegroundColor Red
                }
            }
            Write-Host $ClearLine
        }
        Write-Host "[Alt+Q] QUIT$ClearLine" -ForegroundColor DarkGray
        Write-Host (("-" * ([Console]::WindowWidth - 1)) + $ClearLine) -ForegroundColor DarkGray

        if ($filtered.Count -gt 0) {
            $selectedItem = $filtered[$cursor]
            $cleanTitle = if ($IsDrillView) { Split-Path $selectedItem.FileName -Leaf } else { $selectedItem.FileName -replace '^\[[+-]\]\s', '' }
            $maxTitleSpace = [Console]::WindowWidth - 12
            if ($cleanTitle.Length -gt $maxTitleSpace) { $cleanTitle = $cleanTitle.Substring(0, $maxTitleSpace - 3) + "..." }
            Write-Host "SELECTED: $cleanTitle$ClearLine" -ForegroundColor White
        } else { 
            Write-Host "SELECTED: (None)$ClearLine" -ForegroundColor DarkGray 
        }
        Write-Host (("-" * ([Console]::WindowWidth - 1)) + $ClearLine) -ForegroundColor DarkGray

        if ($filtered.Count -eq 0) { 
            Write-Host " (No items found)$ClearLine" -ForegroundColor DarkRed 
        }
        else {
            $start = [Math]::Max(0, $cursor - [Math]::Floor($pageSize / 2))
            $end = [Math]::Min($filtered.Count - 1, $start + $pageSize)
            for ($i = $start; $i -le $end; $i++) {
                $item = $filtered[$i]
                $isCursor = ($i -eq $cursor)
                $d = [int]$item.Depth
                $indent = "  " * $d
                $color = "Gray"
                
                if ($isCursor) { $color = "Cyan" } 
                elseif ($null -ne $Global:RangeStartIdx -and $i -eq $Global:RangeStartIdx) { $color = "Yellow" }
                elseif ($item.IsFolder) {
                    if ($d -eq 0) { $color = "DarkMagenta" } 
                    elseif ($d -eq 1) { $color = "Gray" } 
                    elseif ($d -eq 2) { $color = "DarkYellow" } 
                    else { $color = "DarkGray" }
                }
                
                $prefix = if ($isCursor) { "> " } else { "  " }
                $checkbox = ""
                if ($item.IsFile -or $item.IsFileEntry) {
                    $sig = if ($item.IsFile) { $item.FullName.ToLower() } else { $item.Signature }
                    if ($GlobalDeleteQueue.ContainsKey($sig)) { 
                        $checkbox = "[D] "; $color = "DarkRed" 
                    }
                    elseif ($GlobalVerifyQueue.ContainsKey($sig)) { 
                        $checkbox = "[X] "; $color = "DarkGreen" 
                    }
                    else { 
                        $checkbox = "[ ] " 
                    }
                }
                
                $usedSpace = $prefix.Length + $checkbox.Length + $indent.Length
                $maxLen = [Console]::WindowWidth - $usedSpace - 2
                $fName = if ($item.FileName.Length -gt $maxLen) { $item.FileName.Substring(0, $maxLen - 3) + "..." } else { $item.FileName }
                Write-Host ("$prefix$checkbox$indent$($fName)$ClearLine") -ForegroundColor $color
            }
        }
        for ($j = ($end - $start + 1); $j -le $pageSize; $j++) { Write-Host $ClearLine }
        Write-Host "`n$statusMsg$ClearLine" -ForegroundColor DarkYellow

        $key = [Console]::ReadKey($true)
        if ($DevDebug) { $debugKey = "Key: $($key.Key) | Mod: $($key.Modifiers) | Char: $($key.KeyChar)" }
        $RestoreAnchor = {
            param($targetList, $sig)
            if ($null -eq $sig) { return 0 }
            for ($idx=0; $idx -lt $targetList.Count; $idx++) {
                $s = if ($targetList[$idx].IsFile) { $targetList[$idx].FullName.ToLower() } 
                     elseif ($targetList[$idx].IsFolder) { $targetList[$idx].Path.ToLower() } 
                     else { $targetList[$idx].Signature }
                if ($s -eq $sig) { return $idx }
            }
            return 0
        }

        if ($key.Modifiers -band [System.ConsoleModifiers]::Alt) {
            switch ($key.Key) {
                'Delete' {
                    if (-not $IsDrillView) {
                        $target = $filtered[$cursor]
                        if ($target.IsFile) {
                            $parent = (Normalize-Path $target.DirectoryName).ToLower()
                            $rootNorm = (Normalize-Path $collectionRoot).ToLower()
                            if ($parent -eq $rootNorm) {
                                $statusMsg = "ERROR: Recursive delete disabled at Root!"; 
                                $statusExpiry = (Get-Date).AddSeconds(2)
                            } else {
                                $recursiveList = $Global:FileScanCache | Where-Object { 
                                    $fDir = (Normalize-Path $_.DirectoryName).ToLower()
                                    ($fDir -eq $parent) -or ($fDir.StartsWith($parent + "\"))
                                }
                                if ($recursiveList) {
                                    $firstSig = $recursiveList[0].FullName.ToLower()
                                    $isUnmarking = $GlobalDeleteQueue.ContainsKey($firstSig)
                                    $count = 0
                                    foreach ($f in $recursiveList) {
                                        $sig = $f.FullName.ToLower()
                                        if ($isUnmarking) {
                                            if ($GlobalDeleteQueue.ContainsKey($sig)) { [void]$GlobalDeleteQueue.Remove($sig); $count++ }
                                        } else {
                                            $GlobalDeleteQueue[$sig] = [PSCustomObject]@{ IsFile = $true; FullName = $f.FullName; FileName = $f.Name; DirectoryName = $f.DirectoryName }
                                            if ($GlobalVerifyQueue.ContainsKey($sig)) { [void]$GlobalVerifyQueue.Remove($sig) }
                                            $count++
                                        }
                                    }
                                    $statusMsg = if ($isUnmarking) { "Removed $count items from Delete Queue." } else { "Queued $count hashes recursively." }
                                    $statusExpiry = (Get-Date).AddSeconds(2)
                                }
                            }
                        }
                    }
                }
                'C' { 
                    $filter = ""; $Global:RangeStartIdx = $null
                    $full = if ($IsDrillView) { $Items } else { Build-TreeList -CurrentPath $collectionRoot -Depth 0 }
                    $cursor = &$RestoreAnchor $full $anchorSig; $anchorSig = $null
                }
                'D' {
                    if ($IsDrillView) {
                        $removedCount = 0
                        foreach ($entry in $filtered) {
                            $sig = $entry.Signature
                            if ($GlobalDeleteQueue.ContainsKey($sig)) { [void]$GlobalDeleteQueue.Remove($sig); $removedCount++ }
                        }
                        $statusMsg = "Cleared $removedCount items from Delete Queue"; $statusExpiry = (Get-Date).AddSeconds(2)
                    }
                }
                'K' { if (-not $IsDrillView) { $ExpandedFolders.Clear(); if ($collectionRoot) { [void]$ExpandedFolders.Add((Normalize-Path $collectionRoot).ToLower()) }; return @{ Action = "REBUILD"; Index = 0 } } }
                'P' { if (-not $IsDrillView) { return @{ Action = "CHANGE_ROOT" } } }
                'S' { 
                    if ($IsDrillView) {
                        if ($null -eq $Global:RangeStartIdx) {
                            $Global:RangeStartIdx = $cursor
                            $statusMsg = "Range start set at line $($cursor + 1)"; $statusExpiry = (Get-Date).AddSeconds(2)
                        } else {
                            $low = [Math]::Min($Global:RangeStartIdx, $cursor); $high = [Math]::Max($Global:RangeStartIdx, $cursor); $count = 0
                            for ($idx = $low; $idx -le $high; $idx++) {
                                $entry = $filtered[$idx]; $sig = $entry.Signature
                                if (-not $GlobalDeleteQueue.ContainsKey($sig)) { 
                                    $GlobalDeleteQueue[$sig] = $entry; $count++ 
                                    if ($GlobalVerifyQueue.ContainsKey($sig)) { [void]$GlobalVerifyQueue.Remove($sig) }
                                }
                            }
                            $statusMsg = "Queued $count items for deletion"; $statusExpiry = (Get-Date).AddSeconds(2)
                            $Global:RangeStartIdx = $null
                        }
                    }
                }
                'V' { return @{ Action = "RUN_VERIFY" } }
                'X' { return @{ Action = "CONFIRM_DELETE" } }
                'R' { return @{ Action = "REFRESH" } }
                'Q' { $Global:GlobalQuit = $true; return @{ Action = "EXIT" } }
            }
        } else {
            switch ($key.Key) {
                'UpArrow'   { $cursor = [Math]::Max(0, $cursor - 1) }
                'DownArrow' { $cursor = [Math]::Min($filtered.Count - 1, $cursor + 1) }
                'PageUp'    { $cursor = [Math]::Max(0, $cursor - $pageSize) }
                'PageDown'  { $cursor = [Math]::Min($filtered.Count - 1, $cursor + $pageSize) }
                'Home'      { $cursor = 0 }
                'End'       { $cursor = [Math]::Max(0, $filtered.Count - 1) }
                'LeftArrow' {
                    if ($IsDrillView) { return @{ Action = "BACK" } }
                    if ($filter) { 
                        $filter = ""; $full = Build-TreeList -CurrentPath $collectionRoot -Depth 0
                        $cursor = &$RestoreAnchor $full $anchorSig; $anchorSig = $null
                        return @{ Action = "REBUILD"; Index = $cursor } 
                    }
                    $target = $filtered[$cursor]
                    if ($target.IsFolder) {
                        $p = (Normalize-Path $target.Path).ToLower()
                        if ($ExpandedFolders.Contains($p)) { $ExpandedFolders.Remove($p); return @{ Action = "REBUILD"; Index = $cursor } }
                    }
                }
                'RightArrow' {
                    $target = $filtered[$cursor]
                    if ($target.IsFolder) {
                        $p = (Normalize-Path $target.Path).ToLower()
                        if (-not $ExpandedFolders.Contains($p)) { [void]$ExpandedFolders.Add($p) }
                        return @{ Action = "REBUILD"; Index = $cursor }
                    } elseif ($IsDrillView) {
                        $sig = $target.Signature
                        if ($GlobalDeleteQueue.ContainsKey($sig)) { $statusMsg = "CANNOT VERIFY: Item marked for deletion"; $statusExpiry = (Get-Date).AddSeconds(2); continue }
                        if ($GlobalVerifyQueue.ContainsKey($sig)) { [void]$GlobalVerifyQueue.Remove($sig) } else { $GlobalVerifyQueue[$sig] = $target }
                    } else { return @{ Action = "DRILL"; Data = $target; Index = $cursor } }
                }
                'Enter' {
                    $target = $filtered[$cursor]
                    if ($target.IsFolder) {
                        $p = (Normalize-Path $target.Path).ToLower()
                        if ($ExpandedFolders.Contains($p)) { $ExpandedFolders.Remove($p) } else { [void]$ExpandedFolders.Add($p) }
                        return @{ Action = "REBUILD"; Index = $cursor }
                    } elseif ($IsDrillView) {
                        $sig = $target.Signature
                        if ($GlobalDeleteQueue.ContainsKey($sig)) { $statusMsg = "CANNOT VERIFY: Item marked for deletion"; $statusExpiry = (Get-Date).AddSeconds(2); continue }
                        if ($GlobalVerifyQueue.ContainsKey($sig)) { [void]$GlobalVerifyQueue.Remove($sig) } else { $GlobalVerifyQueue[$sig] = $target }
                    } else { return @{ Action = "DRILL"; Data = $target; Index = $cursor } }
                }
                'Spacebar'  {
                    $target = $filtered[$cursor]
                    if ($target.IsFolder) {
                        $p = (Normalize-Path $target.Path).ToLower()
                        if ($ExpandedFolders.Contains($p)) { $ExpandedFolders.Remove($p) } else { [void]$ExpandedFolders.Add($p) }
                        return @{ Action = "REBUILD"; Index = $cursor }
                    } else {
                        $sig = if ($target.IsFile) { $target.FullName.ToLower() } else { $target.Signature }
                        if ($GlobalDeleteQueue.ContainsKey($sig)) { $statusMsg = "CANNOT VERIFY: Item marked for deletion"; $statusExpiry = (Get-Date).AddSeconds(2); continue }
                        if (-not $GlobalVerifyQueue.ContainsKey($sig)) {
                            $conflict = $false
                            if ($target.IsFile) { $conflict = $GlobalVerifyQueue.Keys | Where-Object { $_.StartsWith($sig + "|") } }
                            if ($conflict) { $statusMsg = "ERROR: Entry inside this hash already queued!"; $statusExpiry = (Get-Date).AddSeconds(2) }
                            else { $GlobalVerifyQueue[$sig] = $target }
                        } else { [void]$GlobalVerifyQueue.Remove($sig) }
                    }
                }
                'Delete' {
                    $target = $filtered[$cursor]
                    if ($target.IsFile -or $target.IsFileEntry) {
                        $sig = if ($target.IsFile) { $target.FullName.ToLower() } else { $target.Signature }
                        if ($GlobalDeleteQueue.ContainsKey($sig)) { 
                            [void]$GlobalDeleteQueue.Remove($sig)
                            $statusMsg = "Removed from Delete Queue"; $statusExpiry = (Get-Date).AddSeconds(1)
                        } else { 
                            $GlobalDeleteQueue[$sig] = $target 
                            if ($GlobalVerifyQueue.ContainsKey($sig)) { [void]$GlobalVerifyQueue.Remove($sig) }
                        }
                    }
                }
                'Backspace' { 
                    if ($filter.Length -gt 0) { 
                        $filter = $filter.SubString(0, $filter.Length - 1)
                        if ($filter -eq "") {
                            $full = if ($IsDrillView) { $Items } else { Build-TreeList -CurrentPath $collectionRoot -Depth 0 }
                            $cursor = &$RestoreAnchor $full $anchorSig; $anchorSig = $null
                        } else { $cursor = 0 }
                    }
                }
                default { 
                    if ($key.KeyChar -match '[ -~]') { 
                        if ($filter -eq "") {
                            $anchorItem = $filtered[$cursor]
                            $anchorSig = if ($anchorItem.IsFile) { $anchorItem.FullName.ToLower() } 
                                         elseif ($anchorItem.IsFolder) { $anchorItem.Path.ToLower() } 
                                         else { $anchorItem.Signature }
                        }
                        $filter += $key.KeyChar; $cursor = 0 
                    } 
                }
            }
        }
    }
}

# -------------------------------------------------------------------------
# MAIN ENTRY POINT
# -------------------------------------------------------------------------
try {
    [Console]::Clear()
    if ($Manual) { Show-HashManManual -scriptVersion "v$scriptVersion" }
    if (-not [string]::IsNullOrWhiteSpace($collectionRoot)) { Sync-FileCache }
    $statusNotification = ""
    while ($true) {
        if ($Global:GlobalQuit) { break }
        if ([string]::IsNullOrWhiteSpace($collectionRoot)) {
            Write-Host "NO ROOT PATH SET. PLEASE CONFIGURE NOW." -ForegroundColor Yellow
            $res = @{ Action = "CHANGE_ROOT" }
        } else {
            $tree = Build-TreeList -CurrentPath $collectionRoot -Depth 0
            $res = Get-BlackSelection -Items @($tree) -Title "HASH MANAGER" -StartingIndex $mainCursor -Notification $statusNotification
            $statusNotification = ""
        }
        
        if ($res.Action -ne "DRILL") { $mainCursor = if ($null -ne $res.Index) { $res.Index } else { $mainCursor } }
        else { $mainCursor = $res.Index }

        if ($res.Action -eq "EXIT" -or $Global:GlobalQuit) { break }
        if ($res.Action -eq "REFRESH") { Sync-FileCache -Force $true; $ContentCacheStore.Clear() }
        
        if ($res.Action -eq "CHANGE_ROOT") {
            [Console]::Clear(); Write-Host "ENTER NEW ROOT PATH (LEAVE BLANK TO CANCEL):" -ForegroundColor Cyan
            $inputPath = Read-Host "> "
            if (-not [string]::IsNullOrWhiteSpace($inputPath)) {
                $collectionRoot = Normalize-Path $inputPath
                $collectionRoot | Out-File $settingsFile -Encoding utf8
                Sync-FileCache -Force $true
                $ExpandedFolders.Clear(); [void]$ExpandedFolders.Add($collectionRoot.ToLower()); $mainCursor = 0
            } else {
                if ([string]::IsNullOrWhiteSpace($collectionRoot)) { Write-Host "`nROOT CANNOT BE BLANK." -ForegroundColor Red; Start-Sleep -Seconds 2 }
            }
            [Console]::Clear()
        }

        if ($res.Action -eq "DRILL") {
            $hPath = $res.Data.FullName.ToLower(); $entries = Get-HashEntries -hashFile $res.Data
            $savedDrillIdx = if ($Global:LastDrillCursors.ContainsKey($hPath)) { $Global:LastDrillCursors[$hPath] } else { 0 }
            $drill = Get-BlackSelection -Items @($entries) -Title "ENTRIES: $($res.Data.FileName)" -IsDrillView $true -HashPath $hPath -StartingIndex $savedDrillIdx
            if ($Global:GlobalQuit) { break }
        }

        if ($res.Action -eq "RUN_VERIFY") {
            if ($GlobalVerifyQueue.Count -eq 0) { $statusNotification = "VERIFY QUEUE IS EMPTY."; continue }
            if ($DevDebug) { 
                Write-Host "[DevDebug-Verify] Payload: $($GlobalVerifyQueue.Count) items in dictionary queue." -ForegroundColor DarkYellow
                Read-Host "Press Enter to execute verify..."
            }
            [Console]::Clear(); [Console]::SetCursorPosition(0,0); Write-Host "Verifying...`n" -ForegroundColor DarkCyan
            foreach ($item in $GlobalVerifyQueue.Values) {
                if ($item.IsFile) {
                    Write-Host "HASH CONTAINER: $($item.FileName)" -ForegroundColor Gray
                    $internalFiles = Get-HashEntries -hashFile $item
                    foreach ($entry in $internalFiles) {
                        Write-Host "  [WAIT] $($entry.FileName)" -NoNewline
                        if ($DevDebug) { Write-Host "`n[DevDebug-Verify] CMD: $corzPath | ARGS: $flags `"$($entry.FileName)`" | DIR: $($entry.ParentDir)" -ForegroundColor DarkMagenta }
                        $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{ FileName = $corzPath; WorkingDirectory = $entry.ParentDir; Arguments = "$flags `"$($entry.FileName)`""; CreateNoWindow = $true; UseShellExecute = $false }
                        $proc = [System.Diagnostics.Process]::Start($psi); $proc.WaitForExit()
                        if ($proc.ExitCode -le 1) { Write-Host "`r  [ OK ] $($entry.FileName)$ClearLine" -ForegroundColor DarkGreen } 
                        else { 
                            Write-Host "`r  [FAIL] $($entry.FileName)$ClearLine" -ForegroundColor DarkYellow
                            if ($DevDebug) { Write-Host "  [DevDebug-Verify] Exit Code: $($proc.ExitCode)" -ForegroundColor DarkMagenta }
                        }
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                } else {
                    Write-Host "[WAIT] $($item.FileName)" -NoNewline
                    if ($DevDebug) { Write-Host "`n[DevDebug-Verify] CMD: $corzPath | ARGS: $flags `"$($item.FileName)`" | DIR: $($item.ParentDir)" -ForegroundColor DarkMagenta }
                    $psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{ FileName = $corzPath; WorkingDirectory = $item.ParentDir; Arguments = "$flags `"$($item.FileName)`""; CreateNoWindow = $true; UseShellExecute = $false }
                    $proc = [System.Diagnostics.Process]::Start($psi); $proc.WaitForExit()
                    if ($proc.ExitCode -le 1) { Write-Host "`r[ OK ] $($item.FileName)$ClearLine" -ForegroundColor DarkGreen } 
                    else { 
                        Write-Host "`r[FAIL] $($item.FileName)$ClearLine" -ForegroundColor DarkYellow
                        if ($DevDebug) { Write-Host "  [DevDebug-Verify] Exit Code: $($proc.ExitCode)" -ForegroundColor DarkMagenta }
                    }
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            $GlobalVerifyQueue.Clear(); Write-Host "`nDone. Press any key to return to menu."; [Console]::ReadKey($true) | Out-Null; [Console]::Clear()
        }

        if ($res.Action -eq "CONFIRM_DELETE") {
            if ($GlobalDeleteQueue.Count -eq 0) { $statusNotification = "DELETE QUEUE IS EMPTY."; continue }
            if ($DevDebug) { 
                Write-Host "[DevDebug-Delete] Payload: $($GlobalDeleteQueue.Count) items in dictionary queue." -ForegroundColor DarkYellow
                Read-Host "Press Enter to show summary..."
            }
            [Console]::Clear()
            Write-Host "--- DELETE TASK SUMMARY ---" -ForegroundColor DarkRed
            
            $fullDeletes = $GlobalDeleteQueue.Values | Where-Object { $_.IsFile } | Sort-Object FileName
            $lineModifications = $GlobalDeleteQueue.Values | Where-Object { -not $_.IsFile } | Group-Object SourceHash | Sort-Object { Split-Path $_.Name -Leaf }

            if ($lineModifications) {
                Write-Host "`n-----------------------" -ForegroundColor DarkGray
                Write-Host "Delete lines      ?" -ForegroundColor DarkYellow
                Write-Host "-----------------------" -ForegroundColor DarkGray
                foreach ($group in $lineModifications) {
                    $name = Split-Path $group.Name -Leaf
                    $count = $group.Count.ToString("000")
                    Write-Host ("{0,-16} {1}" -f $name, $count) -ForegroundColor Gray
                }
            }

            if ($fullDeletes) {
                Write-Host "`n-----------------------" -ForegroundColor DarkGray
                Write-Host "Delete .hash files   ?" -ForegroundColor DarkRed
                Write-Host "-----------------------" -ForegroundColor DarkGray
                foreach ($f in $fullDeletes) {
                    Write-Host $f.FileName -ForegroundColor Gray
                }
            }

            $dH = $fullDeletes.Count
            $modSum = if ($lineModifications) { ($lineModifications | Measure-Object -Property Count -Sum).Sum } else { 0 }
            $delSum = if ($fullDeletes) { ($fullDeletes | ForEach-Object { (Get-HashEntries -hashFile $_).Count } | Measure-Object -Sum).Sum } else { 0 }
            $totalLines = $modSum + $delSum
            
            Write-Host "`nSummary: $totalLines line(s) to delete ($dH whole .hash files to delete)." -ForegroundColor Cyan
            Write-Host "`nType YES to confirm or anything else to cancel."
            if ((Read-Host "> ") -eq "YES") {
                foreach ($item in $GlobalDeleteQueue.Values) {
                    if ($item.IsFile) { 
                        if (Test-Path -LiteralPath $item.FullName) { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue }
                        $Global:FileScanCache = $Global:FileScanCache | Where-Object { $_.FullName -ne $item.FullName }
                    } else {
                        if (Test-Path -LiteralPath $item.SourceHash) {
                            $lines = Get-Content -LiteralPath $item.SourceHash -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch [regex]::Escape($item.FileName) }
                            if ($lines) { $lines | Out-File -LiteralPath $item.SourceHash -Encoding utf8 }
                            if ($ContentCacheStore.ContainsKey($item.SourceHash)) { [void]$ContentCacheStore.Remove($item.SourceHash) }
                        }
                    }
                    [System.Windows.Forms.Application]::DoEvents()
                }
                $Global:FileScanCache | ConvertTo-Json -Depth 5 | Out-File $cacheFileTree -Encoding utf8
                $GlobalDeleteQueue.Clear(); Write-Host "`nDeletions complete." -ForegroundColor DarkGreen; Start-Sleep -Seconds 1
            }
            [Console]::Clear()
        }
    }
} finally { Save-SessionState; [Console]::Clear(); [Console]::ResetColor(); [Console]::CursorVisible = $true }