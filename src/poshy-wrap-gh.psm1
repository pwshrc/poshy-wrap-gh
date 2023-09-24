#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


Get-ChildItem -Path "$PSScriptRoot/private/*.ps1" | ForEach-Object {
    . $_.FullName
}

[string[]] $functionsToExport = @()
Get-ChildItem -Path "$PSScriptRoot/*.ps1" | ForEach-Object {
    . $_.FullName
    $functionsToExport += $_.BaseName
}

Export-ModuleMember -Function *
