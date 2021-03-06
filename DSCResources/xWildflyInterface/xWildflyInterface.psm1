function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Ensure,

        [System.String]
        $ConfigDir,

        [System.String]
        $Address,

        [System.String]
        $ConfigFile
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

    # Load the xml file
    [xml] $xmlDoc = Get-Content "$ConfigDir\$ConfigFile"

    # Get reference to the Interface
    $interface = $xmlDoc.GetElementsByTagName("interface") | Where-Object {$_.Name -eq $Name}

    # Fill in the return results variable
    $result = @{
        Name = $interface.Name
        Address = $(if($interface.'inet-address') {$interface.'inet-address'.Value} else {$null})
    }

    # Return the result
    return $result

}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Ensure,

        [System.String]
        $ConfigDir,

        [System.String]
        $Address,

        [System.String]
        $ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    # Load the xml file
    [xml] $xmlDoc = Get-Content "$ConfigDir\$ConfigFile"

    # Get reference to the Interface
    $interface = $xmlDoc.GetElementsByTagName("interface") | Where-Object {$_.Name -eq $Name}
    $interfaces = $xmlDoc.GetElementsByTagName("interfaces")

    # determine action
    switch($Ensure)
    {
        "Present"
        {
            if ($interface)
            {
                # Get reference to inet address node
                $inetAddress = $interface.GetElementsByTagName("inet-address") | Where-Object {$_.value -ne $null}

                # Check to see if address is null
                if (([string]::IsNullOrEmpty($Address)) -and ($inetAddress -ne $null))
                {
                    # Display
                    Write-Verbose "Removing inet-address node from interface $Name in $ConfigFile"
                    
                    # Remove child element
                    $inetAddress.ParentNode.RemoveChild($inetAddress)
                }
                elseif ((![string]::IsNullOrEmpty($Address)) -and ($inetAddress -ne $null))
                {
                    # Get current value
                    $inetAddressValue = $inetAddress.Value.Split(":")[1].Replace("}", "")

                    # Display
                    Write-Verbose "Replacing $inetAddressValue with $Address on interface $Name in $ConfigFile"

                    # Replace
                    $inetAddress.value = $inetAddress.value.Replace($inetAddressValue, $Address)
                }
                elseif ((![string]::IsNullOrEmpty($Address)) -and ($inetAddress -eq $null))
                {
                    # Display
                    Write-Verbose "Adding inet-address node with value $Address to interface $Name in $ConfigFile"
                    
                    # Create new node
                    $inetNode = $xmlDoc.CreateElement("inet-address", $interface.NamespaceURI)
                    $inetNode.SetAttribute("value", "`${jboss.bind.address." + $Name.ToLower() + ":$Address}")

                    # Add node to interface
                    $interface.AppendChild($inetNode)
                }
            }
            else
            {
                # Create new node
                $interface = $xmlDoc.CreateElement("interface", $interfaces)
                $interface.SetAttribute("name", $Name.ToLower())

                # Check to see if address is null
                if ($Address -ne $null)
                {
                    # Create new node
                    $inetNode = $xmlDoc.CreateElement("inet-address", $interface.NamespaceURI)
                    $inetNode.SetAttribute("value", "`${jboss.bind.address." + $Name.ToLower() + ":$Address}")

                    # Add node to interface
                    $interfaces.AppendChild($inetNode)
                }
            }
        }
        "Absent"
        {
            # Check for interface
            if ($interface)
            {
                # Display
                Write-Verbose "Removing interface $Name from $ConfigFile"
                
                # Remove node
                $interface.ParentNode.RemoveChild($interface)
            }
        }
    }

    # Save the document
    $xmlDoc.Save("$ConfigDir\$ConfigFile")
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.String]
        $Ensure,

        [System.String]
        $ConfigDir,

        [System.String]
        $Address,

        [System.String]
        $ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>

    # Load the xml file
    [xml] $xmlDoc = Get-Content "$ConfigDir\$ConfigFile"
    $desiredState = $true

    # Get reference to the Interface
    $interface = $xmlDoc.GetElementsByTagName("interface") | Where-Object {$_.Name -eq $Name}

    # Check ensure value
    switch ($Ensure)
    {
        "Present"
        {
            # Check the service
            if ($interface)
            {
                # Compare address
                if ($interface.'inet-address')
                {
                    # Parse address
                    $inetAddress = $interface.'inet-address'.Value.Split(":")[1].Replace("}", "")

                    # Compare
                    if ($inetAddress -eq $Address)
                    {
                        $desiredState = $true
                    }
                    else
                    {
                        $desiredState = $false
                    }
                }
                elseif (![string]::IsNullOrEmpty($Address))
                {
                    # Not in desired state
                    $desiredState = $false
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
            if ($interface)
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
        Write-Verbose "Wildfly interface $Name in desired state, no action required."
    }
    else
    {
        Write-Verbose "Wildfly interface $Name is not in desired state."
    }

    return $desiredState
}


Export-ModuleMember -Function *-TargetResource

