<#
.SYNOPSIS
    Bootstrap Windows on first boot to use with Ansible.
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>

[CmdletBinding(PositionalBinding=$false)]
param (
    [Parameter()]
    [String]
    $Task
)

$ErrorActionPreference = "Stop"

Trap {
    $_
    Exit 1
}

$dotnet452_uri = 'https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
$dotnet452_name = 'NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
$dotnet452_args = '/q /norestart'
$dotnet452_hash = '6c2c589132e830a185c5f40f82042bee3022e721a216680bd9b3995ba86f3781'

# Set script path
$script_path = Split-Path $script:MyInvocation.MyCommand.Path
$script_name = $script:MyInvocation.MyCommand.Name
$script_full_path = $script:MyInvocation.MyCommand.Path

$runonce_task_name = "Bootstrap-task"


# Set temp directory and create directory if it doesn't exist
$tmp_dir = $env:TEMP
if (!(Test-Path -Path $tmp_dir)) {
    New-Item -Path $tmp_dir -ItemType Directory | Out-Null
}

function Write-Log {
    param (
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [string]
        $Message,
        [Parameter()]
        [string]
        [ValidateSet("Error", "Warn", "Info")]
        $Level = "Info",
        [Parameter()]
        [string]
        $Path = $env:TEMP
    )


    $log_file = "bootstrap.log"
    $log_path = "$Path\$log_file"
    $formatted_date = Get-Date -Format s

    if (!(Test-Path -Path $log_path)) {
        New-Item -Path $log_path -ItemType File -Force | Out-Null
    }

    switch ($Level) {
        'Info' {
            Write-Verbose -Message $Message
        }
        'Warn' {
            Write-Warning -Message $Message
        }
        'Error' {
            Write-Error -Message $Message
        }
        Default {}
    }

    "$formatted_date - $Message" | Out-File -FilePath $log_path -Append
    
}

Function Enable-AutoLogon {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $User,
        [Parameter()]
        [string]
        $Password,
        [Parameter()]
        [string]
        $Domain
    )

    $autologon_path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path -Path $autologon_path)) {
        New-Item -Path $autologon_path | Out-Null
    }

    Write-Log -Message "Enable AutoLogon for $User"
    Set-ItemProperty -Path $autologon_path -Name 'DefaultUserName' -Value $User
    Set-ItemProperty -Path $autologon_path -Name 'DefaultDomainName' -Value $Domain
    Set-ItemProperty -Path $autologon_path -Name 'DefaultPassword' -Value $Password
    Set-ItemProperty -Path $autologon_path -Name 'AutoAdminLogon' -Value 1
    Remove-ItemProperty -Path $autologon_path -Name 'AutoLogonCount' -ErrorAction SilentlyContinue
}

Function Disable-AutoLogon {

    $autologon_path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path -Path $autologon_path)) {
        New-Item -Path $autologon_path
    }

    Write-Log -Message "Disabling AutoLogon"
    Set-ItemProperty -Path $autologon_path -Name 'DefaultUserName' -Value ''
    Set-ItemProperty -Path $autologon_path -Name 'DefaultPassword' -Value ''
    Set-ItemProperty -Path $autologon_path -Name 'AutoAdminLogon' -Value 0
}

Function Set-RunOnce {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Command,
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )
    
    $runonce_path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

    Write-Log -Message "Setting RunOnce to run $Command"
    Set-ItemProperty -Path $runonce_path -Name $Name -Value $Command
}

function Get-RunOnce {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $runonce_path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

    try {
        $runonce_item = Get-ItemProperty -Path $runonce_path -Name $Name
    }
    catch {
        Write-Log -Message "RunOnce with Name $Name is not set"
        return $runonce_item = ""
    }

    Write-Log -Message "RunOnce is set to $($runonce_item.$Name)"
    return $runonce_item.$Name
    
}

function Remove-RunOnce {
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )
    
    $runonce_path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

    try {
        Remove-ItemProperty -Path $runonce_path -Name $Name
    }
    catch {
        Write-Log -Message "RunOnce with Name $Name does not exist"
        return $false
    }

    Write-Log -Message "RunOnce with Name $Name has been removed"
    return $true
}

Function Start-AdvanceProcess {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Executable,
        [Parameter()]
        [string]
        $Arguments
    )

    $process = New-Object System.Diagnostics.Process
    $start_info = $process.StartInfo
    $start_info.FileName = $Executable
    $start_info.Arguments = $Arguments
    Write-Log -Message "Starting process with $Executable $Arguments"
    $process.Start() | Out-Null

    $process.WaitForExit() | Out-Null

    $exit_code = $process.ExitCode
    Write-Log -Message "Process terminated with exit code $exit_code"

    return $exit_code
}

Function Invoke-FileDownload {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Uri,
        [Parameter()]
        [string]
        $OutFile
    )

    $web_client = New-Object System.Net.WebClient
    $web_client.Headers.Add("user-agent", "Mozilla/5.0 (Windows Bootstrap)")

    Try {
        $web_client.DownloadFile($uri, $outFile)
    }
    Catch {
        Throw "Error Download .Net 4.5.2"
    }
}

Function Get-Sha256Sum {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $File
    )

    [reflection.assembly]::LoadWithPartialName("System.Security") | Out-Null

    Write-Log -Message "Computing SHA256 Hash on $File"
    $hash = [Security.Cryptography.HashAlgorithm]::Create( "SHA256" )
    Try {
        $stream = ([IO.StreamReader]"$File").BaseStream
        $sha256sum = -join ($hash.ComputeHash($stream) | ForEach { "{0:x2}" -f $_ })
    }
    Catch {
        Throw "Error computing hash"
    }
    Finally {
        $stream.Close()
    }

    Write-Log -Message "Computed SHA256 Hash is $sha256sum"

    return $sha256sum
}

Function Invoke-RunOnceRestart {
    param (
        [Parameter()]
        [string]
        $Command,
        [Parameter()]
        [string]
        $User,
        # Parameter help description
        [Parameter()]
        [string]
        $Password
    )


    Set-RunOnce -Command $Command
    Enable-AutoLogon -User $User -Password $Password
    
}

Function Install-DotNet452 {

    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $OutPath = $env:TEMP
    )

    $dotnet452_filename = 'NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
    $dotnet452_uri = 'https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
    $dotnet452_reg = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    $tmp_dir = $OutPath

    # Test if .Net 4.5.2 is installed
    if ((Test-Path -Path $dotnet452_reg) -and ((Get-ItemProperty $dotnet452_reg).Release -lt 379893)) {

        $file_path = "$tmp_dir\$dotnet452_filename"
        # Download file
        Invoke-FileDownload -Uri $dotnet452_uri -OutFile $file_path
        # Generate SHA256 hash and verify the file
        $fileHash = Get-Sha256Sum -File $file_path
        if ($fileHash -ne $dotnet452_hash) {
            Throw ".Net 4.5.2 hash doesn't match"
        }
        $exit_code = Start-AdvanceProcess -Executable $file_path -Arguments $dotnet452_args
        Write-Log -Message ".Net install exit code is $exit_code"
        if ($exit_code -ne 3010 -and $exit_code -ne 0) {
            Throw "Error installing .Net 4.5.2"
        }
        elseif ($exit_code -eq 3010) {
            return $true
        }
    }
    else {
        Write-Log -Message ".Net Framework is already 4.5.2 or later..."
        return $exit_code
    }

    return $false
}

Function Install-WMF51 {
    param (
        [Parameter()]
        [string]
        $OutPath = $env:TEMP
    )

    $wmf_filename ='W2K12-KB3191565-x64.msu'
    $wmf_uri = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/W2K12-KB3191565-x64.msu'
    $wmf_args = '/quiet /norestart'
    $wmf_hash = '4a1385642c1f08e3be7bc70f4a9d74954e239317f50d1a7f60aa444d759d4f49'
    $tmp_dir = $OutPath

    # Test if PowerShell is less than 5.1
    if ($PSVersionTable.PSVersion.Major -lt 5 -and $PSVersionTable.PSVersion.Minor -lt 1) {
        $file_path = "$tmp_dir\$wmf_filename"
        # Download File
        Invoke-FileDownload -Uri $wmf_uri -OutFile $file_path

        # Generate SHA256 hash and verify the file
        $fileHash = Get-Sha256Sum -File $file_path
        if ($fileHash -ne $wmf_hash) {
            Throw "WMF 5.1 hash doesn't match"
        }

        $exit_code = Start-AdvanceProcess -Executable $file_path -Arguments $wmf_args
        Write-Log -Message "WMF 5.1 exit code is $exit_code"
        if ($exit_code -ne 3010 -and $exit_code -ne 0) {
            Throw "Error installing WMF 5.1"
        }
        elseif ($exit_code -eq 3010) {
            # Return true for a reboot
            return $true
        }
    }
    else {
        Write-Log -Message "Powershell is already 5.1 or later..."
    }
    return $false
}

Function Enable-WinRM {
    #Write-Log -Message "Running the Ansible Enable-WinRM script at `"$script_path\EnableWinRM.ps1`" "
    # Run the default Ansible WinRM script
    #& "$script_path\EnableWinRM.ps1"
    #powershell.exe -File "$script_path\EnableWinRM.ps1"

    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Value 1

    Write-Log -Message "WinRM: Run quickconfig"
    &winrm quickconfig -quiet

    Write-Log -Message "WinRM: Allow unencrypted"
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force

    Write-Log -Message "WinRM: Allow Basic auth"
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true -Force

    Write-Log -Message "WinRM: Allow all hosts"
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

    Enable-PSRemoting -SkipNetworkProfileCheck -Force

    Write-Log -Message "Checking WinRM service"
    if ((Get-Service -Name "WinRM").Status -ne "Running") {
        Write-Log -Message "WinRM service is not running. Starting the service."
        Start-Service -Name "WinRM"
    }

    Write-Log -Message "WinRM service is running."

}

Write-Log -Message "Script path is $script_path"
Write-Log -Message "Script name is $script_name"

# The list of actions needed to perform the bootstrap
$task_list = @(
    @{
        name = "Install .Net 4.5.2"
        action = "dotnet"
        url = $dotnet452_uri
        file = $dotnet452_name
        arguments = $dotnet452_args
        sha256 = $dotnet452_hash
    },
    @{
        name = "Upgrade WMF"
        action = "powershell"
        url = $powershell_uri
        file = $powershell_file
        arguments = $powershell_args
    },
    @{
        name = "Enable WinRM"
        action = "winrm"
    }
)

$tasks = @()

# If script is not 
if (-Not $Task) {
    $tasks = $task_list
}
else {
    Write-Log -Message "Script `$Task argument is $Task"

    # Loop through task list and rebuild the list if task parameter defined
    $task_match = $false
    foreach ($item in $task_list) {

        # Set flag to start saving list
        if ($Task -eq $item.action) {
            $task_match = $true
        }

        # If task input matches then start building list
        if ($task_match) {
            $tasks += $item
        }
    }
}

$reboot_required = $false
ForEach($item in $tasks) {

    # If reboot is required set next task to run
    if ($reboot_required) {
        Enable-AutoLogon -User 'vagrant' -Password 'vagrant'
        Set-RunOnce -Name $runonce_task_name -Command "powershell.exe -file $script_full_path -Task $($item.action)"
        Write-Log -Message "Restarting the computer..."
        Restart-Computer -Force
        Start-Sleep -Seconds 30
    }
    Write-Log -Message "The current task is $($item.action)"
    switch ($item.action) {
        "dotnet" {
            Write-Log -Message '.Net 4.5.2 install...'
            $reboot_required = Install-DotNet452
        }
        'powershell' {
            Write-Log 'PowerShell upgrade...'
            $reboot_required = Install-WMF51
        }
        'winrm' {
            Write-Log 'Enable WinRM...'
            #Start-Sleep -Seconds 
            Enable-WinRM
        }
        default {
            throw "Unknown task fed to the script"
        }
    }

}

Write-Log -Message "Disabling autologin"
Disable-AutoLogon

Write-Log -Message "Removing RunOnce task if exist"
Remove-RunOnce -Name $runonce_task_name

Write-Log -Message "Bootstrap script complete"