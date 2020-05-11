<#
.SYNOPSIS
    Utilize Diskshadow.exe to create a VSS snapshot and copy files without lock

.DESCRIPTION
    This script creates a Diskshadow script with the input parameters by the user and runs diskshadow.exe with
    said script with an external copy process.

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.PARAMETER SourceDrive
    Source drive of VSS snapshot
.PARAMETER DestinationVSSdrive
    Destination of VSS snapshot mount
.PARAMETER ExternalScriptPath
    Path to External batch file to run before deleting VSS snapshot
.PARAMETER VssMetaCab
    Path to VSS meta cab (Only needed for restoring)
.PARAMETER ShowDebug
    Script will show Debug commands from console
.PARAMETER EmailReport
    If this is enabled, script will send report email after running
.PARAMETER DiskShadowPath
    Path to Diskshadow.exe (Only included in Server 2008 and higher)
.PARAMETER LogPath
    Path to log file
.PARAMETER LogVerbosity
    How much logging is written to log file ("None","Info","Debug","All")
.PARAMETER EmailAddress
    List of email addresses comma delimited
.PARAMETER SmtpServer
    Hostname or IP of smtp server
.PARAMETER EmailFromAddress
    Email Parameter of who is sending the email
.PARAMETER EmailAttachment
    Path of attachments comma delimited



.INPUTS
    View Parameters
.OUTPUTS
    Log file wrote to Temp folder unless user specifies path
.NOTES
  Version:        1.0
  Author:         Timothy Allen
  Creation Date:  5/1/17
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>



#>

Param(
    [Parameter(Mandatory=$true)]
    [String]$sourceDrive,
    [Parameter(Mandatory=$true)]
    [String]$destinationVSSdrive,
    [String]$ExternalScriptPath =$null,
    [String]$VssMetaCab = "$env:TEMP\vssMeta.cab",
    [switch]$ShowDebug,
    [Switch]$EmailReport,
    [String]$DiskShadowPath="diskshadow.exe",
    [String]$LogPath="$env:TEMP\VSSmount.log",
    [ValidateSet("None","Info","Debug","All")]
    [String]$LogVerbosity = "Info",
    [String]$EmailAddress = $null,
    [String]$SmtpServer = $null,
    [String]$EmailFromAddress="$env:USERNAME@$env:USERDNSDOMAIN",
    [String]$EmailAttachment=$null


    )

$scriptPath = Split-path -Parent $MyInvocation.MyCommand.Definition
cd $scriptPath

if ($ShowDebug)
{
    $DebugPreference = "Continue"
    Write-Debug "Debug is turned on"
    $LogVerbosity = "Debug"
}

. .\Execute-Command.ps1
. .\Write-Log.ps1
. .\Email-Report.ps1

$startTime = Get-Date -Format o | foreach{$_ -replace ":", "."}

Write-Log -Level Info -Message "Script start time: $startTime" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "Source Drive for VSS: $sourceDrive" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "Destination Drive for VSS: $destinationVSSdrive" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "Path to External Script: $ExternalScriptPath" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "Path to VSS Meta Cab: $VssMetaCab" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "List of email addresses: $EmailAddress" -LogLevel $LogVerbosity -Path $LogPath

Write-Log -Level Debug -Message "Path to Diskshadow.exe: $DiskShadowPath" -LogLevel $LogVerbosity -Path $LogPath






$vssAlias = "sourceDrive"
$dshadowScriptPath = "$env:TEMP\dShadowScript.dsh"
$emailSubject = "$env:COMPUTERNAME Offline Copy: "
#$ExternalScriptPath = "$scriptPath\" + $ExternalScriptPath



#set context persistent nowriters


if ($ExternalScriptPath -ne $null)
{
$dshadowScript = "reset
set verbose on
set context persistent
set metadata $VssMetaCab
begin backup
add volume $sourceDrive alias $vssAlias
create
expose %$vssAlias% $destinationVSSdrive
exec $ExternalScriptPath
delete shadows exposed $destinationVSSdrive
end backup
reset"
}
Else
{
$dshadowScript = "reset"

}
Write-Log -Level Debug -Message "Diskshadow script:`n$dshadowScript" -LogLevel $LogVerbosity -Path $LogPath

$dshadowScript | Set-Content $dshadowScriptPath -Force


# Start DiskShadow process with predefined script
# Creates the VSS Shadow and mounts it under user defined path


    Write-Log -Level Debug -Message "--- Start Diskshadow ---" -LogLevel $LogVerbosity -Path $LogPath
    #$diskShadowJob1 = Start-Process -FilePath "diskshadow.exe" -ArgumentList "-s $dshadowScriptPath" -Wait -ErrorAction Stop -WindowStyle Normal
    #$diskShadowJob1 = Execute-Command -commandTitle "Diskshadow" -commandPath "$DiskShadowPath" -commandArguments "-s $dshadowScriptPath"
    
 
    $diskShadowJob1 = (Start-Process -FilePath $DiskShadowPath -ArgumentList "-s $dshadowScriptPath" -Wait -PassThru -NoNewWindow)
	

    
    #Write-Log -Level Debug -Message "Diskshadow.exe output`n$diskShadowJob1.stdout" -LogLevel $LogVerbosity -Path $LogPath

    #Write-Log -Level Debug -Message ($diskShadowJob1.stdout | Out-String) -LogLevel $LogVerbosity -Path $LogPath
    Write-Log -Level Debug -Message ($diskShadowJob1.ExitCode | Out-String) -LogLevel $LogVerbosity -Path $LogPath
    Write-Debug ($diskShadowJob1.ExitCode.GetType() | Out-String)


    if($diskShadowJob1.ExitCode -ne 0)
    {
    #Write-Log -Level Warn -Message "Error Starting Diskshadow process (Creating VSS snapshot and mounting it)" -LogLevel $LogVerbosity -Path $LogPath
    #Write-Log -Level Warn -Message "Error Output: $diskShadowJob1.stderr`nError Code: $diskShadowJob1.ExitCode" -LogLevel $LogVerbosity -Path $LogPath
    $emailSubject = $emailSubject + "FAILED"
    $EmailAttachment = $null
    &$CallEmailReport
    }

Remove-Item $dshadowScriptPath -Force





Remove-Item -Path "$dshadowScriptPath"


$emailSubject = $emailSubject + "SUCCESS"

&$CallEmailReport

