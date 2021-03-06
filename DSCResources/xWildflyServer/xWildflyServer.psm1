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
        $ServerGroup,

        [System.String]
        $PortOffset,

        [System.String]
        $JvmName,

        [System.String]
        $AutoStart,

        [System.String]
        $ConfigDir,

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

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $servers = $xmlDoc.GetElementsByTagName("servers") | Where-Object {($_.name -eq $Name)}

    # Save the results
    $result = @{
        Name = $server.name
        ServerGroup = $server.group
        JvmName = $server.Jvm.name
    }

    # return the results
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
        $ServerGroup,

        [System.String]
        $PortOffset,

        [System.String]
        $JvmName,

        [System.String]
        $AutoStart,

        [System.String]
        $ConfigDir,

        [System.String]
        $ConfigFile
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1


    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $server = $xmlDoc.GetElementsByTagName("server") | Where-Object {($_.name -eq $Name)}
    $servers = $xmlDoc.GetElementsByTagName("servers")

    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if ($server -ne $null)
            {
                # Display 
                Write-Verbose "Updating server $Name"
             
                # Update the server group properties
                $server.group = $ServerGroup

                # Check to see if autostart is null
                if (![string]::IsNullOrEmpty($AutoStart))
                {
                    # Check for attribute
                    if ($server.'auto-start')
                    {
                        # Update
                        $server.'auto-start' = $AutoStart
                    }
                    else
                    {
                        # Create the attribute
                        $server.SetAttribute("auto-start", $AutoStart)
                    }
                }
                else
                {
                    # Check to see if autostart attribute is present
                    if ($server.'auto-start')
                    {
                        # Remove the attribute
                        $server.RemoveAttribute("auto-start")
                    }
                }

                # Check to see if jvmname was specified
                if (![string]::IsNullOrEmpty($JvmName))
                {
                    # Check for node
                    if ($server.jvm)
                    {
                        # set value
                        $server.jvm.name = $JvmName
                    }
                    else
                    {
                        # Create the node
                        $jvmNode = $xmlDoc.CreateElement("jvm", $servers.NamespaceURI)

                        # Set name attribute
                        $jvmNode.SetAttribute("name", $JvmName)

                        # Add to parent
                        $server.AppendChild($jvmNode)
                    }
                }
                else
                {
                    # Check for presence of node
                    if ($server.jvm)
                    {
                        # Remove
                        $server.RemoveChild($server.jvm)
                    }
                }

                # Check for port offset
                if (![string]::IsNullOrEmpty($PortOffset))
                {
                    # Check for node
                    if ($server.'socket-bindings')
                    {
                        # Update value
                        $server.'socket-bindings'.'port-offset' = $PortOffset
                    }
                    else
                    {
                        # Create node
                        $socketBindings = $xmlDoc.CreateElement("socket-bindings", $servers.NamespaceURI)

                        # Set attribute value
                        $socketBindings.SetAttribute("port-offset", $PortOffset)

                        # Add to parent
                        $server.AppendChild($socketBindings)
                    }
                }
                else
                {
                    # Check for node
                    if ($server.'socket-bindings')
                    {
                        # Get reference to socket bindings
                        $socketBindings = $server.'socket-bindings'
                        
                        # Remove
                        $server.RemoveChild($socketBindings)
                    }
                }
            }
            else
            {
                # Display
                Write-Verbose "Creating server $Name"
                
                # Create new Datasource entry
                $server = $xmlDoc.CreateElement("server", $servers.NamespaceURI)

                # Fill in the server group node attributes
                $server.SetAttribute("name", $Name)
                $server.SetAttribute("group", $ServerGroup)

                # check to see if jvm was specified
                if (![string]::IsNullOrEmpty($JvmName))
                {
                    # Create the node
                    $jvmNode = $xmlDoc.CreateElement("jvm", $servers.NamespaceURI)

                    # Set name attribute
                    $jvmNode.SetAttribute("name", $JvmName)

                    # Add to parent
                    $server.AppendChild($jvmNode)
                }

                # check for autostart
                if (![string]::IsNullOrEmpty($AutoStart))
                {
                    # Create the attribute
                    $server.SetAttribute("auto-start", $AutoStart)
                }

                # Check for socket bindings
                if (![string]::IsNullOrEmpty($PortOffset))
                {
                    # Create the node
                    $socketBindings = $xmlDoc.CreateElement("socket-bindings", $servers.NamespaceURI)

                    # Set attribute value
                    $socketBindings.SetAttribute("port-offset", $PortOffset)

                    # Add to parent
                    $server.AppendChild($socketBindings)
                }

                # Append to parent
                $servers.AppendChild($server)
            }
        }
        "Absent"
        {
            # Display
            Write-Verbose "Removing server $Name"
            
            $server.ParentNode.RemoveChild($server)
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
        $ServerGroup,

        [System.String]
        $PortOffset,

        [System.String]
        $JvmName,

        [System.String]
        $AutoStart,

        [System.String]
        $ConfigDir,

        [System.String]
        $ConfigFile

    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    <#
    $result = [System.Boolean]
    
    $result
    #>
    $desiredState = $true

    # Load xml document
    [xml]$xmlDoc = Get-Content -Path "$ConfigDir\$ConfigFile"

    # Get all the datasource nodes in the specified profile
    $server = $xmlDoc.GetElementsByTagName("server") | Where-Object {($_.name -eq $Name)}

    switch($Ensure)
    {
        "Present"
        {
            # Check for the existance of the datasource
            if ($server -ne $null)
            {
                # Test the specific properties
                if ($server.group -ne $ServerGroup)
                {
                    # not in desired state
                    $desiredState = $false

                    # Break from if
                    break
                }

                
                # Check autostart
                if (![string]::IsNullOrEmpty($AutoStart))
                {
                    # If present and values do not match
                    if ($server.'auto-start' -and ($server.'auto-start' -ne $AutoStart))
                    {
                        # Not in desired state
                        $desiredState = $false

                        break
                    }
                    # If not present
                    elseif (!$server.'auto-start')
                    {
                        # Not in desired state
                        $desiredState = $false

                        break
                    }
                }
                else
                {
                    # If present
                    if ($server.'auto-start')
                    {
                        # Not in deisrd state
                        $desiredState = $false
                    }
                }

                # Check jvm name
                if (![string]::IsNullOrEmpty($JvmName))
                {
                    # If present and valued do not match
                    if ($server.jvm -and ($server.jvm.name -ne $JvmName))
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                    # If not present
                    elseif(!$server.jvm)
                    {
                        # not in desired state
                        $desiredState = $false   
                    }
                }
                else
                {
                    # If present
                    if ($server.jvm)
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                }
                
                if (![string]::IsNullOrEmpty($PortOffset))
                {
                    # If present and values do not match
                    if ($server.'socket-bindings' -and ($server.'socket-bindings'.'port-offset' -ne $PortOffset))
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                    # If not present
                    elseif (!$server.'socket-bindings')
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                }
                else
                {
                    # If present
                    if ($server.'socket-bindings')
                    {
                        # Not in desired state
                        $desiredState = $false
                    }
                }
            }
            else
            {
                # datasource not found
                $desiredState = $false
            }
        }
        "Absent"
        {
            if ($server -ne $null)
            {
                # Datasource found
                $desiredState = $false
            }
            else
            {
                # Datasource wasn't found
                $desiredState = $true
            }
        }
    }

    # Check for desired state
    if ($desiredState -and ($desiredState -eq $true))
    {
        # Display
        Write-Verbose "Server $Name is in desired state, no action required"
        
        # return result
        return $true
    }
    else
    {
        # Display
        Write-Verbose "Server $Name is not in desired state"

        # return result
        return $false
    }
}

 
Export-ModuleMember -Function *-TargetResource

