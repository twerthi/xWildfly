function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $BinDir,

        [System.String]
        $InstallArguments,

        [System.String]
        $InstallDir,

        [System.String]
        $ArchiveName,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $returnValue = @{
    Ensure = [System.String]
    ServiceName = [System.String]
    BinDir = [System.String]
    Browser = [System.String[]]
    Credential = [System.Management.Automation.PSCredential]
    }

    $returnValue
    #>
	$result = @{}

    # Get reference to the service
    $WildflyService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    # Fill in the return results variable
    $result['State'] = (if($WildflyService) {$WildflyService.Status} else {$null})

    # Return the result
    return $result

}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $BinDir,

        [System.String]
        $InstallArguments,

        [System.String]
        $InstallDir,

        [System.String]
        $ArchiveName,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    # Get Wildfly service folder
    $WildflyServiceDir = "$($InstallDir)\$($ArchiveName.SubString(0, $ArchiveName.LastIndexOf('.')))\docs\contrib\scripts\service"

    # Get service folder
    $WildflyServiceInstaller = $BinDir + "\service\service.bat"
    $WildflyServiceName = $ServiceName

    # determine action
    switch($Ensure)
    {
        "Present"
        {

            # Get reference to service
            $WildflyService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

            # Check to see if the wildfly service exists
            if (!$WildflyService)
            {
                # Display
                Write-Verbose "Installing Wildfly service $WildflyServiceInstaller."

                # Execute installation
                $installProcess = Start-Process -FilePath "$WildflyServiceInstaller" -ArgumentList $InstallArguments -Wait -NoNewWindow -PassThru 

                # Check the exit code
                if ($installProcess.ExitCode -eq 0)
                {
                    # Wait until the OS has it registered
                    while((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) -eq $null)
                    {
                        # give it a little time
                        Start-sleep -Seconds 1
                    }
                }
                else
                {
                    # Write error
                    Write-Error $Error
                }

                # Get reference to the service
                $WildflyService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

                # Check to make sure it exists
                if ($WildflyService)
                {
                    # Write to log
                    Write-Verbose "Wildfly service successfully installed."

                    # Check to see if a service account was set
                    if ($Credential -ne $null)
                    {
                        # Display
                        Write-Verbose "Setting $($Credential.UserName) as service credentials."

                        # Configure service account
                        $wmiObject = Get-WmiObject -Class win32_service -Filter "Name='$ServiceName'"
                        $wmiObject.change($null,$null,$null,$null,$null,$null,$Credential.UserName,$Credential.GetNetworkCredential().Password)
                    }

                }
                else
                {
                    # Error
                    Write-Error "Wildfly service was not installed."
                }
            }
            else
            {
                # Set the Credential
                $wmiObject = Get-WmiObject -Class win32_service -Filter "Name='$ServiceName'"
                    
                if ($Credential -ne $null)
                {
                    $wmiObject.change($null,$null,$null,$null,$null,$null,$Credential.UserName,$Credential.GetNetworkCredential().Password)
                }
                else
                {
                    $wmiObject.change($null,$null,$null,$null,$null,$null,"LocalSystem",$null)
                }
            }
        }
        "Absent"
        {
            # Get reference to service
            $wmiObject = Get-WmiObject -Class win32_service -Filter "Name='$ServiceName'"

            # Check to see if it's present
            if ($wmiObject -ne $null)
            {
                # Test state of service
                if ($wmiObject.State -eq "Running")
                {
                    # Stop the service
                    $wmiObject.StopService()

                    # Loop while running
                    while($wmiObject.State -ne "Stopped")
                    {
                        Write-Verbose "Stopping service..."
                        Start-Sleep -Seconds 1
                        $wmiObject.Get()
                    }
                }

                Write-Verbose "Removing $ServiceName"
                
                # Delete the service
                $wmiObject.Delete()
            }
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $ServiceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $BinDir,

        [System.String]
        $InstallArguments,

        [System.String]
        $InstallDir,

        [System.String]
        $ArchiveName,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>

    # Get reference to service
    $WildflyService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    $desiredState = $true

    # Check ensure value
    switch ($Ensure)
    {
        "Present"
        {
            # Check the service
            if ($WildflyService)
            {
                # Get the WMI reference
                $WildflyService = Get-WmiObject win32_service -Filter "name='$ServiceName'"

                # Declare working variables
                $serviceUserName = $(if($Credential -eq $null) {"LocalSystem"} else {$Credential.UserName})

                # check to make sure it's running as the correct account
                if($WildflyService.Startname -eq $serviceUserName)
                {
                    # Doesn't need to run
                    $desiredState = $true
                }
                else
                {
                    # Needs to run
                    $desiredState =  $false
                }
            }
            else
            {
                # needs to run
                $desiredState = $false
            }
        }

        "Absent"
        {
            if ($WildflyService)
            {
                $desiredState = $false
            }
            else
            {
                $desiredState = $true
            }
        }
    }
    
    if($desiredState)
    {
        Write-Verbose "Wildfly service in desired state, no action required."
    }
    else
    {
        Write-Verbose "Wildfly service is not in desired state."
    }

    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

