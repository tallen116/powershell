$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

Write-Debug $PSScriptRoot

$daysTillExpire = 75


Set-Location cert:
$expiredCerts = Get-Childitem -Recurse | where {$_.NotAfter -le (get-date).AddDays($daysTillExpire) -and $_.NotAfter -gt (Get-Date)} | select thumbprint, subject, Issuer, friendlyname, notafter

$objShell = New-Object -ComObject Shell.Application

$objFolder = $objShell.NameSpace("$env:HOMEDRIVE$env:HOMEPATH")

$namedFolder = $objShell.BrowseForFolder(0, "Please select where to save the Expired Certificate CSV.  If you hit Cancel it will save in the same directory as the script.", 0, 0.5)

Write-Host $namedFolder.Self.path

$saveDirectory = $namedFolder.Self.Path


if ($saveDirectory -eq $null) {

    $expiredCerts | Export-Csv -Path "$PSScriptRoot\expiredCerts.csv" -Force

} else {

    $expiredCerts | export-csv -Path "$saveDirectory\expiredCerts.csv" -Force

}