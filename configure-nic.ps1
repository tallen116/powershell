#requires -version 4

<#
.SYNOPSIS
  Configure network adapter

.DESCRIPTION
  Configures the network adapter in an idempotent manner.

.INPUTS Name
  Non-Mandatory.  The name of the network adapter.  You must define Name or MacAddress or script will fail.

.INPUTS MacAddress
  Non-Mandatory.  The mac address of the network adapter.  You must define Name or MacAddress or script will fail.

.INPUTS AutoDnsRegister
  Non-Mandatory. Set or unset the DNS auto registration on the network adapter.

.INPUTS Mtu
  Non-Mandatory. Set MTU on the network adapter.  Valid options are 1514 and 9014

.INPUTS Debug
  Non-Mandatory.  Output debug output.

.OUTPUTS 
  Json formatted output with results of the script.

.NOTES
  Version:        0.4
  Author:         Timothy Allen
  Creation Date:  2020/02/25

  Version:        0.3
  Author:         Timothy Allen
  Creation Date:  2020/02/16

  Version:        0.1
  Author:         Timothy Allen
  Creation Date:  2020/02/15

.EXAMPLE

Rename network adapter based off of MacAddress.  The MacAddress needs to be in the "XX-XX-XX-XX-XX-XX" format.

  powershell.exe -file win_netadapter.ps1 -Name "LAN" -MacAddress "55-55-55-55-55-55"

Set AutoDNS registration on network adapter.  Must specify Name of the network adapter.

  powershell.exe -file win_netadapter.ps1 -Name "LAN" -AutoDnsRegister False

Set Jumbo packet setting on network adapter.  Options must be 1514 or 9014.

  powershell.exe -file win_netadapter.ps1 -Name "LAN" -Mtu 9014
  
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

[CmdletBinding()]
param (
# Parameter help description
[Parameter(Mandatory=$false, Position=0)]
[string]
$Name=$null,

# Mac Address
[Parameter(Mandatory=$false, Position=1)]
[string]
$MacAddress=$null,

# Auto DNS registration
[Parameter(Mandatory=$false)]
[string]
$AutoDnsRegister=$null,

# MTU
[Parameter(Mandatory=$false)]
[int]
$Mtu=$null
)

Set-StrictMode -Version 2.0

#Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "0.3"


#-----------------------------------------------------------[Functions]------------------------------------------------------------

<#

Function <FunctionName>{
  Param()
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }
  
  Process{
    Try{
      <code goes here>
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#>

function Exit-Json {
    param (
        # Powershell object
        [Parameter(Mandatory=$true, Position=0)]
        [psobject]
        $InputObject
    )

    ConvertTo-Json -InputObject $inputObject

    #if ($InputObject.failed -eq $true) {
    if ($InputObject.ContainsKey("failed")) {
        if ($InputObject.failed -eq $true) {
          #Write-Host "Failed"
        }
    }

    if ($InputObject.changed -eq $true) {
        #Write-Host "Changed"
    }
    else {

    }
    
    Exit 0
}


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Verbose "Name is $($Name)"
Write-Verbose "MacAddress is $($MacAddress)"
Write-Verbose "Auto Register DNS is $($AutoDnsRegister)" 
Write-Verbose "MTU is $($Mtu)" 

$result = @{
    changed = $false
}

# Look and see if Name and MacAddress has been defined
if ($Name -eq "" -and $MacAddress -eq "") {
    Exit-Json -InputObject $result
}

# Look and see if MacAddress has been defined
if ($MacAddress -ne "") {

    try {
        # Get Network adapter
        $networkAdapter = Get-NetAdapter | Where-Object {$_.MacAddress -eq $MacAddress}
    }
    catch {
        $result.failed = $true
        $result.msg = "Failed to get network adapter."
    }

    # Check if results contain a network adapter
    if ($null -eq $networkAdapter) {
        $result.failed = $true
        $result.msg = "No network adapters found."
        Exit-Json -InputObject $result
    }

    try {
        # See if name is already matching if not change the name
        if ($networkAdapter.Name -ne $Name) {
          $networkAdapter | Rename-NetAdapter -NewName $Name
          $result.changed = $true  
        }
    }
    catch {
        $result.failed = $true
        $result.msg = "Failed to rename network adapter."
        Exit-Json -InputObject $result
    }

}

# Check if Name is defined
if ($Name -ne "") {

  try {
      # Get network adapter based off Name
      $networkAdapter = Get-NetAdapter | Where-Object {$_.Name -eq $Name}
  }
  catch {
      $result.failed = $true
      $result.msg = "Failed to get network adapter."
      Exit-Json -InputObject $result
  }

  # See if results contain a network adapter
  if ($null -eq $networkAdapter) {
      $result.failed = $true
      $result.msg = "No network adapters found."
      Exit-Json -InputObject $result
  }

  # See if AutoDnsRegister hasa been defined
  if ($AutoDnsRegister -ne "") {
    
    try {
      # Get Dns options for the network adapter
      $networkAdapterProperties = $networkAdapter | Get-DnsClient

      # If AutoDnsRegister has been defined and is not the same change it
      if ($AutoDnsRegister -eq $true -and $networkAdapterProperties.RegisterThisConnectionsAddress -ne $true ) {
        $networkAdapter | Set-DnsClient -RegisterThisConnectionsAddress $true
        $result.changed = $true
      }

      # If AutoDnsRegister has been defined and is not the same change it
      if ($AutoDnsRegister -eq $false -and $networkAdapterProperties.RegisterThisConnectionsAddress -ne $false ) {
        $networkAdapter | Set-DnsClient -RegisterThisConnectionsAddress $false
        $result.changed = $true
      }


    }
    catch {
      $result.failed = $true
      $result.msg = "Failed to set Auto DNS registration"
      Exit-Json -InputObject $result
    }
  }

  # See if Mtu has been defined
  if ($Mtu -ne 0) {
    try {
      # Get advance network adapter options
      $networkAdapterJumboPacket = $networkAdapter | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet"
      
      # Check and see if the results if they are empty
      if ($null -eq $networkAdapterJumboPacket) {
        $result.failed = $true
        $result.msg = "Failed to get Network Adapter Interface details"
        Exit-Json -InputObject $result
      }

      # Check if MTU has been defined as 1500
      if ($Mtu -eq 1514) {
        # Check if the MTU is not set to 1500
        if ($networkAdapterJumboPacket.RegistryValue -ne 1514) {
          $networkAdapter | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" | Set-NetAdapterAdvancedProperty -RegistryValue 1514
          $result.changed = $true
        }
      }

      # Check if MTU has been defined as 9000
      if ($Mtu -eq 9014) {
        # Check if the MTU is not set to 9000
        if ($networkAdapterJumboPacket.RegistryValue -ne 9014) {
          $networkAdapter | Get-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" | Set-NetAdapterAdvancedProperty -RegistryValue 9014
          $result.changed = $true
        }
      }

    }
    catch {
      $result.failed = $true
      $result.msg = "Failed to set MTU"
      Exit-Json -InputObject $result
    }
  }


}

# Return results
Exit-Json -InputObject $result