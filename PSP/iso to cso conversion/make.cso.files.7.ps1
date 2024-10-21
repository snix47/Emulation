# make cso files v7.ps1 - working
#
# PlayStationPortable PSP convert .iso files to .cso files script, runs through a dir and does ´em all
# uses max compression ratio (9)
#
# uncomment # Get-ChildItem $sourcePath -Recurse -Filter *.iso | Remove-Item to remove the .iso files when done
#
# dependencies: ciso.exe  path given in $destinationPath (i know sloppy by me)
#

$sourcePath = "x:\your iso dir\" # Set the path to your ISOs directory
$destinationPath = "x:\ciso.exe" # Set the path to the ciso.exe file
$maxThreads = 10 # Set the maximum number of threads to run simultaneously

$jobs = New-Object System.Collections.ArrayList
$totalIsoSize = 0
$totalCsoSize = 0

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew() # Start the stopwatch

Get-ChildItem $sourcePath -Recurse -Filter *.iso | ForEach-Object {
    $sourceFile = $_.FullName
    $destinationFile = Join-Path $sourcePath ($_.BaseName + ".cso")
    Write-Host "Source: $sourceFile"
    Write-Host "Destination: $destinationFile"

    $isoSize = $_.Length
    $totalIsoSize += $isoSize

    # Start a new background job to convert the current ISO file to a CSO file
    $jobs.Add((Start-Job -ScriptBlock {
        param($sourceFile, $destinationFile, $cisoPath)
        & $cisoPath 9 $sourceFile $destinationFile
    } -ArgumentList $sourceFile, $destinationFile, $destinationPath))

    # If the maximum number of threads has been reached, wait for the oldest job to finish
    if ($jobs.Count -ge $maxThreads) {
        $oldestJob = $jobs[0]
        while ($oldestJob.State -ne "Completed") {
            Start-Sleep -Milliseconds 100
        }
        $jobs.RemoveAt(0) # Remove the oldest job from the list
        $oldestJob | Receive-Job # Retrieve the output of the oldest job
    }
}

# Wait for all remaining jobs to finish and retrieve their output
$jobs | ForEach-Object {
    $_ | Wait-Job | Receive-Job
}

# Optionally delete the source ISO files
# Get-ChildItem $sourcePath -Recurse -Filter *.iso | Remove-Item

$totalTime = $stopwatch.Elapsed # Stop the stopwatch and get the total elapsed time

# Calculate total ISO and CSO file sizes
Get-ChildItem $sourcePath -Recurse -Filter *.iso | ForEach-Object {
    $totalIsoSize += $_.Length
}
Get-ChildItem $sourcePath -Recurse -Filter *.cso | ForEach-Object {
    $totalCsoSize += $_.Length
}

$totalIsoSizeMB = [Math]::Round($totalIsoSize / 1MB, 0)
$totalCsoSizeMB = [Math]::Round($totalCsoSize / 1MB, 0)
$sizeDifferenceMB = [Math]::Round($totalIsoSizeMB - $totalCsoSizeMB, 0)
$sizeDifferencePercent = [Math]::Round(($sizeDifferenceMB / $totalIsoSizeMB) * 100, 0)

$hours = [Math]::Floor($totalTime.TotalHours)
$minutes = [Math]::Floor($totalTime.TotalMinutes % 60)
$seconds = [Math]::Floor($totalTime.TotalSeconds % 60)

Write-Host "Total time running: $hours hours, $minutes minutes, $seconds seconds."
Write-Host "Total ISO size: $totalIsoSizeMB MB"
Write-Host "Total CSO size: $totalCsoSizeMB MB"
Write-Host "Size difference: $($sizeDifferenceMB) MB ($($sizeDifferencePercent)%)"

# Complessed ISO9660 converter Ver.1.00 by BOOSTER
# Usage: ciso level infile outfile
#  level: 1-9 compress ISO to CSO (1=fast/large - 9=small/slow
#         0   decompress CSO to ISO
