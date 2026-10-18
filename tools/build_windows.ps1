param([string]$Godot = 'Godot.exe')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$output = Join-Path $project 'builds'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$exportLog = Join-Path $project '.godot/windows-export.log'
$buildTemp = Join-Path $project '.godot/export_temp'
New-Item -ItemType Directory -Path $buildTemp -Force | Out-Null
$previousTemp, $previousTmp = $env:TEMP, $env:TMP
try {
    $env:TEMP = $buildTemp
    $env:TMP = $buildTemp
    $process = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', ('"' + $project + '"'), '--export-release', '"Windows Desktop"', ('"' + (Join-Path $output 'DOODLECAST.exe') + '"'), '--log-file', ('"' + $exportLog + '"')) -WindowStyle Hidden -Wait -PassThru
} finally {
    $env:TEMP, $env:TMP = $previousTemp, $previousTmp
}
if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern '^ERROR:|SCRIPT ERROR' -Quiet)) { throw ('Godot Windows export failed. See ' + $exportLog) }
$oldPack = Join-Path $output 'DOODLECAST.pck'
if (Test-Path -LiteralPath $oldPack) { Remove-Item -LiteralPath $oldPack }
$files = Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Name -eq 'DOODLECAST.exe' -or $_.Extension -eq '.dll' }
Compress-Archive -LiteralPath $files.FullName -DestinationPath (Join-Path $output 'DOODLECAST-Windows.zip') -Force
Write-Output (Join-Path $output 'DOODLECAST-Windows.zip')
